`timescale 1ns/1ps

module tb_cmd_process();

    reg sys_clk;
    reg sys_rst_n;
    reg rx;
    wire [7:0] cmd;
    wire done;
    wire error;
    wire [2:0] data_length;
    wire tx;
    wire re;

    // EEPROM接口
    reg eeprom_q;
    wire eeprom_c;
    wire eeprom_s_n;
    wire eeprom_d;

    wire [3:0] baud_set;

    assign baud_set = 0;

    initial begin
        sys_clk = 0;
        forever #25 sys_clk = ~sys_clk;
    end 

    reg [7:0] test_data [0:10];
    integer i;

  
    task uart_send_byte;
        input [7:0] byte;
        integer i;
        integer bit_time;
        begin
            // Calculate bit time based on baud_set
            case (baud_set)
                3'd0: bit_time = 104160;   // 9600 baud rate
                3'd1: bit_time = 52080;    // 19200 baud rate
                3'd2: bit_time = 26040;    // 38400 baud rate
                3'd3: bit_time = 17360;    // 57600 baud rate
                3'd4: bit_time = 86800;     // 115200 baud rate
                default: bit_time = 104160; // Default to 9600 baud rate
            endcase

            // Send start bit
            rx = 0;
            #(bit_time);

            // Send data bits
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte[i];
                #(bit_time);
            end
            // Send stop bit
            rx = 1;
        end
    endtask

    // 实例化被测模块
    cmd_process cmd_process_inst(
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .rx(rx),
        .cmd(cmd),
        .done(done),
        .error(error),
        .data_length(data_length),
        .tx(tx),
        .re(re),
        .eeprom_q(eeprom_q),
        .eeprom_c(eeprom_c),
        .eeprom_s_n(eeprom_s_n),
        .eeprom_d(eeprom_d)
    );

    initial begin
        // 初始化信号
        rx = 1;
        sys_rst_n = 0;
        #(104160);
        sys_rst_n = 1;

        eeprom_q = 0;
        // 测试1：写入命令 (写入地址0x1234，数据0x55)
        test_data[0] = 8'hAA;  // 帧头
        test_data[1] = 8'h03;  // 长度
        test_data[2] = 8'hA0;  // 写命令
        test_data[3] = 8'h12;  // 地址低字节
        test_data[4] = 8'h34;  // 地址高字节
        test_data[5] = 8'h55;  // 数据
        test_data[6] = 8'h55;  // 帧尾

        #(1041600);

        for(i = 0; i <= 6; i = i + 1) begin
            uart_send_byte(test_data[i]);
            #(1041600);
        end

        // 等待写入完成
        wait(done || error);
        #(500000);

        // // 测试2：读取命令 (读取地址0x1234，长度2字节)
        // test_data[0] = 8'hAA;  // 帧头
        // test_data[1] = 8'h04;  // 长度
        // test_data[2] = 8'hA1;  // 读命令
        // test_data[3] = 8'h34;  // 地址低字节
        // test_data[4] = 8'h12;  // 地址高字节
        // test_data[5] = 8'h02;  // 长度低字节
        // test_data[6] = 8'h00;  // 长度高字节
        // test_data[7] = 8'h55;  // 帧尾

        // for(i = 0; i <= 7; i = i + 1) begin
        //     uart_send_byte(test_data[i]);
        //     #(104160);
        // end

        // // 模拟EEPROM返回数据
        // #(200000);
        // repeat(8) begin
        //     eeprom_q = ~eeprom_q;
        //     #(10000);
        // end

        // // 等待读取完成
        // wait(done || error);
        // #(500000);

        $finish;
    end

    // 监视信号
    initial begin
        $monitor("Time=%0t cmd=%h done=%b error=%b data_length=%h eeprom_s_n=%b eeprom_c=%b eeprom_d=%b eeprom_q=%b",
                 $time, cmd, done, error, data_length, eeprom_s_n, eeprom_c, eeprom_d, eeprom_q);
    end

endmodule
