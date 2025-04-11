//------------------------------------------------------------------------
// eeprom_b.v
//    这是EEPROM "B"控制器，用于处理宏命令，如读取、写入和擦除等操作。
//    该控制器使用"A"控制器进行直接的EEPROM控制。
//
// 命令:
//  WRITE_ENABLE - 写使能
//  WRITE - 写入数据
//     + ADDR是要写入的地址 (0..8191)
//     + LENGTH是要写入的字节数
//  READ - 读取数据
//     + ADDR是要读取的地址 (0..8191)
//     + LENGTH是要读取的字节数
//------------------------------------------------------------------------

`default_nettype none
`timescale 1ns / 1ps
module eeprom_b(
	input  wire        clk,
	input  wire        reset,

	input  wire        cmd_write,
	input  wire        cmd_read,
	input  wire [15:0] addr,      // NV25640有8K字节，使用13位地址即可
	input  wire [7:0]  din,
	output reg  [7:0]  dout,
	output reg         busy,
	
	// EEPROM SPI接口
	input  wire        eeprom_q,  // MISO
	output wire        eeprom_c,  // SCK
	output wire        eeprom_s_n, // CS_N
	output wire        eeprom_d    // MOSI
	);

reg        a_write;
reg        a_read;
reg        a_deselect;
wire       a_done;
wire [7:0] a_dout;
reg  [7:0] a_din;

reg  [15:0] count_a;

reg read;
reg write;
reg done;



eeprom_a e0(
	.clk(clk),
	.reset(reset),
	.write(a_write),
	.read(a_read),
	.deselect(a_deselect),
	.din(a_din),
	.dout(a_dout),
	.done(a_done),
	.eeprom_c(eeprom_c),
	.eeprom_s_n(eeprom_s_n),
	.eeprom_d(eeprom_d),
	.eeprom_q(eeprom_q));

parameter s_idle       = 0,
          
          // 写使能状态
          s_wren       = 1,
          s_wren_w     = 2,
          
          // 写入数据状态
          s_write1     = 3,
          s_write1w    = 4,
          s_write2     = 5,
          s_write2w    = 6,
          s_write3     = 7,
          s_write3w    = 8,
          s_write4     = 9,
          s_write4w    = 10,
          
          // 读取状态寄存器
          s_rdsr       = 13,
          s_rdsr_w     = 14,
          s_rdsr_check = 15,
          
          // 读取数据状态
          s_read1      = 16,
          s_read1w     = 17,
          s_read2      = 18,
          s_read2w     = 19,
          s_read3      = 20,
          s_read3w     = 21,
          s_read4      = 22,
          s_read4w     = 23,
          s_read5      = 24;

reg [7:0] state;
always @(posedge clk) begin
	if (reset == 1'b1) begin
		state <= s_idle;
		done <= 1'b0;
		read <= 1'b0;
		write <= 1'b0;
        busy <= 1'b0;
	end else begin
		done <= 1'b0;
		read <= 1'b0;
		write <= 1'b0;
		a_write <= 1'b0;
		a_read  <= 1'b0;
		a_deselect <= 1'b0;

		case (state)
			s_idle: begin
				if (cmd_write == 1'b1) begin
					state <= s_wren;
					count_a <= addr;
                    busy <= 1'b1;
				end else if (cmd_read == 1'b1) begin
					state <= s_read1;
					count_a <= addr;
                    busy <= 1'b1;
				end
			end

			//===============================================================
			// 写使能
			//===============================================================
			s_wren: begin
				a_write <= 1'b1;
				a_deselect <= 1'b1;
				a_din <= 8'h06;  // WREN命令
				state <= s_wren_w;
			end
			s_wren_w: begin
				if (a_done == 1'b1)
					state <= s_write1;
			end
			
			//===============================================================
			// 写入数据
			//===============================================================
			// WRITE命令
			s_write1: begin
				a_write <= 1'b1;
				a_din <= 8'h02;  // WRITE命令
				state <= s_write1w;
			end
			s_write1w: begin
				if (a_done == 1'b1)
					state <= s_write2;
			end

			// 地址高8位
			s_write2: begin
				a_write <= 1'b1;
				a_din <= count_a[15:8];
				state <= s_write2w;
			end
			s_write2w: begin
				if (a_done == 1'b1)
					state <= s_write3;
			end

			// 地址低8位
			s_write3: begin
				a_write <= 1'b1;
				a_din <= count_a[7:0];
				state <= s_write3w;
			end
			s_write3w: begin
				if (a_done == 1'b1) begin
					state <= s_write4;
				end
			end

			// 写入数据
			s_write4: begin
				a_write <= 1'b1;
				a_din <= din;
                a_deselect <= 1'b1;
				state <= s_write4w;
			end
			s_write4w: begin
                if (a_done == 1'b1) begin
                    state <= s_rdsr;
				end
			end
			
			//===============================================================
			// 读取状态寄存器
			//===============================================================
			s_rdsr: begin
				a_write <= 1'b1;
				a_din <= 8'h05;  // RDSR命令
				state <= s_rdsr_w;
			end
			s_rdsr_w: begin
				if (a_done == 1'b1)
					state <= s_rdsr_check;
			end

			s_rdsr_check: begin
				a_read <= 1'b1;
				a_deselect <= 1'b1;
				if (a_done == 1'b1) begin
					if (a_dout[0] == 1'b1)
						state <= s_rdsr;  // WIP位为1，继续等待
                    else begin
						done <= 1'b1;
                        busy <= 1'b0;
						state <= s_idle;
					end
				end
			end

			//===============================================================
			// 读取数据
			//===============================================================
			// READ命令
			s_read1: begin
				a_write <= 1'b1;
				a_din <= 8'h03;  // READ命令
				state <= s_read1w;
			end
			s_read1w: begin
				if (a_done == 1'b1)
					state <= s_read2;
			end

			// 地址高8位
			s_read2: begin
				a_write <= 1'b1;
				a_din <= count_a[15:8];
				state <= s_read2w;
			end
			s_read2w: begin
				if (a_done == 1'b1)
					state <= s_read3;
			end

			// 地址低8位
			s_read3: begin
				a_write <= 1'b1;
				a_din <= count_a[7:0];
				state <= s_read3w;
			end
			s_read3w: begin
				if (a_done == 1'b1) begin
					state <= s_read4;
				end
			end

			// 读取数据
			s_read4: begin
				a_read <= 1'b1;
				a_deselect <= 1'b1;
				state <= s_read4w;
			end
			s_read4w: begin
				if (a_done == 1'b1) begin
					write <= 1'b1;
					dout <= a_dout;
					state <= s_read5;
				end
			end
			
			s_read5: begin
				done <= 1'b1;
                busy <= 1'b0;
				state <= s_idle;
			end
		endcase
	end
end

endmodule
`default_nettype wire
