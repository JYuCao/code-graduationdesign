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

    // Flash interface
    reg flash_q;
    wire flash_c;
    wire flash_s_n;
    wire flash_d;

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
                default: bit_time = 1041660; // Default to 9600 baud rate
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

        // 添加Flash接口连接
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_s_n(flash_s_n),
        .flash_d(flash_d)
    );

    initial begin
        // 初始化信号
        rx = 1;
        sys_rst_n = 0;
        #(104160);
        sys_rst_n = 1;

        flash_q = 0;
        test_data[0] = 8'hAA; 
        test_data[1] = 8'h04; 
        test_data[2] = 8'hA0; 
        test_data[3] = 8'h12;  
        test_data[4] = 8'h34;  
        test_data[5] = 8'h56;  
        test_data[6] = 8'h78;  
        test_data[7] = 8'h55;  

        #(1041600);

        for(i = 0; i <= 7; i = i + 1) begin
            uart_send_byte(test_data[i]);
            if(i < 7)
                #(1041600);
        end

        
        // wait(done || error);
        // #1000000;

        // send_command(8'h05, 8'hA1, 88'h0000_0000_55_0000_0000_0000);
        // wait(done || error);
        // #1000000;

        // send_command(8'h06, 8'hA2, 88'h0000_0000_0002_0000_0000_0000);
        
        // // 模拟Flash返回数据
        // #500000;
        // flash_q = 1;
        // #104160;
        // flash_q = 0;
        // #104160;
        // flash_q = 1;
        // #104160;
        // flash_q = 0;
        
        wait(done || error);
        #1000000;

        $finish;
    end

    // 监视信号
    initial begin
        $monitor("Time=%0t cmd=%h done=%b error=%b data_length=%h",
                 $time, cmd, done, error, data_length);
    end

endmodule
