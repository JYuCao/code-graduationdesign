`timescale 1ns / 1ps

module tb_eeprom;

    // Clock and reset signals
    reg clk;
    reg reset;
    wire busy;
    
    // Control signals
    reg cmd_write;
    reg cmd_read;
    reg [15:0] addr;
    reg [15:0] length;
    reg [7:0] din;
    wire [7:0] dout;
    wire [15:0] status;
    
    // EEPROM SPI interface
    wire eeprom_q;
    wire eeprom_c;
    wire eeprom_s_n;
    wire eeprom_d;
    
    // Simulated EEPROM data
    reg [7:0] read_data;
    reg [7:0] last_written_data [0:3]; // ?????????????????    
    // Instantiate EEPROM controller
    eeprom_b uut (
        .clk(clk),
        .reset(reset),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .addr(addr),
        .length(length),
        .din(din),
        .dout(dout),
        .eeprom_q(eeprom_q),
        .eeprom_c(eeprom_c),
        .eeprom_s_n(eeprom_s_n),
        .eeprom_d(eeprom_d),
        .busy(busy)
    );
    
    // Clock generation - 20MHz (50ns period)
    initial begin
        clk = 0;
        forever #25 clk = ~clk; // 20MHz clock
    end
    
    // Simulate EEPROM SPI interface
    reg [7:0] spi_cmd;
    reg [15:0] spi_addr;
    reg [7:0] spi_data;
    reg [3:0] bit_count;
    reg wip_flag; // Write in progress flag
    reg [1:0] byte_index; // ??????last_written_data???
    
    // Simulate MISO signal
    assign eeprom_q = read_data[7];
    
    // SPI interface simulation
    always @(posedge eeprom_c or posedge reset) begin
        if (reset) begin
            bit_count <= 0;
            spi_cmd <= 0;
            spi_addr <= 0;
            spi_data <= 0;
            byte_index <= 0;
        end else if (!eeprom_s_n) begin
            // Receive command byte
            if (bit_count < 8) begin
                spi_cmd <= {spi_cmd[6:0], eeprom_d};
                bit_count <= bit_count + 1;
            end 
            // Receive address bytes
            else if (bit_count < 24) begin
                spi_addr <= {spi_addr[14:0], eeprom_d};
                bit_count <= bit_count + 1;
                if (bit_count == 23) begin
                    byte_index <= spi_addr[1:0]; // ????????????
                end
            end 
            // Receive/send data bytes
            else begin
                if (spi_cmd == 8'h02) begin // Write command
                    spi_data <= {spi_data[6:0], eeprom_d};
                    if (bit_count[2:0] == 3'b111) begin
                        // ?????????????????????                        last_written_data[byte_index] <= {spi_data[6:0], eeprom_d};
                        byte_index <= byte_index + 1;
                        spi_addr <= spi_addr + 1;
                    end
                end
                bit_count <= bit_count + 1;
            end
        end
    end
    
    // Simulate EEPROM read operation
    always @(negedge eeprom_c) begin
        if (!eeprom_s_n) begin
            if (bit_count >= 24 && spi_cmd == 8'h03) begin // Read command
                if (bit_count[2:0] == 3'b000) begin
                    // ??????????                    read_data <= last_written_data[byte_index];
                    byte_index <= byte_index + 1;
                    spi_addr <= spi_addr + 1;
                end else begin
                    read_data <= {read_data[6:0], 1'b0};
                end
            end else if (bit_count >= 8 && spi_cmd == 8'h05) begin // Read status register
                read_data <= {7'b0, wip_flag};
            end
        end
    end
    
    // Simulate EEPROM write enable and status
    always @(posedge eeprom_s_n) begin
        if (spi_cmd == 8'h06) begin // Write enable
            // Write enable set
        end else if (spi_cmd == 8'h02) begin // Write command
            wip_flag <= 1; // Set write in progress flag
            // Simulate write delay
            #500 wip_flag <= 0; // Complete write after 500ns
        end
    end
    
    // Test procedure
    initial begin
        // Initialize
        reset = 1;
        cmd_write = 0;
        cmd_read = 0;
        addr = 0;
        length = 0;
        din = 0;
        wip_flag = 0;
        
        last_written_data[0] = 8'h00;
        last_written_data[1] = 8'h00;
        last_written_data[2] = 8'h00;
        last_written_data[3] = 8'h00;
        
        // Release reset
        #500;
        reset = 0;
        #500;
        
        // Test 1: Write data
        $display("Starting write test");
        addr = 16'h0020; // Start address
        length = 16'h0001; // Write 4 bytes
        
        // Write data sequence
        #100;
        cmd_write = 1;
        din = 8'hA1;
        #50;
        cmd_write = 0;
        
        // Wait for write completion
        #10000;
        
        // Test 2: Read data
        $display("Starting read test");
        addr = 16'h0020; // Start address
        length = 16'h0001; // Read 4 bytes
        
        #100;
        cmd_read = 1;
        #50;
        cmd_read = 0;
        
        // Wait for read completion
        #10000;
        
        // Verify read data
        $display("Test completed");
        
        // End simulation
        #5000;
        $finish;
    end

endmodule
