
module uart_rx(
    sys_clk,        
    sys_rst_n,      
    baud_set,   
    rx,   
			 
    data,
    Rx_Done
		);

	input sys_clk;
	input sys_rst_n; 
	input [2:0]baud_set;
	input rx;
	
	output reg [7:0]data;
	output reg Rx_Done;
	
	reg [15:0] baud_div;
	
	parameter IDLE  = 3'b000;
	parameter START = 3'b001;
	parameter DATA  = 3'b010;
	parameter STOP  = 3'b011;
	parameter DONE  = 3'b100;
	
	reg [2:0] state;
	reg [2:0] next_state;
	
	reg [15:0] baud_cnt;
	reg baud_pulse;
    reg sample_pulse;
	reg [2:0] bit_cnt;
	reg [7:0] rx_data;
	
    // baud set
	always @(*) begin
		case (baud_set)
            3'd0: baud_div = 2083;   // 9600 baud @ 20MHz (20M/9600)
            3'd1: baud_div = 1042;   // 19200 baud @ 20MHz
            3'd2: baud_div = 521;    // 38400 baud @ 20MHz
            3'd3: baud_div = 347;    // 57600 baud @ 20MHz
            3'd4: baud_div = 174;    // 115200 baud @ 20MHz
            default: baud_div = 2083; // Default to 9600 baud rate
        endcase
	end

    // rx_negedge check
    reg rx_prev;
    wire rx_negedge;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            rx_prev <= 1'b1;
        else
            rx_prev <= rx;
    end
    assign rx_negedge = ({rx_prev, rx} == 2'b10);

	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			baud_cnt <= 16'd0;
			baud_pulse <= 1'b0;
            sample_pulse <= 1'b0;
		end
		else if(state != IDLE) begin
			if(baud_cnt == baud_div - 1) begin
				baud_cnt <= 16'd0;
				baud_pulse <= 1'b1;
			end
			else begin
				baud_cnt <= baud_cnt + 1'b1;
				baud_pulse <= 1'b0;
			end
            if(baud_cnt == baud_div/2)
                sample_pulse <= 1'b1;
            else
                sample_pulse <= 1'b0;
		end
		else begin
			baud_cnt <= 16'd0;
			baud_pulse <= 1'b0;
            sample_pulse <= 1'b0;
		end
	end
	
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end
	
	always @(*) begin
		case(state)
			IDLE: begin
				if(rx_negedge)
					next_state = START;
				else
					next_state = IDLE;
			end
			
			START: begin
				if(baud_pulse)
					next_state = DATA;
				else
					next_state = START;
			end
			
			DATA: begin
				if(baud_pulse && bit_cnt == 3'd7)
					next_state = STOP;
				else
					next_state = DATA;
			end
			
			STOP: begin
				if(baud_pulse)
					next_state = DONE;
				else
					next_state = STOP;
			end
			
			DONE: begin
				next_state = IDLE;
			end
			
			default: next_state = IDLE;
		endcase
	end
	
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n)
			bit_cnt <= 3'd0;
		else if(state == DATA) begin
			if(baud_pulse)
				bit_cnt <= bit_cnt + 1'b1;
		end
		else
			bit_cnt <= 3'd0;
	end
	
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n)
			rx_data <= 8'd0;
		else if(state == DATA && sample_pulse)
			rx_data[bit_cnt] <= rx;
	end
	
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if(!sys_rst_n) begin
			data <= 8'd0;
			Rx_Done <= 1'b0;
		end
		else if(state == DONE) begin
			data <= rx_data;
			Rx_Done <= 1'b1;
		end
		else
			Rx_Done <= 1'b0;
	end
	
endmodule
