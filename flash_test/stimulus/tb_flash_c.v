`timescale 1ns / 1ps

module tb_flash_c;

    // 时钟周期定义
    parameter CLK_PERIOD = 50;

    // 测试信号定义
    reg         clk;
    reg         reset;
    reg         cmd_erasedies;
    reg         cmd_write;
    reg         cmd_read;
    reg  [31:0] addr;
    reg  [15:0] length;
    reg  [7:0]  din;
    wire [7:0]  dout;
    wire        read;
    wire        write;
    wire        done;
    wire        error;
    wire        busy;
    
    // Flash接口信号
    reg         flash_q;
    wire [15:0] flash_c;
    wire        flash_d;
    wire [15:0] flash_reset_n;
    wire [15:0] flash_s_n;

    // 实例化被测试模块
    flash_c uut (
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
        .busy(busy),
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_d(flash_d),
        .flash_reset_n(flash_reset_n),
        .flash_s_n(flash_s_n)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

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
        flash_q = 0;

        // 等待5个时钟周期后释放复位
        #(CLK_PERIOD * 5);
        reset = 0;
        #(CLK_PERIOD * 5);

        // 测试用例1：写入数据到Flash 0
        $display("Test Case 1: Write Data to Flash 0 at %0t", $time);
        addr = 32'h00000100;  // Flash 0
        din = 8'h55;
        cmd_write = 1;
        #(CLK_PERIOD);
        cmd_write = 0;

        // 等待写入命令完成
        wait(!flash_s_n[0]);
        #(CLK_PERIOD * 20);

        // 模拟Flash响应
        repeat(3) begin
            flash_q = 1;  // WIP=1
            #(CLK_PERIOD * 20);
        end
        flash_q = 0;  // WIP=0
        
        // 等待操作完成
        wait(done);
        #(CLK_PERIOD * 100);

        // 测试用例2：读取Flash 1的数据
        $display("Test Case 2: Read Data from Flash 1 at %0t", $time);
        addr = 32'h10000100;  // Flash 1
        length = 16'h0001;
        cmd_read = 1;
        #(CLK_PERIOD);
        cmd_read = 0;

        // 等待读取命令完成
        wait(uut.flash_array[1].flash_inst.state == 51);
        #(CLK_PERIOD * 3);

        // 模拟dummy字节
        repeat(8) begin
            flash_q = $random;
            @(posedge flash_c[1]);
        end

        // 模拟返回8个字节数据
        repeat(8) begin
            repeat(8) begin
                flash_q = $random;
                @(posedge flash_c[1]);
            end
            $display("Read byte from Flash 1: 0x%h at %0t", dout, $time);
        end
        
        // 等待操作完成
        wait(done);
        #(CLK_PERIOD * 1000);

        // 测试用例3：擦除Flash 2
        $display("Test Case 3: Erase Die in Flash 2 at %0t", $time);
        addr = 32'h20000000;  // Flash 2
        length = 16'h0001;
        cmd_erasedies = 1;
        #(CLK_PERIOD);
        cmd_erasedies = 0;

        // 等待擦除命令完成
        wait(!flash_s_n[2]);
        #(CLK_PERIOD * 3);

        // 模拟Flash响应
        repeat(3) begin
            flash_q = 1;  // WIP=1
            #(CLK_PERIOD * 20);
        end
        flash_q = 0;  // WIP=0

        // 等待操作完成
        wait(done);

        // 结束仿真
        #(CLK_PERIOD * 100);
        $display("Simulation completed at %0t", $time);
        $finish;
    end

    // 监视关键信号
    initial begin
        $monitor("Time=%0t busy=%b done=%b error=%b cs=%h",
                 $time, busy, done, error, addr[31:28]);
    end

endmodule
