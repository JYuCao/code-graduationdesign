`timescale 1ns/1ps

module tb_can_level_bit();

// 时钟和复位信号
reg clk;
reg rstn;

// CAN接口信号
reg  can_rx;
wire can_tx;

// 用户接口信号
wire req;
wire rbit;
reg  tbit;

// 实例化被测试模块
can_level_bit #(
    .default_c_PTS(16'd34),   // 20MHz时钟下，这些参数配置可实现40kbps波特率
    .default_c_PBS1(16'd5),
    .default_c_PBS2(16'd10)
) u_can_level_bit (
    .rstn(rstn),
    .clk(clk),
    .can_rx(can_rx),
    .can_tx(can_tx),
    .req(req),
    .rbit(rbit),
    .tbit(tbit)
);

// 生成20MHz时钟
initial begin
    clk = 0;
    forever #25 clk = ~clk;  // 50ns周期，20MHz
end

// 测试激励
initial begin
    // 初始化信号
    rstn = 0;
    can_rx = 1;
    tbit = 1;
    
    // 等待100ns后释放复位
    #100;
    rstn = 1;
    
    // 等待系统稳定
    #100;
    
    // 测试场景1：发送一个标准CAN帧的起始位
    can_rx = 0;  // 发送起始位
    #2500;       // 等待一个比特时间 (20MHz/40kbps = 500个时钟周期 = 1250ns)
    
    // 测试场景2：发送一些数据位
    send_can_bit(1);  // 发送1
    send_can_bit(0);  // 发送0
    send_can_bit(1);  // 发送1
    send_can_bit(1);  // 发送1
    
    // 测试场景3：发送7个连续的1表示帧结束
    repeat(7) begin
        send_can_bit(1);
    end
    
    // 等待一段时间观察结果
    #5000;
    
    // 结束仿真
    $finish;
end

// 监控关键信号
always @(posedge clk) begin
    if(req) begin
        $display("Time=%0t req=1 rbit=%b", $time, rbit);
    end
end

// 发送单个CAN比特的任务
task send_can_bit;
    input bit_value;
begin
    can_rx = bit_value;
    #2500;  // 等待一个比特时间
end
endtask


endmodule
