`timescale 1ns/1ps

module tb_cmd_process();

    reg sys_clk;
    reg rx;
    wire [7:0] cmd;
    wire done;
    wire error;
    wire [2:0] data_length;
    wire tx;
    wire re;

    wire [3:0] baud_set;

    assign baud_set = 0;

    initial begin
        sys_clk = 0;
        forever #25 sys_clk = ~sys_clk;
    end 

    reg [7:0] test_data [0:6];
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
        .rx(rx),
        .cmd(cmd),
        .done(done),
        .error(error),
        .data_length(data_length),
        .tx(tx),
        .re(re)
    );

    initial begin
        rx = 1;
        test_data[0] = 8'hAA; 
        test_data[1] = 8'h02; 
        test_data[2] = 8'hFF; 
        test_data[3] = 8'h12;  
        test_data[4] = 8'h34;  
        test_data[5] = 8'h55;  

        #(1041600);

        for(i = 0; i <= 5; i = i + 1) begin
            uart_send_byte(test_data[i]);
            if(i < 5)
                #(1041600);
        end

        wait(done || error);
        
        #(1041600);
        
        $finish;
    end

endmodule
