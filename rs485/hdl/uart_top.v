
module uart_top(
    sys_clk,    
    rx,
    sys_rst_n,
    tx,   
    re    
);

	input sys_clk;
	input sys_rst_n;
    input rx;
    wire [2:0]baud_set;
	
	output tx;
	output reg re;
	
    wire uart_state;
    wire Rx_Done;
    wire Tx_Done;
    reg send_en;
    reg [7:0] data_to_send;
    wire [7:0] received_data;

    reg Rx_Done_r1, Rx_Done_r2;
    wire Rx_Done_pos;

    always@(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            Rx_Done_r1 <= 1'b0;
            Rx_Done_r2 <= 1'b0;
        end else begin
            Rx_Done_r1 <= Rx_Done;
            Rx_Done_r2 <= Rx_Done_r1;
        end
    end
    
    assign Rx_Done_pos = Rx_Done_r1 & ~Rx_Done_r2;
	
    assign baud_set = 3'd0;

	always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            re <= 1'b0;  
        else if(send_en)
            re <= 1'b1; 
        else if(Tx_Done)
            re <= 1'b0; 
    end

	always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            data_to_send <= 8'd0;
            send_en <= 1'b0;
        end
        else if(Rx_Done_pos) begin
            data_to_send <= received_data; 
            send_en <= 1'b1;
        end
        else begin
            send_en <= 1'b0; 
        end
    end

	uart_tx uart_byte_tx(
		.sys_clk(sys_clk),
		.sys_rst_n(sys_rst_n),
		.data(data_to_send),
		.send_en(send_en),
		.baud_set(baud_set),
		
		.tx(tx),
		.Tx_Done(Tx_Done),
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

