
//`timescale <time_units> / <precision>

module uart_top(
    sys_clk,      
    sys_rst_n,   
    rx,
    baud_set,
    tx,   
    re    
);

	input sys_clk;
	input sys_rst_n;
    input rx;
    input [2:0]baud_set;
	
	output tx;
	output re;
	
	wire [7:0]data;
    wire uart_state;
    wire Rx_Done;
    wire send_en;
    wire [7:0] data_to_send;
    wire [7:0] received_data;
	
    assign re = uart_state;
    assign data_to_send = received_data; 
    assign send_en = Rx_Done;

	uart_tx uart_byte_tx(
		.sys_clk(sys_clk),
		.sys_rst_n(sys_rst_n),
		.data(data_to_send),
		.send_en(send_en),
		.baud_set(baud_set),
		
		.tx(tx),
		.Tx_Done(),
		.uart_state(uart_state)
	);
	
	uart_rx uart_byte_rx(
		.sys_clk(sys_clk),
		.sys_rst_n(sys_rst_n),
		.baud_set(baud_set),
		.rx(rx),
		
		.data(received_data),
		.Rx_Done(Rx_Done)
	);
	
endmodule

