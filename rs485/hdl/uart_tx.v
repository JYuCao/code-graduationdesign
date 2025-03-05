
//`timescale <time_units> / <precision>

module uart_tx(
	sys_clk,    
	sys_rst_n, 
	data, 
	send_en,   
	baud_set, 
	
	tx, 
	Tx_Done,   
	uart_state 
);

	input sys_clk;
	input sys_rst_n;
	input [7:0]data;
	input send_en;
	input [2:0]baud_set;
	
	output reg tx;
	output reg Tx_Done;
	output reg uart_state;
	
	reg bps_sys_clk;	
	
	reg [15:0]div_cnt;
	
	reg [15:0]bps_DR;
	
	reg [3:0]bps_cnt;
	
	reg [7:0]r_data;
	
	localparam START_BIT = 1'b0;
	localparam STOP_BIT = 1'b1;
	
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            uart_state <= 1'b0;
        else if(send_en)
            uart_state <= 1'b1;
        else if(bps_cnt == 4'd11)
            uart_state <= 1'b0;
        else
            uart_state <= uart_state;
	
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            r_data <= 8'd0;
        else if(send_en)
            r_data <= data;
        else
            r_data <= r_data;
	
	// 50M
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            bps_DR <= 16'd5207;
        else begin
            case(baud_set)
                0:bps_DR <= 16'd5207;
                1:bps_DR <= 16'd2603;
                2:bps_DR <= 16'd1301;
                3:bps_DR <= 16'd867;
                4:bps_DR <= 16'd433;
                default:bps_DR <= 16'd5207;			
            endcase
        end	
	
	//counter
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            div_cnt <= 16'd0;
        else if(uart_state)begin
            if(div_cnt == bps_DR)
                div_cnt <= 16'd0;
            else
                div_cnt <= div_cnt + 1'b1;
        end
        else
            div_cnt <= 16'd0;
	
	// bps_sys_clk gen
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            bps_sys_clk <= 1'b0;
        else if(div_cnt == 16'd1)
            bps_sys_clk <= 1'b1;
        else
            bps_sys_clk <= 1'b0;
	
	//bps counter
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)	
            bps_cnt <= 4'd0;
        else if(bps_cnt == 4'd11)
            bps_cnt <= 4'd0;
        else if(bps_sys_clk)
            bps_cnt <= bps_cnt + 1'b1;
        else
            bps_cnt <= bps_cnt;
		
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            Tx_Done <= 1'b0;
        else if(bps_cnt == 4'd11)
            Tx_Done <= 1'b1;
        else
            Tx_Done <= 1'b0;
		
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            tx <= 1'b1;
        else begin
            case(bps_cnt)
                0:tx <= 1'b1;
                1:tx <= START_BIT;
                2:tx <= r_data[0];
                3:tx <= r_data[1];
                4:tx <= r_data[2];
                5:tx <= r_data[3];
                6:tx <= r_data[4];
                7:tx <= r_data[5];
                8:tx <= r_data[6];
                9:tx <= r_data[7];
                10:tx <= STOP_BIT;
                default:tx <= 1'b1;
            endcase
        end	

endmodule


