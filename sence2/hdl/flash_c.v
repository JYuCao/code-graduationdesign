`default_nettype none
`timescale 1ns / 1ps
module flash_c(
    input  wire        clk,
    input  wire        reset,

    input  wire        cmd_erasedies,
    input  wire        cmd_write,
    input  wire        cmd_read,
    input  wire [31:0] addr,
    input  wire [15:0] length,
    input  wire [7:0]  din,
    output reg  [7:0]  dout,
    output reg         read,
    output reg         write,
    output reg         done,
    output reg         error,
    output wire        busy,

    // Flash Interface
    input  wire        flash_q,
    output wire [15:0] flash_c,
    output wire        flash_d,
    output wire [15:0] flash_reset_n,  // 16-bit reset output
    output wire [15:0] flash_s_n
    );

    
    wire [3:0] chip_select = addr[31:28];
 
    
    wire [15:0] flash_done;
    wire [15:0] flash_error;
    wire [15:0] flash_read;
    wire [15:0] flash_write;
    wire [7:0] flash_dout [15:0];

    wire [15:0] flash_s_n_array;
    assign flash_s_n = flash_s_n_array;

    wire [15:0] flash_c_array;
    wire [15:0] flash_d_array;

    parameter s_idle = 0, s_operate = 1;
    reg [1:0] state;
    
    // All chips share the same flash_d
    assign flash_d = flash_d_array[chip_select];
    
    // Each chip has independent flash_c clock line
    assign flash_c = flash_c_array;

    // Busy
    assign busy = (state == s_operate);
    
    // Generate reset signal, reset corresponding chip when system reset or not selected
    genvar r;
    generate
        for (r = 0; r < 16; r = r + 1) begin : reset_gen
            assign flash_reset_n[r] = reset ? 1'b0 : 1'b1;
        end
    endgenerate

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : flash_array
            flash_b flash_inst (
                .clk(clk),
                .reset(reset),
                .cmd_erasedies(cmd_erasedies && (chip_select == i)),
                .cmd_write(cmd_write && (chip_select == i)),
                .cmd_read(cmd_read && (chip_select == i)),
                .addr(addr[27:0]),
                .length(length),
                .din(din),
                .dout(flash_dout[i]),
                .read(flash_read[i]),
                .write(flash_write[i]),
                .done(flash_done[i]),
                .error(flash_error[i]),
                .flash_q(flash_q),
                .flash_c(flash_c_array[i]),
                .flash_s_n(flash_s_n_array[i]),
                .flash_d(flash_d_array[i])  
            );
        end
    endgenerate

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
            case (state)
                s_idle: begin
                    if (cmd_erasedies || cmd_write || cmd_read) begin
                        state <= s_operate;
                    end
                end
                s_operate: begin
                    if (flash_done[chip_select]) begin
                        done <= 1'b1;
                        error <= flash_error[chip_select];
                        read <= flash_read[chip_select];
                        write <= flash_write[chip_select];
                        dout <= flash_dout[chip_select];
                        state <= s_idle;
                    end
                end
            endcase
        end
    end

endmodule
`default_nettype wire
