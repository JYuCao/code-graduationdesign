
//`timescale <time_units> / <precision>

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
	
	reg s0_rx,s1_rx;
	
	reg tmp0_rx,tmp1_rx;
	
	reg [15:0]bps_DR;
	reg [15:0]div_cnt;
	reg bps_sys_clk;
	reg [7:0]bps_cnt;
	
	reg uart_state;
	
	reg [2:0] r_data_byte [7:0];
	reg [2:0] START_BIT,STOP_BIT;
	
	wire nedege;
	
    // Synchronize the signal rx to system clock domain
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)begin
            s0_rx <= 1'b0;
            s1_rx <= 1'b0;	
        end
        else begin
            s0_rx <= rx;
            s1_rx <= s0_rx;	
        end
	
    // Check the negedege of s1_rx
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)begin
            tmp0_rx <= 1'b0;
            tmp1_rx <= 1'b0;	
        end
        else begin
            tmp0_rx <= s1_rx;
            tmp1_rx <= tmp0_rx;	
        end
	
	assign nedege = !tmp0_rx & tmp1_rx;
	
    // set bps
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            bps_DR <= 16'd324;
        else begin
            case(baud_set)
                0:bps_DR <= 16'd324;
                1:bps_DR <= 16'd162;
                2:bps_DR <= 16'd80;
                3:bps_DR <= 16'd53;
                4:bps_DR <= 16'd26;
                default:bps_DR <= 16'd324;			
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
            bps_cnt <= 8'd0;
        else if(bps_cnt == 8'd159 | (bps_cnt == 8'd12 && (START_BIT > 2)))
            bps_cnt <= 8'd0;
        else if(bps_sys_clk)
            bps_cnt <= bps_cnt + 1'b1;
        else
            bps_cnt <= bps_cnt;

	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            Rx_Done <= 1'b0;
        else if(bps_cnt == 8'd159)
            Rx_Done <= 1'b1;
        else
            Rx_Done <= 1'b0;
	
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            data <= 8'd0;
        else if(bps_cnt == 8'd159)begin
            data[0] <= r_data_byte[0][2];
            data[1] <= r_data_byte[1][2];
            data[2] <= r_data_byte[2][2];
            data[3] <= r_data_byte[3][2];
            data[4] <= r_data_byte[4][2];
            data[5] <= r_data_byte[5][2];
            data[6] <= r_data_byte[6][2];
            data[7] <= r_data_byte[7][2];
        end	
		
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)begin
            START_BIT = 3'd0;
            r_data_byte[0] <= 3'd0;
            r_data_byte[1] <= 3'd0;
            r_data_byte[2] <= 3'd0;
            r_data_byte[3] <= 3'd0;
            r_data_byte[4] <= 3'd0;
            r_data_byte[5] <= 3'd0;
            r_data_byte[6] <= 3'd0;
            r_data_byte[7] <= 3'd0;
            STOP_BIT = 3'd0;
        end
        else if(bps_sys_clk)begin
            case(bps_cnt)
                0:begin
                        START_BIT = 3'd0;
                        r_data_byte[0] <= 3'd0;
                        r_data_byte[1] <= 3'd0;
                        r_data_byte[2] <= 3'd0;
                        r_data_byte[3] <= 3'd0;
                        r_data_byte[4] <= 3'd0;
                        r_data_byte[5] <= 3'd0;
                        r_data_byte[6] <= 3'd0;
                        r_data_byte[7] <= 3'd0;
                        STOP_BIT = 3'd0;			
                    end
                6,7,8,9,10,11:START_BIT <= START_BIT + s1_rx;
                22,23,24,25,26,27:r_data_byte[0] <= r_data_byte[0] + s1_rx;
                38,39,40,41,42,43:r_data_byte[1] <= r_data_byte[1] + s1_rx;
                54,55,56,57,58,59:r_data_byte[2] <= r_data_byte[2] + s1_rx;
                70,71,72,73,74,75:r_data_byte[3] <= r_data_byte[3] + s1_rx;
                86,87,88,89,90,91:r_data_byte[4] <= r_data_byte[4] + s1_rx;
                102,103,104,105,106,107:r_data_byte[5] <= r_data_byte[5] + s1_rx;
                118,119,120,121,122,123:r_data_byte[6] <= r_data_byte[6] + s1_rx;
                134,135,136,137,138,139:r_data_byte[7] <= r_data_byte[7] + s1_rx;
                150,151,152,153,154,155:STOP_BIT <= STOP_BIT + s1_rx;
                default:
                    begin
                        START_BIT = START_BIT;
                        r_data_byte[0] <= r_data_byte[0];
                        r_data_byte[1] <= r_data_byte[1];
                        r_data_byte[2] <= r_data_byte[2];
                        r_data_byte[3] <= r_data_byte[3];
                        r_data_byte[4] <= r_data_byte[4];
                        r_data_byte[5] <= r_data_byte[5];
                        r_data_byte[6] <= r_data_byte[6];
                        r_data_byte[7] <= r_data_byte[7];
                        STOP_BIT = STOP_BIT;						
                    end
            endcase
        end
	
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            uart_state <= 1'b0;
        else if(nedege)
            uart_state <= 1'b1;
        else if(Rx_Done || (bps_cnt == 8'd12 && (START_BIT > 2)))
            uart_state <= 1'b0;
        else
            uart_state <= uart_state;		

endmodule



