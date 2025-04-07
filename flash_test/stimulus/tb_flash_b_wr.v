`timescale 1ns / 1ps

module tb_flash_b_wr;

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

        // 测试用例1：写入数据
        $display("Test Case 1: Write Data at %0t", $time);
        addr = 28'h0000100;
        din = 8'h55;
        cmd_write = 1;
        #(CLK_PERIOD);
        cmd_write = 0;

        // 等待WREN和写入命令完成
        wait(!flash_s_n);
        #(CLK_PERIOD * 20);

        // 模拟状态寄存器读取
        repeat(3) begin
            flash_q_reg = 1;  // WIP=1，表示正在写入
            #(CLK_PERIOD * 20);
        end
        flash_q_reg = 0;  // WIP=0，表示写入完成
        
        // 等待写入操作完成
        wait(done);
        #(CLK_PERIOD * 100);

        // 测试用例2：读取数据
        $display("Test Case 2: Read Data at %0t", $time);
        addr = 28'h0000100;
        length = 16'h0001;
        cmd_read = 1;
        #(CLK_PERIOD);
        cmd_read = 0;

        // 等待读取命令和地址发送完成
        wait(uut.state == 32'd51);
        #(CLK_PERIOD * 3);

        // dummy
        repeat(8) begin
            flash_q_reg = $random;
            #(CLK_PERIOD);
        end

        repeat(8) begin
            wait(uut.state == 32'd53);
            repeat(8) begin
                flash_q_reg = $random;
                @(posedge flash_c);
            end
            $display("Read byte: 0x%h at %0t", dout, $time);
        end
        
        // 等待读取操作完成
        wait(done);

        // // 测试用例3：连续写入多个字节
        // $display("Test Case 3: Write Multiple Bytes at %0t", $time);
        // addr = 28'h0000200;
        // din = 8'hAA;
        // cmd_write = 1;
        // #(CLK_PERIOD);
        // cmd_write = 0;

        // // 等待WREN和写入命令完成
        // wait(!flash_s_n);
        // #(CLK_PERIOD * 20);

        // // 模拟状态寄存器读取
        // repeat(3) begin
        //     flash_q_reg = 1;
        //     #(CLK_PERIOD * 20);
        // end
        // flash_q_reg = 0;

        // // 等待写入操作完成
        // wait(done);
        // #(CLK_PERIOD * 100);

        // // 测试用例4：连续读取多个字节
        // $display("Test Case 4: Read Multiple Bytes at %0t", $time);
        // addr = 28'h0000200;
        // length = 16'h0002;
        // cmd_read = 1;
        // #(CLK_PERIOD);
        // cmd_read = 0;

        // // 等待读取命令和地址发送完成
        // wait(!flash_s_n);
        // #(CLK_PERIOD * 50);

        // // 模拟返回多个字节数据
        // flash_q_reg = 1;
        // #(CLK_PERIOD * 16);

        // 等待读取操作完成
        wait(done);

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
