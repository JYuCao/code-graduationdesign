`timescale 1ns / 1ps

module tb_flash_b_wr;
    // Clock and reset signals
    reg clk;
    reg reset;
    
    // Control signals
    reg cmd_write;
    reg cmd_read;
    reg cmd_dieerase;
    reg [23:0] addr;
    reg [15:0] length;
    reg [7:0] din;
    wire [7:0] dout;
    wire read;
    wire write;
    wire done;
    wire [15:0] status;
    
    // Flash interface signals
    wire flash_q;
    wire flash_c;
    wire flash_s_n;
    wire flash_d;

    // Instantiate the module under test
    flash_b uut (
        .clk(clk),
        .reset(reset),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .cmd_dieerase(cmd_dieerase),
        .addr(addr),
        .length(length),
        .din(din),
        .dout(dout),
        .read(read),
        .write(write),
        .done(done),
        .status(status),
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_s_n(flash_s_n),
        .flash_d(flash_d)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #25 clk = ~clk;
    end

    // Test process
    initial begin
        // Initialization
        reset = 1;
        cmd_write = 0;
        cmd_read = 0;
        cmd_dieerase = 0;
        addr = 0;
        length = 0;
        din = 0;
        
        // Wait for several clock cycles then release reset
        #500;
        reset = 0;
        #100;

        // Test write operation
        $display("Starting write test...");
        addr = 24'h000000;
        length = 16'h0001;  // Write one page
        din = 8'hA5;       // Test data
        cmd_write = 1;
        $display("Write data: %h", din);
        #50;
        cmd_write = 0;
        
        // Wait for write completion
        wait(done);
        #500;

        // Test read operation
        $display("Starting read test...");
        addr = 24'h000000;
        length = 16'h0001;  // Read one page
        cmd_read = 1;
        $display("Read data: %h", dout);
        #50;
        cmd_read = 0;
        
        // Wait for read completion
        wait(done);
        #500;

        // Test large capacity read
        $display("Starting large capacity read test...");
        addr = 24'h000000;
        length = 16'h0080;  // Read 128 pages (2GB)
        cmd_read = 1;
        #50;
        cmd_read = 0;
        
        // Wait for a while then end simulation
        #5000;
        
        $display("Simulation completed");
        $finish;
    end

endmodule
