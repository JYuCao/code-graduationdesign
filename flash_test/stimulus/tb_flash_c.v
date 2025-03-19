`timescale 1ns / 1ps

module tb_flash_c;

    // Clock and reset signals
    reg clk;
    reg reset;
    
    // Control signals
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
    
    // Flash interface signals
    wire flash_q;
    wire flash_c;
    wire flash_d;
    
    // Simulated Flash input
    reg flash_q_reg;
    assign flash_q = flash_q_reg;
    
    // Instantiate DUT (Device Under Test)
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
        .flash_d(flash_d)
    );
    
    // Clock generation - 20MHz (50ns period)
    always #25 clk = ~clk;
    
    // Test data storage
    reg [7:0] test_data [0:255];
    integer i;
    
    // Flash response simulation
    always @(posedge clk) begin
        if (flash_c && flash_d) begin
            // Simulate write response
            flash_q_reg <= 1'b1;
        end else if (flash_c && !flash_d) begin
            // Simulate read response
            flash_q_reg <= test_data[i % 256];
            i <= i + 1;
        end else begin
            flash_q_reg <= 1'b0;
        end
    end
    
    // Test procedure
    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        cmd_erasedies = 0;
        cmd_write = 0;
        cmd_read = 0;
        addr = 0;
        length = 16'd1;
        din = 0;
        flash_q_reg = 0;
        i = 0;
        
        // Initialize test data
        for (i = 0; i < 256; i = i + 1) begin
            test_data[i] = i;
        end
        i = 0;
        
        // Release reset
        #100;
        reset = 0;
        #100;
        
        // Test 1: Erase Chip 0
        $display("Test 1: Erase Chip 0 at time %t", $time);
        addr = 32'h00000000;  // Chip 0
        cmd_erasedies = 1;
        #50;
        cmd_erasedies = 0;
        
        // Wait for operation complete
        wait(done);
        #100;
        
        // Test 2: Write to Chip 1
        $display("Test 2: Write to Chip 1 at time %t", $time);
        addr = 32'h10000000;  // Chip 1
        length = 16'd4;
        cmd_write = 1;
        
        // Write 4 bytes
        for (i = 0; i < 4; i = i + 1) begin
            din = 8'hA0 + i;
            #50;
        end
        cmd_write = 0;
        
        // Wait for operation complete
        wait(done);
        #100;
        
        // Test 3: Read from Chip 1
        $display("Test 3: Read from Chip 1 at time %t", $time);
        addr = 32'h10000000;  // Chip 1
        length = 16'd4;
        cmd_read = 1;
        #50;
        cmd_read = 0;
        
        // Wait for operation complete
        wait(done);
        #100;
        
        // Test 4: Write to Chip 15 (highest chip)
        $display("Test 4: Write to Chip 15 at time %t", $time);
        addr = 32'hF0000000;  // Chip 15
        length = 16'd2;
        cmd_write = 1;
        
        // Write 2 bytes
        for (i = 0; i < 2; i = i + 1) begin
            din = 8'hF0 + i;
            #50;
        end
        cmd_write = 0;
        
        // Wait for operation complete
        wait(done);
        #100;
        
        // Test 5: Read from Chip 15
        $display("Test 5: Read from Chip 15 at time %t", $time);
        addr = 32'hF0000000;  // Chip 15
        length = 16'd2;
        cmd_read = 1;
        #50;
        cmd_read = 0;
        
        // Wait for operation complete
        wait(done);
        #100;
        
        // Test 6: Concurrent operations test (write then read)
        $display("Test 6: Concurrent operations test at time %t", $time);
        addr = 32'h20000000;  // Chip 2
        length = 16'd1;
        din = 8'hCC;
        cmd_write = 1;
        #50;
        cmd_write = 0;
        
        // Start read operation immediately without waiting
        addr = 32'h30000000;  // Chip 3
        cmd_read = 1;
        #50;
        cmd_read = 0;
        
        // Wait for all operations complete
        wait(done);
        #100;
        
        // Test 7: Invalid address test
        $display("Test 7: Invalid address test at time %t", $time);
        addr = 32'hFFFFFFFF;  // Invalid address
        cmd_read = 1;
        #50;
        cmd_read = 0;
        
        // Wait for operation complete
        wait(done);
        #100;
        
        // Tests completed
        $display("All tests completed at time %t", $time);
        #500;
        $finish;
    end
    
    // Signal monitoring
    initial begin
        $monitor("Time=%t, CS=%h, Done=%b, Error=%b, Read=%b, Write=%b, Dout=%h", 
                 $time, cs, done, error, read, write, dout);
    end

endmodule
