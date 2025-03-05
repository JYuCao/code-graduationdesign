`timescale 1ns / 1ps

module tb_eeprom;

    // Inputs
    reg clk;
    reg rst;
    reg spi_miso;
    reg [7:0] data_in;
    reg [15:0] addr;
    reg read;
    reg write;

    // Outputs
    wire spi_mosi;
    wire spi_sck;
    wire spi_cs;
    wire [7:0] data_out;
    wire busy;

    // Instantiate the Unit Under Test (UUT)
    spi_eeprom uut (
        .clk(clk),
        .rst(rst),
        .spi_miso(spi_miso),
        .spi_mosi(spi_mosi),
        .spi_sck(spi_sck),
        .spi_cs(spi_cs),
        .data_in(data_in),
        .data_out(data_out),
        .addr(addr),
        .read(read),
        .write(write),
        .busy(busy)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 1;
        spi_miso = 0;
        data_in = 8'h00;
        addr = 16'h0000;
        read = 0;
        write = 0;

        // Wait for global reset to finish
        #100;
        rst = 0;

        // Write operation
        addr = 16'h0010;
        data_in = 8'hA5;
        write = 1;
        #10;
        write = 0;

        // Wait for write to complete
        wait (!busy);
        #100;
        // Read operation
        addr = 16'h0001;
        read = 1;
        #10;
        read = 0;

        // Wait for read to complete
        wait (!busy);

        // Check the read data
        if (data_out == 8'hA5) begin
            $display("Read/Write operation successful");
        end else begin
            $display("Read/Write operation failed");
        end

        // Finish simulation
        #100;
        $finish;
    end

endmodule
