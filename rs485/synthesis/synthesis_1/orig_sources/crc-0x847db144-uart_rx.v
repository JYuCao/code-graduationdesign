
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
	reg bps_sam_plus;
	reg [7:0]bps_cnt;
	
	reg uart_state;
	
	reg START_BIT;
    reg STOP_BIT;
	
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

    // 20M
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            bps_DR <= 16'd2083;
        else begin
            case(baud_set)
                0: bps_DR <= 16'd2083;  // 9600 
                1: bps_DR <= 16'd1041;  // 19200
                2: bps_DR <= 16'd520;   // 38400
                3: bps_DR <= 16'd346;   // 57600
                4: bps_DR <= 16'd173;   // 115200
                default: bps_DR <= 16'd2083;
            endcase
        end
	
	//counter
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            div_cnt <= 16'd0;
        else if(uart_state)begin
            if(div_cnt >= bps_DR - 1)
                div_cnt <= 16'd0;
            else
                div_cnt <= div_cnt + 1'b1;
        end
        else
            div_cnt <= 16'd0;
		
	// bps_sam_plus gen
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            bps_sam_plus <= 1'b0;
        else if(div_cnt == bps_DR / 2)
            bps_sam_plus <= 1'b1;
        else
            bps_sam_plus <= 1'b0;
	
	//bps counter
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)	
            bps_cnt <= 8'd0;
        else if(bps_cnt == 8'd11)
            bps_cnt <= 8'd0;
        else if(div_cnt == bps_DR - 2)
            bps_cnt <= bps_cnt + 1'b1;
        else
            bps_cnt <= bps_cnt;

	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            Rx_Done <= 1'b0;
        else if(bps_cnt == 8'd10 && (div_cnt == bps_DR - 3))
            Rx_Done <= 1'b1;
        else
            Rx_Done <= 1'b0;

    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            data <= 8'd0;
        else if (bps_sam_plus)
            data[bps_cnt-1] <= tmp0_rx;
            //if (bps_cnt == 8'd1) begin
                //if (tmp0_rx != 1'b0)
                    //uart_state <= 1'b0;
            //end else if (bps_cnt == 8'd10) begin
                //STOP_BIT <= tmp0_rx;
            //end else begin
                //r_data_byte[bps_cnt-1] <= tmp0_rx;
            //end
                
        //end

    //always@(posedge sys_clk or negedge sys_rst_n)
        //if(!sys_rst_n)
            //data <= 8'd0;
        //else if(bps_cnt == 8'd11) begin
            //if (STOP_BIT == 1'b1) begin
                //data <= r_data_byte;
            //end
        //end	
	
	always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            uart_state <= 1'b0;
        else if(nedege)
            uart_state <= 1'b1;
        else if(Rx_Done)
            uart_state <= 1'b0;
        else
            uart_state <= uart_state;

endmodule



