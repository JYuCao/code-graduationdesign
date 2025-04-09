module tb_can_packet();

// 时钟和复位信号
reg         rstn = 1'b0;
reg         clk = 1'b0;

// CAN 总线信号
wire        can_bus;
wire        can_tx1, can_tx2;
wire        can_rx1, can_rx2;

// 模拟 CAN 总线（线与）
assign can_bus = can_tx1 & can_tx2;
assign can_rx1 = can_bus;
assign can_rx2 = can_bus;

// 节点1（发送方）接口信号
reg         tx_start1 = 1'b0;
reg  [31:0] tx_data1 = 32'h0;
wire        tx_done1;
wire        tx_acked1;
wire        rx_valid1;
wire [28:0] rx_id1;
wire        rx_ide1;
wire        rx_rtr1;
wire [ 3:0] rx_len1;
wire [63:0] rx_data1;
reg         rx_ack1 = 1'b1;

// 节点2（接收方）接口信号
reg         tx_start2 = 1'b0;
reg  [31:0] tx_data2 = 32'h0;
wire        tx_done2;
wire        tx_acked2;
wire        rx_valid2;
wire [28:0] rx_id2;
wire        rx_ide2;
wire        rx_rtr2;
wire [ 3:0] rx_len2;
wire [63:0] rx_data2;
reg         rx_ack2 = 1'b1;

// 实例化发送节点
can_level_packet #(
    .TX_RTR         ( 1'b0     ),
    .TX_ID          ( 11'h456  ),
    .default_c_PTS  ( 16'd34   ),
    .default_c_PBS1 ( 16'd5    ),
    .default_c_PBS2 ( 16'd10   )
) u_can_packet1 (
    .rstn           ( rstn     ),
    .clk            ( clk      ),
    .can_rx         ( can_rx1  ),
    .can_tx         ( can_tx1  ),
    .tx_start       ( tx_start1),
    .tx_data        ( tx_data1 ),
    .tx_done        ( tx_done1 ),
    .tx_acked       ( tx_acked1),
    .rx_valid       ( rx_valid1),
    .rx_id          ( rx_id1   ),
    .rx_ide         ( rx_ide1  ),
    .rx_rtr         ( rx_rtr1  ),
    .rx_len         ( rx_len1  ),
    .rx_data        ( rx_data1 ),
    .rx_ack         ( rx_ack1  )
);

// 实例化接收节点
can_level_packet #(
    .TX_RTR         ( 1'b0     ),
    .TX_ID          ( 11'h123  ),
    .default_c_PTS  ( 16'd34   ),
    .default_c_PBS1 ( 16'd5    ),
    .default_c_PBS2 ( 16'd10   )
) u_can_packet2 (
    .rstn           ( rstn     ),
    .clk            ( clk      ),
    .can_rx         ( can_rx2  ),
    .can_tx         ( can_tx2  ),
    .tx_start       ( tx_start2),
    .tx_data        ( tx_data2 ),
    .tx_done        ( tx_done2 ),
    .tx_acked       ( tx_acked2),
    .rx_valid       ( rx_valid2),
    .rx_id          ( rx_id2   ),
    .rx_ide         ( rx_ide2  ),
    .rx_rtr         ( rx_rtr2  ),
    .rx_len         ( rx_len2  ),
    .rx_data        ( rx_data2 ),
    .rx_ack         ( rx_ack2  )
);

// 时钟生成
always #25 clk = ~clk;

// 测试过程
initial begin
    // 初始化
    rstn = 1'b0;
    {tx_start1, tx_data1, rx_ack1} = 0;
    {tx_start2, tx_data2, rx_ack2} = 0;
    
    // 复位
    #200;
    rstn = 1'b1;
    #200;
    
    // 测试发送数据包
    tx_data1 = 32'h12345678;
    wait(u_can_packet1.stat == 4'd1);
    wait(u_can_packet1.cnt >= 20);
    wait(u_can_packet1.bit_req);
    tx_start1 = 1'b1;
    @(posedge clk);
    tx_start1 = 1'b0;
    
    // 等待接收完成
    wait(rx_valid2);
    #1000;
    
    // 结束仿真
    $display("Simulation finished");
    $finish;
end

// 监控接收到的数据
always @(posedge clk) begin
    if (rx_valid2) begin
        $display("Time: %t, Node2 Received: ID=%h, IDE=%b, RTR=%b, LEN=%d, DATA=%h", 
                 $time, rx_id2, rx_ide2, rx_rtr2, rx_len2, rx_data2);
    end
end

// 监控发送完成信号
always @(posedge clk) begin
    if (tx_done1) begin
        $display("Time: %t, Node1 TX completed, ACKed=%b", $time, tx_acked1);
    end
end

endmodule
