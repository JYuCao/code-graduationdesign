`timescale 1ns / 1ps

module tb_flash_a();

// 时钟和复位信号
reg clk;
reg reset;

// 控制信号
reg write;
reg read;
reg deselect;
reg [7:0] din;
wire [7:0] dout;
wire done;

// Flash 接口信号
reg flash_q;
wire flash_c;
wire flash_s_n;
wire flash_d;

// 实例化被测模块
flash_a uut (
    .clk(clk),
    .reset(reset),
    .write(write),
    .read(read),
    .deselect(deselect),
    .din(din),
    .dout(dout),
    .done(done),
    .flash_q(flash_q),
    .flash_c(flash_c),
    .flash_s_n(flash_s_n),
    .flash_d(flash_d)
);

// 时钟生成
initial begin
    clk = 0;
    forever #25 clk = ~clk;
end

// 测试激励
initial begin
    // 初始化
    reset = 1;
    write = 0;
    read = 0;
    deselect = 0;
    din = 0;
    flash_q = 0;
    
    // 等待几个时钟周期后释放复位
    #500;
    reset = 0;
    #100;
    
    // 测试写操作
    din = 8'hA5;
    write = 1;
    #50;
    write = 0;
    wait(done);
    #100;
    
    // 测试读操作
    read = 1;
    #50;
    read = 0;
    // 模拟Flash返回数据
    repeat(8) begin
        @(posedge flash_c);
        flash_q = $random;
    end
    wait(done);
    #100;
    
    // 测试带deselect的操作
    deselect = 1;
    din = 8'h55;
    write = 1;
    #50;
    write = 0;
    wait(done);
    
    #500;
    $finish;
end

// 监控输出
initial begin
    $monitor("Time=%0t reset=%b write=%b read=%b din=%h dout=%h done=%b",
             $time, reset, write, read, din, dout, done);
end

endmodule