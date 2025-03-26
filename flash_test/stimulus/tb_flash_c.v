`timescale 1ns / 1ps

module tb_flash_c;

    // Clock and reset signals
    reg clk;
    reg reset;
    
    // Command signals
    reg cmd_erasedies;
    reg cmd_write;
    reg cmd_read;
    reg [31:0] addr;
    reg [15:0] length;
    reg [7:0] din;
    
    // Output signals
    wire [7:0] dout;
    wire read;
    wire write;
    wire done;
    wire error;
    wire [3:0] cs;
    
    // Flash interface
    reg flash_q;
    wire [15:0] flash_c;
    wire flash_d;
    wire [15:0] flash_reset_n;
    
    // Instantiate the module under test
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
        .error(error),
        .cs(cs),
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_d(flash_d),
        .flash_reset_n(flash_reset_n)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #25 clk = ~clk; // 100MHz clock
    end
    
    // Simulate Flash response
    always @(posedge clk) begin
        // Simple Flash response simulation
        // In real scenarios, there should be more complex logic to simulate Flash behavior
        flash_q <= flash_d; // Simple data echo
    end
    
    // Test process
    initial begin
        // Initialization
        reset = 1;
        cmd_erasedies = 0;
        cmd_write = 0;
        cmd_read = 0;
        addr = 0;
        length = 0;
        din = 0;
        flash_q = 0;
        
        // Release reset
        #500;
        reset = 0;
        #100;
        
        // Test 1: Erase a sector in chip 0
        addr = 32'h00000000; // Select chip 0
        length = 16'd1;      // Erase 1 sector
        cmd_erasedies = 1;
        #50;
        cmd_erasedies = 0;
        
        // Wait for operation completion
        wait(done);
        #100;
        
        // Test 2: Write data to chip 1
        addr = 32'h10000100; // Select chip 1, address 0x100
        length = 16'd1;      // Write 1 page
        din = 8'hA5;         // Test data
        cmd_write = 1;
        #50;
        cmd_write = 0;
        
        // Wait for operation completion
        wait(done);
        #100;
        
        // Test 3: Read data from chip 1
        addr = 32'h10000100; // Select chip 1, address 0x100
        length = 16'd1;      // Read 1 page
        cmd_read = 1;
        #50;
        cmd_read = 0;
        
        // Wait for operation completion
        wait(done);
        #100;
        
        // Test 4: Erase a sector in chip 15
        addr = 32'hF0000000; // Select chip 15
        length = 16'd1;      // Erase 1 sector
        cmd_erasedies = 1;
        #50;
        cmd_erasedies = 0;
        
        // Wait for operation completion
        wait(done);
        #100;
        
        // Simulation end
        $display("Simulation completed");
        $finish;
    end
    
    // Monitor signals
    initial begin
        $monitor("Time=%0t, CS=%h, Done=%b, Error=%b, Read=%b, Write=%b, Dout=%h",
                 $time, cs, done, error, read, write, dout);
    end

endmodule
