`timescale 1ns/1ps

module tb_top_can_flash();

// 时钟和复位
reg clk;
reg rstn;

// CAN总线
tri      can_bus;    // can_bus = CAN_H - CAN_L
pulldown(can_bus);   // 上拉电阻

// 发送端CAN控制器信号
wire         can_tx_rstn;
wire         can_tx_clk;
wire         can_tx_rx;
wire         can_tx_tx;
reg          can_tx_valid;
wire         can_tx_ready;
reg   [31:0] can_tx_data;
wire         rx_valid;
wire         rx_last;
wire  [7:0]  rx_data;
wire  [28:0] rx_id;
wire         rx_ide;

// 接收端信号 (top_can_flash)
wire         can_rx;
wire         can_tx_out;

// Flash接口
reg  flash_q;
wire [15:0] flash_c;
wire flash_d;
wire [15:0] flash_reset_n;
wire [15:0] flash_s_n;

// EEPROM接口
reg  spi_miso;
wire spi_mosi;
wire spi_sck;
wire spi_cs;

// 状态输出
wire [31:0] status_a;
wire [31:0] status_b;

// 发送端时钟生成
tb_gen_clkrst #(25000) can_tx_clkrst(can_tx_rstn, can_tx_clk);  // 20MHz时钟

// CAN PHY模拟
tb_can_phy can_tx_phy(can_tx_tx, can_tx_rx, can_bus);
tb_can_phy can_rx_phy(can_tx_out, can_rx, can_bus);

// 发送端CAN控制器
can_top #(
    .LOCAL_ID(11'h123),           // 发送方ID
    .RX_ID_SHORT_FILTER(11'h456), // 不关心接收
    .RX_ID_SHORT_MASK(11'h7ff),
    .RX_ID_LONG_FILTER(29'h12345678),
    .RX_ID_LONG_MASK(29'h1fffffff),
    .default_c_PTS(16'd12),
    .default_c_PBS1(16'd2),
    .default_c_PBS2(16'd5)
) can_tx_ctrl (
    .rstn(can_tx_rstn),
    .clk(can_tx_clk),
    .can_rx(can_tx_rx),
    .can_tx(can_tx_tx),
    .tx_valid(can_tx_valid),
    .tx_ready(can_tx_ready),
    .tx_data(can_tx_data),
    .rx_valid(rx_valid),
    .rx_last(rx_last),
    .rx_data(rx_data),
    .rx_id(rx_id),
    .rx_ide(rx_ide)
);

// 系统时钟生成
initial begin
    clk = 0;
    forever #25 clk = ~clk;  // 50MHz时钟
end

// 实例化被测模块
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
    .can_rx(can_rx),
    .can_tx(can_tx_out),
    .flash_q(flash_q),
    .flash_c(flash_c),
    .flash_d(flash_d),
    .flash_reset_n(flash_reset_n),
    .flash_s_n(flash_s_n),
    .spi_miso(spi_miso),
    .spi_mosi(spi_mosi),
    .spi_sck(spi_sck),
    .spi_cs(spi_cs),
    .status_a(status_a),
    .status_b(status_b)
);

// 测试过程
initial begin
    // 初始化
    rstn = 0;
    can_tx_valid = 0;
    can_tx_data = 0;
    flash_q = 0;
    spi_miso = 0;
    
    // 复位
    #500 rstn = 1;
    
    // 等待EEPROM初始化完成
    wait(u_top_can_flash.state == u_top_can_flash.WAIT_CAN_STATE);
    #2500;
    
    // 等待发送端准备就绪
    wait(can_tx_ready);
    
    // 1. 发送帧头 (0F0F0F0F)
    can_tx_valid = 1;
    can_tx_data = 32'h0F0F0F0F;
    @(posedge can_tx_clk);
    can_tx_valid = 0;
    @(posedge clk) wait(u_top_can_flash.can_rx_valid);
    @(posedge clk) wait(!u_top_can_flash.can_rx_valid);
    #10000;
    
    // 2. 发送帧信息 (数据长度=16字节)
    wait(can_tx_ready);
    can_tx_valid = 1;
    can_tx_data = 32'h00000010;  // 16字节数据
    @(posedge can_tx_clk);
    can_tx_valid = 0;
    @(posedge clk) wait(u_top_can_flash.can_rx_valid);
    @(posedge clk) wait(!u_top_can_flash.can_rx_valid);
    #10000;
    
    // 3. 发送时间戳 (8字节, 全0)
    wait(can_tx_ready);
    can_tx_valid = 1;
    can_tx_data = 32'h00000000;
    @(posedge can_tx_clk);
    can_tx_valid = 0;
    @(posedge clk) wait(u_top_can_flash.can_rx_valid);
    @(posedge clk) wait(!u_top_can_flash.can_rx_valid);
    #10000;
    
    wait(can_tx_ready);
    can_tx_valid = 1;
    can_tx_data = 32'h00000000;
    @(posedge can_tx_clk);
    can_tx_valid = 0;
    @(posedge clk) wait(u_top_can_flash.can_rx_valid);
    @(posedge clk) wait(!u_top_can_flash.can_rx_valid);
    #10000;
    
    // 4. 发送数据 (8字节)
    wait(can_tx_ready);
    can_tx_valid = 1;
    can_tx_data = 32'hAAAAAAAA;
    @(posedge can_tx_clk);
    can_tx_valid = 0;
    @(posedge clk) wait(u_top_can_flash.can_rx_valid);
    @(posedge clk) wait(!u_top_can_flash.can_rx_valid);
    #10000;
    
    wait(can_tx_ready);
    can_tx_valid = 1;
    can_tx_data = 32'hBBBBBBBB;
    @(posedge can_tx_clk);
    can_tx_valid = 0;
    @(posedge clk) wait(u_top_can_flash.can_rx_valid);
    @(posedge clk) wait(!u_top_can_flash.can_rx_valid);
    #10000;
    
    // 5. 发送帧尾 (F0F0F0F0)
    wait(can_tx_ready);
    can_tx_valid = 1;
    can_tx_data = 32'hF0F0F0F0;
    @(posedge can_tx_clk);
    can_tx_valid = 0;
    @(posedge clk) wait(u_top_can_flash.can_rx_valid);
    @(posedge clk) wait(!u_top_can_flash.can_rx_valid);
    
    // 等待传输完成
    #50000;
    
    // 结束仿真
    $finish;
end

// 模拟EEPROM响应
always @(negedge spi_cs) begin
    spi_miso <= 0;
end

// 模拟Flash响应
always @(negedge flash_s_n[0]) begin
    flash_q <= 0;
end

// 监控状态
always @(posedge clk) begin
    if(status_a != 0) begin
        $display("Status A changed: %h", status_a);
    end
    if(status_b != 0) begin
        $display("Status B changed: %h", status_b);
    end
end

always @(posedge clk) begin
    if(u_top_can_flash.can_rx_valid) begin
        $display("Time=%0t: Received CAN data: %h", $time, u_top_can_flash.can_rx_data);
    end
end

// 监控CAN总线状态
always @(posedge clk) begin
    if(can_bus !== can_bus) begin  // 检测总线冲突
        $display("Time=%0t: CAN bus contention detected!", $time);
    end
end

// 发送32位数据的任务
task send_data;
    input [31:0] data;
begin
    // 发送4个字节
    repeat(4) begin
        wait(can_tx_ready);
        @(posedge can_tx_clk);
        can_tx_valid <= 1;
        can_tx_data <= data[31:24];
        data <= {data[23:0], 8'h00};
        @(posedge can_tx_clk);
        can_tx_valid <= 0;
        #5000; // 等待发送完成
    end
end
endtask

endmodule
