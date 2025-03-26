`timescale 1ns / 1ps

module tb_flash_c;

    reg clk;
    reg reset;
    reg cmd_erasedies;
    reg cmd_write;
    reg cmd_read;
    reg [31:0] addr;
    reg [15:0] length;
    reg [7:0] din;

    wire [7:0] dout;
    wire read;
    wire write;
    wire done;
    wire error;
    wire [3:0] cs;

    flash_c uut (
        .clk(clk),
        .reset(reset),
        .cmd_erasedies(cmd_erasedies),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .addr(addr),
        .length(length),
        .din(din),
        .dout(dout),
        .read(read),
        .write(write),
        .done(done),
        .error(error)
    );

    always #5 clk = ~clk;

    initial begin
    
        clk = 0;
        reset = 1;
        cmd_erasedies = 0;
        cmd_write = 0;
        cmd_read = 0;
        addr = 0;
        length = 0;
        din = 0;

     
        #10;
        reset = 0;

   
        #10;
        addr = 32'hC3210000; 
        cmd_write = 1;
        din = 8'hAA;
        #10;
        cmd_write = 0;

        
        wait(done);
        #10;

    
        addr = 32'hB1230000; 
        cmd_read = 1;
        #10;
        cmd_read = 0;

    
        wait(done);
        #10;


        addr = 32'hA2310000; 
        cmd_erasedies = 1;
        #10;
        cmd_erasedies = 0;

       
        wait(done);
        #10;

     
        $stop;
    end

endmodule
