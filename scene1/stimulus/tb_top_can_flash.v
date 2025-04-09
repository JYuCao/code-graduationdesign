`timescale 1ns/1ps

module tb_top_can_flash();

// 时钟和复位信号
reg clk;
reg rstn;

// CAN接口信号
reg  can_rx;
wire can_tx;

// Flash接口信号
reg  flash_q;
wire [15:0] flash_c;
wire flash_d;
wire [15:0] flash_reset_n;
wire [15:0] flash_s_n;

// EEPROM接口信号
reg  spi_miso;
wire spi_mosi;
wire spi_sck;
wire spi_cs;

// 状态输出信号
wire [31:0] status_a;
wire [31:0] status_b;

// 实例化被测试模块
top_can_flash #(
    .LOCAL_ID(11'h456),
    .RX_ID_SHORT_FILTER(11'h123),
    .RX_ID_SHORT_MASK(11'h7ff),
    .RX_ID_LONG_FILTER(29'h12345678),
    .RX_ID_LONG_MASK(29'h1fffffff),
    .default_c_PTS(16'd34),
    .default_c_PBS1(16'd5),
    .default_c_PBS2(16'd10),
    .L(11'd1024),
    .M(32'd28)
) u_top_can_flash (
    .clk(clk),
    .rstn(rstn),
    
    // CAN接口
    .can_rx(can_rx),
    .can_tx(can_tx),
    
    // Flash接口
    .flash_q(flash_q),
    .flash_c(flash_c),
    .flash_d(flash_d),
    .flash_reset_n(flash_reset_n),
    .flash_s_n(flash_s_n),
    
    // EEPROM接口
    .spi_miso(spi_miso),
    .spi_mosi(spi_mosi),
    .spi_sck(spi_sck),
    .spi_cs(spi_cs),
    
    // 状态输出
    .status_a(status_a),
    .status_b(status_b)
);

// 20MHz时钟生成（周期50ns）
initial begin
    clk = 0;
    forever #25 clk = ~clk;
end

// 测试激励
initial begin
    // 初始化信号
    rstn = 0;
    can_rx = 1;
    flash_q = 0;
    spi_miso = 0;
    
    // 等待100ns后释放复位
    #100;
    rstn = 1;
    
    // 等待系统稳定
    #1000;
    wait(u_top_can_flash.state == 3);
    
    // 模拟CAN数据接收
    // 帧头: 0F0F0F0F
    send_can_byte(8'h0F);
    send_can_byte(8'h0F);
    send_can_byte(8'h0F);
    send_can_byte(8'h0F);
    
    // 帧信息
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    send_can_byte(8'h10); // 数据长度16字节
    
    // 时间戳
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    send_can_byte(8'h00);
    
    // 数据
    repeat(16) begin
        send_can_byte(8'hAA);
    end
    
    // 帧尾: F0F0F0F0
    send_can_byte(8'hF0);
    send_can_byte(8'hF0);
    send_can_byte(8'hF0);
    send_can_byte(8'hF0);
    
    // 等待处理完成
    #10000;
    
    // 结束仿真
    $finish;
end

// 模拟EEPROM响应
always @(negedge spi_cs) begin
    // 当片选有效时，返回一些测试数据
    spi_miso <= 1'b0;
end

// 模拟Flash响应
always @(flash_s_n) begin
    // 当任意片选有效时，返回一些测试数据
    flash_q <= 1'b0;
end

// 监控状态
always @(posedge clk) begin
    if (status_a != 0 || status_b != 0) begin
        $display("Status changed - A: %h, B: %h", status_a, status_b);
    end
end

// 发送CAN字节的任务
task send_can_byte;
    input [7:0] byte;
    integer i;
begin
    // 发送起始位
    can_rx = 0;
    #1000;
    
    // 发送8位数据
    for (i = 0; i < 8; i = i + 1) begin
        can_rx = byte[i];
        #1000;
    end
    
    // 发送结束位
    can_rx = 1;
    #1000;
end
endtask

endmodule
