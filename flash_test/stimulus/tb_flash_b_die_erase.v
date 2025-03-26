`timescale 1ns / 1ps

module tb_flash_b_die_erase();

// 时钟和复位信号
reg clk;
reg reset;

// 控制信号
reg cmd_dieerase;
reg [23:0] addr;
reg [15:0] length;
reg [7:0] din;
wire [7:0] dout;
wire read;
wire write;
wire done;
wire [15:0] status;

// Flash 接口信号
reg flash_q;
wire flash_c;
wire flash_s_n;
wire flash_d;

// 其他控制信号（未使用但需要连接）
reg cmd_erasesectors;
reg cmd_write;
reg cmd_read;

// 实例化被测模块
flash_b uut (
    .clk(clk),
    .reset(reset),
    .cmd_dieerase(cmd_dieerase),
    .cmd_erasesectors(cmd_erasesectors),
    .cmd_write(cmd_write),
    .cmd_read(cmd_read),
    .addr(addr),
    .length(length),
    .din(din),
    .dout(dout),
    .read(read),
    .write(write),
    .done(done),
    .status(status),
    .flash_q(flash_q),
    .flash_c(flash_c),
    .flash_s_n(flash_s_n),
    .flash_d(flash_d)
);

// 时钟生成，20MHz
initial begin
    clk = 0;
    forever #25 clk = ~clk;
end

// 测试激励
initial begin
    // 初始化
    reset = 1;
    cmd_dieerase = 0;
    cmd_erasesectors = 0;
    cmd_write = 0;
    cmd_read = 0;
    addr = 24'h0;
    length = 16'h0;
    din = 8'h0;
    flash_q = 0;

    // 等待复位完成
    #100;
    reset = 0;
    #100;

    // 测试场景1：擦除Die 0
    addr = 24'h000000;  // Die 0 地址
    length = 16'h1;     // 擦除1个Die
    cmd_dieerase = 1;
    #50;
    cmd_dieerase = 0;
    
    // 等待RDSR返回不忙
    repeat(10) begin
        @(posedge flash_c);
        if(~flash_s_n) begin
            flash_q = 0;  // WIP位为0，表示不忙
        end
    end
    
    wait(done);
    #200;

    // 测试场景2：擦除多个Die
    addr = 24'h400000;  // 从Die 1开始
    length = 16'h2;     // 擦除2个Die
    cmd_dieerase = 1;
    #50;
    cmd_dieerase = 0;
    
    // 模拟每个Die的擦除过程
    repeat(2) begin
        repeat(10) begin
            @(posedge flash_c);
            if(~flash_s_n) begin
                flash_q = 0;
            end
        end
    end
    
    wait(done);
    #200;

    $display("Die Erase 测试完成");
    $finish;
end

// 监控关键信号
initial begin
    $monitor("Time=%0t cmd_dieerase=%b addr=%h length=%h done=%b status=%h",
             $time, cmd_dieerase, addr, length, done, status);
end

endmodule
