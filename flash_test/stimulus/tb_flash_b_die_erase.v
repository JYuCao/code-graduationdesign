`timescale 1ns / 1ps

module tb_flash_b_die_erase;

    // 时钟周期定义
    parameter CLK_PERIOD = 50;

    // 测试信号定义
    reg         clk;
    reg         reset;
    reg         cmd_erasedies;
    reg         cmd_write;
    reg         cmd_read;
    reg  [27:0] addr;
    reg  [15:0] length;
    reg  [7:0]  din;
    wire [7:0]  dout;
    wire        read;
    wire        write;
    wire        done;
    wire        error;
    wire        flash_q;
    wire        flash_c;
    wire        flash_s_n;
    wire        flash_d;

    // 实例化被测试模块
    flash_b uut (
        .clk(clk),
        .reset(reset),
        .cmd_erasedies(cmd_erasedies),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .addr(addr),
        .length(length),
        .din(din),
        .dout(dout),
        .read(read),
        .write(write),
        .done(done),
        .error(error),
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_s_n(flash_s_n),
        .flash_d(flash_d)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // 模拟Flash响应
    reg flash_q_reg;
    assign flash_q = flash_q_reg;

    // 测试激励
    initial begin
        // 初始化信号
        reset = 1;
        cmd_erasedies = 0;
        cmd_write = 0;
        cmd_read = 0;
        addr = 0;
        length = 0;
        din = 0;
        flash_q_reg = 0;

        // 等待5个时钟周期后释放复位
        #(CLK_PERIOD * 5);
        reset = 0;
        #(CLK_PERIOD * 5);

        // 测试用例1：擦除一个Die
        $display("Test Case 1: Erase Single Die at %0t", $time);
        addr = 28'h0000000;  // Die 0
        length = 16'h0001;   // 擦除1个Die
        cmd_erasedies = 1;
        #(CLK_PERIOD);
        cmd_erasedies = 0;

        // 模拟Flash响应
        wait(!flash_s_n);  // 等待片选信号激活
        
        // 等待WREN命令完成
        #(CLK_PERIOD * 10);
        
        // 模拟状态寄存器读取
        // 首先返回忙状态
        repeat(5) begin
            flash_q_reg = 1;  // WIP=1，表示正在擦除
            #(CLK_PERIOD * 20);
        end
        
        // 然后返回就绪状态
        flash_q_reg = 0;  // WIP=0，表示擦除完成
        #(CLK_PERIOD * 10);
        
        // 等待操作完成
        wait(done);
        
        if (!error)
            $display("Die Erase Test Passed at %0t", $time);
        else
            $display("Die Erase Test Failed at %0t", $time);

        // 测试用例2：擦除多个Die
        #(CLK_PERIOD * 100);
        $display("Test Case 2: Erase Multiple Dies at %0t", $time);
        addr = 28'h0000000;  // 起始Die
        length = 16'h0003;   // 擦除3个Die
        cmd_erasedies = 1;
        #(CLK_PERIOD);
        cmd_erasedies = 0;

        // 对每个Die重复模拟Flash响应
        repeat(3) begin
            wait(!flash_s_n);
            #(CLK_PERIOD * 10);
            flash_q_reg = 1;  // WIP=1
            #(CLK_PERIOD * 20);
            flash_q_reg = 0;  // WIP=0
            #(CLK_PERIOD * 10);
        end

        // 等待操作完成
        wait(done);
        
        if (!error)
            $display("Multiple Die Erase Test Passed at %0t", $time);
        else
            $display("Multiple Die Erase Test Failed at %0t", $time);

        // 结束仿真
        #(CLK_PERIOD * 100);
        $display("Simulation completed at %0t", $time);
        $finish;
    end

    // 监视关键信号
    initial begin
        $monitor("Time=%0t cs_n=%b sck=%b mosi=%b miso=%b busy=%b done=%b error=%b",
                 $time, flash_s_n, flash_c, flash_d, flash_q, write|read, done, error);
    end

endmodule
