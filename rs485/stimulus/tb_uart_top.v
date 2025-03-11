
`timescale 1ns/1ps

module tb_uart_top;

parameter SYSCLK_PERIOD = 50;// 20MHZ

reg SYSCLK;
reg NSYSRESET;
reg rx;
reg [2:0] baud_set;

wire tx;
wire re;

initial
begin
    SYSCLK = 1'b0;
    NSYSRESET = 1'b0;
    rx = 1;
    baud_set = 3'd0;
end


//////////////////////////////////////////////////////////////////////
// Clock Driver
//////////////////////////////////////////////////////////////////////
always @(SYSCLK)
    #(SYSCLK_PERIOD / 2.0) SYSCLK <= !SYSCLK;


//////////////////////////////////////////////////////////////////////
// Instantiate Unit Under Test:  uart_top
//////////////////////////////////////////////////////////////////////
uart_top uart_top_0 (
    // Inputs
    .sys_clk(SYSCLK),
    .rx(rx),
    .sys_rst_n(NSYSRESET),

    // Outputs
    .tx(tx),
    .re(re)
);

initial begin
    #10000;
    NSYSRESET = 1;
    #10000;

    send_byte(8'h55);
    #(1041600);
    #(5000)

    send_byte(8'haa);
    #(1041600);

    $stop;
end

task send_byte;
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

endmodule

