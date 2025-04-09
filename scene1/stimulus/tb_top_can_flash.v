`timescale 1ns/1ps

module tb_top_can_flash();

// 时钟和复位信号
reg clk;
reg rstn;

// CAN总线信号
wire can_bus;
wire can_tx_sender;
wire can_tx_receiver;

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

// 模拟CAN总线（线与）
assign can_bus = can_tx_sender & can_tx_receiver;

// 发送方CAN控制器信号
reg         tx_start_sender = 1'b0;
reg  [31:0] tx_data_sender = 32'h0;
wire        tx_done_sender;
wire        tx_acked_sender;
wire        rx_valid_sender;
wire [28:0] rx_id_sender;
wire        rx_ide_sender;
wire        rx_rtr_sender;
wire [ 3:0] rx_len_sender;
wire [63:0] rx_data_sender;
reg         rx_ack_sender = 1'b1;

// 实例化发送方CAN控制器
can_level_packet #(
    .TX_RTR         ( 1'b0     ),
    .TX_ID          ( 11'h123  ),  // 使用接收方期望的ID
    .default_c_PTS  ( 16'd12   ),
    .default_c_PBS1 ( 16'd2    ),
    .default_c_PBS2 ( 16'd5    )
) u_can_sender (
    .rstn           ( rstn     ),
    .clk            ( clk      ),
    .can_rx         ( can_bus  ),
    .can_tx         ( can_tx_sender ),
    .tx_start       ( tx_start_sender ),
    .tx_data        ( tx_data_sender ),
    .tx_done        ( tx_done_sender ),
    .tx_acked       ( tx_acked_sender ),
    .rx_valid       ( rx_valid_sender ),
    .rx_id          ( rx_id_sender ),
    .rx_ide         ( rx_ide_sender ),
    .rx_rtr         ( rx_rtr_sender ),
    .rx_len         ( rx_len_sender ),
    .rx_data        ( rx_data_sender ),
    .rx_ack         ( rx_ack_sender )
);

// 实例化被测试模块
top_can_flash #(
    .LOCAL_ID(11'h456),
    .RX_ID_SHORT_FILTER(11'h123),
    .RX_ID_SHORT_MASK(11'h7ff),
    .RX_ID_LONG_FILTER(29'h12345678),
    .RX_ID_LONG_MASK(29'h1fffffff),
    .default_c_PTS(16'd12),
    .default_c_PBS1(16'd2),
    .default_c_PBS2(16'd5),
    .L(11'd1024),
    .M(32'd28)
) u_top_can_flash (
    .clk(clk),
    .rstn(rstn),
    
    // CAN接口
    .can_rx(can_bus),
    .can_tx(can_tx_receiver),
    
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
    tx_start_sender = 0;
    tx_data_sender = 0;
    flash_q = 0;
    spi_miso = 0;
    
    // 等待100ns后释放复位
    #100;
    rstn = 1;
    
    // 等待系统稳定，确保进入WAIT_CAN_STATE状态
    wait(u_top_can_flash.state == u_top_can_flash.WAIT_CAN_STATE);
    #1000;
    
    // 等待CAN控制器准备好发送数据
    wait(u_can_sender.stat == 4'd1); // 等待IDLE状态
    wait(u_can_sender.cnt >= 20);    // 等待计数器
    wait(u_can_sender.bit_req);      // 等待位请求
    
    // 发送第一帧数据
    // 帧头: 0F0F0F0F
    send_frame_data(32'h0F0F0F0F, 32'h00000010, 64'h0000000000000000, 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA, 32'hF0F0F0F0);
    
    // 等待处理完成
    wait(u_top_can_flash.state == u_top_can_flash.WAIT_CAN_STATE);
    #5000;
    
    // 发送第二帧数据
    wait(u_can_sender.stat == 4'd1); // 等待IDLE状态
    wait(u_can_sender.cnt >= 20);    // 等待计数器
    wait(u_can_sender.bit_req);      // 等待位请求
    
    // 帧头: 0F0F0F0F, 帧信息: 数据长度8字节, 时间戳, 数据, 帧尾: F0F0F0F0
    send_frame_data(32'h0F0F0F0F, 32'h00000008, 64'h0102030405060708, 64'h5555555555555555, 32'hF0F0F0F0);
    
    // 等待处理完成
    wait(u_top_can_flash.state == u_top_can_flash.WAIT_CAN_STATE);
    #10000;
    
    // 结束仿真
    $display("Simulation completed successfully");
    $finish;
end

// 模拟EEPROM响应
reg [3:0] spi_counter = 0;
reg spi_active = 0;

always @(negedge spi_cs) begin
    spi_active <= 1;
    spi_counter <= 0;
end

always @(posedge spi_sck) begin
    if (spi_active) begin
        spi_counter <= spi_counter + 1;
        if (spi_counter == 7) begin
            spi_miso <= 1'b1;
            spi_active <= 0;
        end
    end
end

// 模拟Flash响应
reg [3:0] flash_counter = 0;
reg flash_active = 0;

always @(flash_s_n) begin
    if (flash_s_n != 16'hFFFF) begin
        flash_active <= 1;
        flash_counter <= 0;
    end
end

always @(posedge flash_c[0]) begin
    if (flash_active) begin
        flash_counter <= flash_counter + 1;
        if (flash_counter == 7) begin
            flash_q <= 1'b1;
            flash_active <= 0;
        end
    end
end

// 监控状态
always @(posedge clk) begin
    if (status_a != 0 || status_b != 0) begin
        $display("Status changed - A: %h, B: %h", status_a, status_b);
    end
end

// 监控状态机状态变化
always @(u_top_can_flash.state) begin
    $display("Time: %t, State changed to: %d", $time, u_top_can_flash.state);
end

// 监控CAN发送完成信号
always @(posedge clk) begin
    if (tx_done_sender) begin
        $display("Time: %t, CAN TX completed, ACKed=%b", $time, tx_acked_sender);
    end
end

// 发送一帧CAN数据的任务
task send_frame_data;
    input [31:0] header;    // 帧头
    input [31:0] frame_info; // 帧信息
    input [63:0] timestamp;  // 时间戳
    input [127:0] data;      // 数据（最多16字节）
    input [31:0] footer;     // 帧尾
    
    integer i, data_bytes;
    reg [7:0] current_byte;
begin
    // 计算数据字节数
    data_bytes = frame_info[7:0];
    
    // 发送帧头
    for (i = 0; i < 4; i = i + 1) begin
        current_byte = header[8*i +: 8];
        send_can_data_byte(current_byte);
    end
    
    // 发送帧信息
    for (i = 0; i < 4; i = i + 1) begin
        current_byte = frame_info[8*i +: 8];
        send_can_data_byte(current_byte);
    end
    
    // 发送时间戳
    for (i = 0; i < 8; i = i + 1) begin
        current_byte = timestamp[8*i +: 8];
        send_can_data_byte(current_byte);
    end
    
    // 发送数据
    for (i = 0; i < data_bytes; i = i + 1) begin
        current_byte = data[8*i +: 8];
        send_can_data_byte(current_byte);
    end
    
    // 发送帧尾
    for (i = 0; i < 4; i = i + 1) begin
        current_byte = footer[8*i +: 8];
        send_can_data_byte(current_byte);
    end
end
endtask

// 通过CAN控制器发送一个字节的任务
task send_can_data_byte;
    input [7:0] byte_data;
begin
    // 设置发送数据
    tx_data_sender = {24'h0, byte_data};
    
    // 启动发送
    tx_start_sender = 1'b1;
    @(posedge clk);
    tx_start_sender = 1'b0;
    
    // 等待发送完成
    wait(tx_done_sender);
    @(posedge clk);
    @(posedge clk);
end
endtask

endmodule
