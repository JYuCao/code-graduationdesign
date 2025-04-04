
module spi_eeprom (
    input wire clk,
    input wire rst,
    input wire spi_miso,
    output wire spi_mosi,
    output wire spi_sck,
    output wire spi_cs,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    input wire [15:0] addr,
    input wire read,
    input wire write,
    output reg busy
);

    // SPI command definitions
    localparam CMD_READ  = 8'h03;
    localparam CMD_WRITE = 8'h02;
    localparam CMD_WREN  = 8'h06;

    // State machine states
    localparam IDLE  = 0;
    localparam SEND_CMD  = 1;
    localparam SEND_ADDR  = 2;
    localparam TRANSFER_DATA  = 3;
    localparam WAIT  = 4;

    reg [3:0] state, next_state;

    reg [7:0] shift_reg;
    reg [3:0] bit_cnt;
    reg [15:0] addr_reg;
    reg [7:0] data_reg;

    // SPI signals
    assign spi_sck = clk;
    assign spi_cs = (state == IDLE);
    assign spi_mosi = shift_reg[7];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            busy <= 0;
            data_out <= 8'b0;
        end else begin
            state <= next_state;
            if (state == IDLE) begin
                busy <= 0;
            end else begin
                busy <= 1;
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (read || write) begin
                    next_state = SEND_CMD;
                end
            end
            SEND_CMD: begin
                if (bit_cnt == 4'd7) begin
                    next_state = SEND_ADDR;
                end
            end
            SEND_ADDR: begin
                if (bit_cnt == 4'd15) begin
                    next_state = TRANSFER_DATA;
                end
            end
            TRANSFER_DATA: begin
                if (bit_cnt == 4'd7) begin
                    next_state = WAIT;
                end
            end
            WAIT: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            shift_reg <= 8'b0;
            bit_cnt <= 4'b0;
            addr_reg <= 16'b0;
            data_reg <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (read) begin
                        shift_reg <= CMD_READ;
                    end else if (write) begin
                        shift_reg <= CMD_WRITE;
                    end
                    addr_reg <= addr;
                    data_reg <= data_in;
                    bit_cnt <= 4'b0;
                end
                SEND_CMD: begin
                    shift_reg <= {shift_reg[6:0], 1'b0};
                    bit_cnt <= bit_cnt + 1;
                end
                SEND_ADDR: begin
                    if (bit_cnt < 8) begin
                        shift_reg <= addr_reg[15:8];
                    end else begin
                        shift_reg <= addr_reg[7:0];
                    end
                    shift_reg <= {shift_reg[6:0], 1'b0};
                    bit_cnt <= bit_cnt + 1;
                end
                TRANSFER_DATA: begin
                    if (read) begin
                        data_out <= {data_out[6:0], spi_miso};
                    end else if (write) begin
                        shift_reg <= data_reg;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end
                    bit_cnt <= bit_cnt + 1;
                end
                WAIT: begin
                    // Wait for the EEPROM to complete the operation
                end
            endcase
        end
    end

endmodule
