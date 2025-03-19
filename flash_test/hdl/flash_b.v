    
`default_nettype none
`timescale 1ns / 1ps
module flash_b(
	input  wire        clk,
	input  wire        reset,

	input  wire        cmd_erasedies,
	input  wire        cmd_write,
	input  wire        cmd_read,
	input  wire [27:0] addr,
    input  wire [15:0] length,
	input  wire [7:0]  din,
	output reg  [7:0]  dout,
	output reg         read,
	output reg         write,
	output reg         done,
	output reg         error,
	
	// Flash interface
	input  wire        flash_q,
	output wire        flash_c,
	output wire        flash_s_n,
	output wire        flash_d
	);

reg        a_write;
reg        a_read;
reg        a_deselect;
wire       a_done;
wire [7:0] a_dout;
reg  [7:0] a_din;

reg  [27:0] count_a;
reg  [15:0] count_b;
reg  [29:0] count_c;

flash_a f0(
	.clk(clk),
	.reset(reset),
	.write(a_write),
	.read(a_read),
	.deselect(a_deselect),
	.din(a_din),
	.dout(a_dout),
	.done(a_done),
	.flash_c(flash_c),
	.flash_s_n(flash_s_n),
	.flash_d(flash_d),
	.flash_q(flash_q));

parameter s_idle       = 0,

          s_die_erase1      = 1,
          s_die_erase1w     = 2,
          s_die_erase2      = 3,
          s_die_erase2w     = 4,
          s_die_erase3      = 5,
          s_die_erase3w     = 6,
          s_die_erase4      = 7,
          s_die_erase4w     = 8,
          s_die_erase5      = 9,
          s_die_erase5w     = 10,
          s_die_erase6      = 11,
          s_die_erase6w     = 12,
          s_die_erase7      = 13,
          s_die_erase7w     = 14,
          s_die_erase8      = 15,
          s_die_erase8w     = 16,
          s_die_erase9      = 17,
          s_die_erase9w     = 18,
          s_die_erase10     = 19,
          s_die_erase10w    = 20,
          s_die_erase11     = 21,

          s_write1     = 22,
          s_write1w    = 23,
          s_write2     = 24,
          s_write2w    = 25,
          s_write3     = 26,
          s_write3w    = 27,
          s_write4     = 28,
          s_write4w    = 29,
          s_write5     = 30,
          s_write5w    = 31,
          s_write6     = 32,
          s_write6w    = 33,
          s_write7     = 34,
          s_write7w    = 35,
          s_write8     = 36,
          s_write8w    = 37,
          s_write9     = 38,
          s_write9w    = 39,
          s_write10    = 40,

          s_read1      = 41,
          s_read1w     = 42,
          s_read2      = 43,
          s_read2w     = 44,
          s_read3      = 45,
          s_read3w     = 46,
          s_read4      = 47,
          s_read4w     = 48,
          s_read5      = 49,
          s_read5w     = 50,
          s_read6      = 51,
          s_read6w     = 52,
          s_read7      = 53,
          s_read7w      = 54,
          s_read8      = 55;

reg [31:0] state;
always @(posedge clk) begin
	if (reset == 1'b1) begin
		state <= s_idle;
		done <= 1'b0;
        error <= 1'b0;
		read <= 1'b0;
		write <= 1'b0;
	end else begin
		done <= 1'b0;
        error <= 1'b0;
		read <= 1'b0;
		write <= 1'b0;
		a_write <= 1'b0;
		a_read  <= 1'b0;
		a_deselect <= 1'b0;
		
		case (state)
			s_idle: begin
				if (cmd_erasedies == 1'b1) begin
					state <= s_die_erase1;
                    count_a <= {16'h0000, addr[27:16]};
					count_b <= length;
				end 
                else if (cmd_write == 1'b1) begin
					state <= s_write1;
                    count_a <= addr;
				end 
                else if (cmd_read == 1'b1) begin
					state <= s_read1;
                    count_a <= {16'h0000, addr[27:16]};
					count_b <= length;
                    //count_c <= 30'h20000000;
                    count_c <= 30'h00001000;
				end
			end

            //===============================================================
			// ERASE DIE
			//===============================================================
			// WREN
            s_die_erase1: begin
				a_write    <= 1'b1;
				a_deselect <= 1'b1;
				a_din      <= 8'h06;    
				state <= s_die_erase1w;
			end
			s_die_erase1w: begin
				if (a_done == 1'b1)
					state <= s_die_erase2;
			end

            // DE
			s_die_erase2: begin
				a_write <= 1'b1;
				a_din <= 8'hc4;
				state <= s_die_erase2w;
			end
			s_die_erase2w: begin
				if (a_done == 1'b1)
					state <= s_die_erase3;
			end

            // ADDR[31:24]			
			s_die_erase3: begin
				a_write <= 1'b1;
				a_din <= {4'b0000, count_a[11:8]};
				state <= s_die_erase3w;
			end
			s_die_erase3w: begin
				if (a_done == 1'b1)
					state <= s_die_erase4;
			end

			// ADDR[23:16]			
			s_die_erase4: begin
				a_write <= 1'b1;
				a_din <= count_a[7:0];
				state <= s_die_erase4w;
			end
			s_die_erase4w: begin
				if (a_done == 1'b1)
					state <= s_die_erase5;
			end

			// ADDR[15:8]
			s_die_erase5: begin
				a_write <= 1'b1;
				a_din <= 8'h00;
				state <= s_die_erase5w;
			end
			s_die_erase5w: begin
				if (a_done == 1'b1)
					state <= s_die_erase6;
			end

            // ADDR[7:0]
			s_die_erase6: begin
				a_write <= 1'b1;
				a_din <= 8'h00;
				a_deselect <= 1'b1;
				state <= s_die_erase6w;
			end
			s_die_erase6w: begin
				if (a_done == 1'b1)
					state <= s_die_erase7;
			end

			// RDSR
			s_die_erase7: begin
				a_write <= 1'b1;
				a_din <= 8'h05;
				state <= s_die_erase7w;
			end
			s_die_erase7w: begin
				if (a_done == 1'b1)
					state <= s_die_erase8;
			end

			s_die_erase8: begin
				a_read <= 1'b1;
				a_deselect <= 1'b1;
				state <= s_die_erase8w;
			end
			s_die_erase8w: begin
				if (a_done == 1'b1) begin
					if (a_dout[0] == 1'b1)
						state <= s_die_erase7;
					else
						state <= s_die_erase9;
				end
			end

            // RDFSR
			s_die_erase9: begin
				a_write <= 1'b1;
				a_din <= 8'h70;
				state <= s_die_erase9w;
			end
			s_die_erase9w: begin
				if (a_done == 1'b1)
					state <= s_die_erase10;
			end

			s_die_erase10: begin
				a_read <= 1'b1;
				a_deselect <= 1'b1;
				state <= s_die_erase10w;
			end
			s_die_erase10w: begin
				if (a_done == 1'b1) begin
					if (a_dout[5] == 1'b1)
						error <= 1'b1;
                state <= s_die_erase11;
				end
			end

			// Loop until all requested dies are erased.
			s_die_erase11: begin
				count_b <= count_b - 1;
				count_a <= count_a + 1024;
				if (count_b == 0) begin
					state <= s_idle;
					done <= 1'b1;
				end else begin
					state <= s_die_erase1;
				end
			end


			//===============================================================
			// WRITE DATA
			//===============================================================
			// WREN
			s_write1: begin
				a_write <= 1'b1;
				a_deselect <= 1'b1;
				a_din <= 8'h06;
				state <= s_write1w;
			end
			s_write1w: begin
				if (a_done == 1'b1)
					state <= s_write2;
			end
			
			// 4BPP
			s_write2: begin
				a_write <= 1'b1;
				a_din <= 8'h12; 
				state <= s_write2w;
			end
			s_write2w: begin
				if (a_done == 1'b1)
					state <= s_write3;
			end

			// ADDR[31:24]
			s_write3: begin
				a_write <= 1'b1;
				a_din <= {4'b0000, count_a[27:24]};
				state <= s_write3w;
			end
			s_write3w: begin
				if (a_done == 1'b1)
					state <= s_write4;
			end

			// ADDR[23:16]
			s_write4: begin
				a_write <= 1'b1;
				a_din <= count_a[23:16];
				state <= s_write4w;
			end
			s_write4w: begin
				if (a_done == 1'b1)
					state <= s_write5;
			end

			// ADDR[15:8]
			s_write5: begin
				a_write <= 1'b1;
				a_din <= count_a[15:8];
				state <= s_write5w;
			end
			s_write5w: begin
				if (a_done == 1'b1) begin
					state <= s_write6;
				end
			end

            // ADDR[7:0]
			s_write6: begin
				a_write <= 1'b1;
				a_din <= count_a[7:0];
				read <= 1'b1;			// Gets the first data word ready.
				state <= s_write6w;
			end
			s_write6w: begin
				if (a_done == 1'b1) begin
					state <= s_write7;
				end
			end

			// DATA
			s_write7: begin
				state <= s_write7w;
				a_write <= 1'b1;
				a_din <= din;
				a_deselect <= 1'b1;
			end
			s_write7w: begin
				if (a_done == 1'b1) begin
					state <= s_write8;
				end
			end
			
			// RDSR
			s_write8: begin
				a_write <= 1'b1;
				a_din <= 8'h05;
				state <= s_write8w;
			end
			s_write8w: begin
				if (a_done == 1'b1)
					state <= s_write9;
			end

			s_write9: begin
				a_read <= 1'b1;
				a_deselect <= 1'b1;
				state <= s_write9w;
			end

			s_write9w: begin
				if (a_done == 1'b1) begin
					if (a_dout[0] == 1'b1)
						state <= s_write8;
					else
						state <= s_write10;
				end
			end

			
			s_write10: begin
				done <= 1'b1;
				state <= s_idle;
			end


            //===============================================================
			// READ DATA
			//===============================================================
			// 4Byte FAST_READ
			s_read1: begin
				a_write <= 1'b1;
				a_din <= 8'h0c;
				state <= s_read1w;
			end
			s_read1w: begin
				if (a_done == 1'b1)
					state <= s_read2;
			end

            // ADDR[31:24]
			s_read2: begin
				a_write <= 1'b1;
				a_din <= {4'b0000, count_a[27:24]};
				state <= s_read2w;
			end
			s_read2w: begin
				if (a_done == 1'b1)
					state <= s_read3;
			end

			// ADDR[23:16]
			s_read3: begin
				a_write <= 1'b1;
				a_din <= count_a[23:16];
				state <= s_read3w;
			end
			s_read3w: begin
				if (a_done == 1'b1)
					state <= s_read4;
			end

			// ADDR[15:8]
			s_read4: begin
				a_write <= 1'b1;
				a_din <= 8'h00;
				state <= s_read4w;
			end
			s_read4w: begin
				if (a_done == 1'b1)
					state <= s_read5;
			end

			// ADDR[7:0]
			s_read5: begin
				a_write <= 1'b1;
				a_din <= 8'h00;
				state <= s_read5w;
			end
			s_read5w: begin
				if (a_done == 1'b1) begin
					state <= s_read6;
				end
			end

			// DUMMY
			s_read6: begin
				a_read <= 1'b1;
				state <= s_read6w;
			end
			s_read6w: begin
				if (a_done == 1'b1) begin
					state <= s_read7;
				end
			end

			// DATA[n]
			s_read7: begin
				a_read <= 1'b1;
				state <= s_read7w;
				if (count_c == 0) begin
					a_deselect <= 1'b1;
				end
			end
			s_read7w: begin
				if (a_done == 1'b1) begin
					write <= 1'b1;
					dout <= a_dout;
					state <= s_read8;
				end
			end
			
			s_read8: begin
				count_c <= count_c - 1;
				if (count_c == 0) begin
					state <= s_idle;
					done <= 1'b1;
				end else begin
					state <= s_read7;
				end
			end

    
		endcase
	end

end

endmodule
`default_nettype wire
