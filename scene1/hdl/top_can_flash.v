//--------------------------------------------------------------------------------------------------------
// Module  : can_flash_top
// Type    : synthesizable, top module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: CAN bus data receiver and Flash storage controller
//           Receives data from CAN bus and stores it in Flash
//           Records the last written address in EEPROM
//--------------------------------------------------------------------------------------------------------

module top_can_flash #(
    // CAN parameters
    parameter [10:0] LOCAL_ID      = 11'h456,
    parameter [10:0] RX_ID_SHORT_FILTER = 11'h123,
    parameter [10:0] RX_ID_SHORT_MASK   = 11'h7ff,
    parameter [28:0] RX_ID_LONG_FILTER  = 29'h12345678,
    parameter [28:0] RX_ID_LONG_MASK    = 29'h1fffffff,
    parameter [15:0] default_c_PTS  = 16'd34,
    parameter [15:0] default_c_PBS1 = 16'd5,
    parameter [15:0] default_c_PBS2 = 16'd10,
    
    // Storage parameters
    parameter [10:0] L = 11'd1024,  // Number of address records in EEPROM
    parameter [31:0] M = 32'd28   // Default frame size in bytes
) (
    input  wire        clk,        // System clock
    input  wire        rstn,       // Active low reset
    
    // CAN interface
    input  wire        can_rx,     // CAN RX
    output wire        can_tx,     // CAN TX
    
    // Flash interface
    input  wire        flash_q,    // Flash data input
    output wire [15:0] flash_c,    // Flash clock
    output wire        flash_d,    // Flash data output
    output wire [15:0] flash_reset_n, // Flash reset
    output wire [15:0] flash_s_n,
    
    // EEPROM interface
    input  wire        spi_miso,   // EEPROM data input
    output wire        spi_mosi,   // EEPROM data output
    output wire        spi_sck,    // EEPROM clock
    output wire        spi_cs,     // EEPROM chip select
    
    // Status outputs
    output reg  [31:0] status_a,   // Status register A
    output reg  [31:0] status_b    // Status register B
);

// Constants
localparam [31:0] FRAME_HEADER = 32'h0F0F0F0F;
localparam [31:0] FRAME_FOOTER = 32'hF0F0F0F0;

// State machine states
localparam [4:0] INIT_STATE         = 5'd0;
localparam [4:0] WAIT_CAN_STATE     = 5'd3;
localparam [4:0] RECEIVE_HEADER     = 5'd4;

localparam [4:0] RECEIVE_FOOTER     = 5'd8;
localparam [4:0] WRITE_EEPROM       = 5'd9;
localparam [4:0] UPDATE_ADDR        = 5'd11;
localparam [4:0] READ_EEPROM_STATE1 = 5'd12;
localparam [4:0] READ_EEPROM_STATE2 = 5'd13;
localparam [4:0] READ_EEPROM_STATE3 = 5'd14;
localparam [4:0] RECEIVE_FRAME_INFO1 = 5'd5;
localparam [4:0] RECEIVE_FRAME_INFO2 = 5'd15;
localparam [4:0] RECEIVE_FRAME_INFO3 = 5'd16;
localparam [4:0] RECEIVE_FRAME_INFO4 = 5'd17;
localparam [4:0] RECEIVE_FRAME_INFO5 = 5'd18;
localparam [4:0] RECEIVE_TIME1 = 5'd6;
localparam [4:0] RECEIVE_TIME2 = 5'd19;
localparam [4:0] RECEIVE_TIME3 = 5'd20;
localparam [4:0] RECEIVE_DATA1 = 5'd7;
localparam [4:0] RECEIVE_DATA2 = 5'd21;
localparam [4:0] WRITE_EEPROM1 = 5'd22;
localparam [4:0] WRITE_EEPROM2 = 5'd23;
localparam [4:0] WRITE_EEPROM3 = 5'd24;
localparam [4:0] WRITE_EEPROM4 = 5'd25;
localparam [4:0] WRITE_FLASH1  = 5'd10;
localparam [4:0] WRITE_FLASH2  = 5'd26;

// Registers
reg [4:0]  state;
reg [3:0]  next_state;
reg [31:0] frame_size;         // Size of each frame in bytes
reg [31:0] write_address;      // Current flash write address

// Ping-pong buffer control
reg        buffer_select;      // 0 = buffer A, 1 = buffer B
reg [31:0] buffer_a_size;      // Size of data in buffer A
reg [31:0] buffer_b_size;      // Size of data in buffer B
reg        buffer_a_ready;     // Buffer A ready to be written to flash
reg        buffer_b_ready;     // Buffer B ready to be written to flash
reg [31:0] expected_data_size; // Expected data size from frame info
reg [31:0] received_data_size; // Actual received data size

// Frame validation
reg        valid_frame;        // Flag for valid frame
reg [31:0] header_buffer;      // Buffer for frame header detection
reg [31:0] footer_buffer;      // Buffer for frame footer detection
reg [31:0] frame_info;         // Frame information

// Memory for ping-pong buffers (simplified for simulation)
reg [7:0]  buffer_a [0:31];  // Buffer A - 32B
reg [7:0]  buffer_b [0:31];  // Buffer B - 32B

// EEPROM control signals
reg        eeprom_read;
reg        eeprom_write;
reg [15:0] eeprom_addr;
reg [7:0]  eeprom_data_in;
wire [7:0] eeprom_data_out;
wire       eeprom_busy;

// Flash control signals
reg        flash_cmd_write;
reg        flash_cmd_read;
reg        flash_cmd_erasedies;
reg [31:0] flash_addr;
reg [15:0] flash_length;
reg [7:0]  flash_din;
wire [7:0] flash_dout;
wire       flash_read;
wire       flash_write;
wire       flash_done;
wire       flash_error;
wire       flash_busy;

// CAN interface signals
wire       can_rx_valid;
wire       can_rx_last;
wire [7:0] can_rx_data;
wire [28:0] can_rx_id;
wire       can_rx_ide;

// Counters
reg [31:0] byte_counter;       // Counter for bytes in current frame
reg [31:0] eeprom_read_counter; // Counter for EEPROM read operations
reg [31:0] flash_write_counter; // Counter for Flash write operations
reg [1:0]  header_state;       // State for header detection
reg [1:0]  footer_state;       // State for footer detection
reg [31:0] buffer_write_index; // Current write index in buffer


reg [31:0] last_addr;       // last address be read
reg [1:0]  eeprom_byte_counter;    // Byte counter for reading address bytes
reg [31:0] eeprom_addr_bytes;  // Temporary storage for address bytes
reg [10:0] eeprom_index;

// Instantiate EEPROM controller
eeprom_b eeprom_ctrl (
    .clk(clk),
    .reset(~rstn),
    .eeprom_q(spi_miso),
    .eeprom_d(spi_mosi),
    .eeprom_c(spi_sck),
    .eeprom_s_n(spi_cs),
    .din(eeprom_data_in),
    .dout(eeprom_data_out),
    .addr(eeprom_addr),
    .cmd_read(eeprom_read),
    .cmd_write(eeprom_write),
    .busy(eeprom_busy)
);

// Instantiate Flash controller
flash_c flash_ctrl (
    .clk(clk),
    .reset(~rstn),
    .cmd_erasedies(flash_cmd_erasedies),
    .cmd_write(flash_cmd_write),
    .cmd_read(flash_cmd_read),
    .addr(flash_addr),
    .length(flash_length),
    .din(flash_din),
    .dout(flash_dout),
    .read(flash_read),
    .write(flash_write),
    .done(flash_done),
    .error(flash_error),
    .flash_q(flash_q),
    .flash_c(flash_c),
    .flash_d(flash_d),
    .flash_reset_n(flash_reset_n),
    .busy(flash_busy),
    .flash_s_n(flash_s_n)
);

// Instantiate CAN controller
can_top #(
    .LOCAL_ID(LOCAL_ID),
    .RX_ID_SHORT_FILTER(RX_ID_SHORT_FILTER),
    .RX_ID_SHORT_MASK(RX_ID_SHORT_MASK),
    .RX_ID_LONG_FILTER(RX_ID_LONG_FILTER),
    .RX_ID_LONG_MASK(RX_ID_LONG_MASK),
    .default_c_PTS(default_c_PTS),
    .default_c_PBS1(default_c_PBS1),
    .default_c_PBS2(default_c_PBS2)
) can_ctrl (
    .rstn(rstn),
    .clk(clk),
    .can_rx(can_rx),
    .can_tx(can_tx),
    .tx_valid(1'b0),           // We're only receiving, not transmitting
    .tx_ready(),
    .tx_data(32'h0),
    .rx_valid(can_rx_valid),
    .rx_last(can_rx_last),
    .rx_data(can_rx_data),
    .rx_id(can_rx_id),
    .rx_ide(can_rx_ide)
);

// Initialize status registers
initial begin
    status_a = 32'h0;
    status_b = 32'h0;
    state = INIT_STATE;
    buffer_select = 1'b0;
    buffer_a_ready = 1'b0;
    buffer_b_ready = 1'b0;
    buffer_a_size = 32'h0;
    buffer_b_size = 32'h0;
    valid_frame = 1'b0;
    frame_size = M;  // Default frame size
    write_address = 32'h0;
    eeprom_index = 11'd0;
end

// Main state machine
always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        state <= INIT_STATE;
        buffer_select <= 1'b0;
        buffer_a_ready <= 1'b0;
        buffer_b_ready <= 1'b0;
        buffer_a_size <= 32'h0;
        buffer_b_size <= 32'h0;
        valid_frame <= 1'b0;
        frame_size <= M;
        write_address <= 32'h0;
        status_a <= 32'h0;
        status_b <= 32'h0;
        byte_counter <= 32'h0;
        eeprom_read_counter <= 32'h0;
        flash_write_counter <= 32'h0;
        header_state <= 2'h0;
        footer_state <= 2'h0;
        buffer_write_index <= 32'h0;
        header_buffer <= 32'h0;
        footer_buffer <= 32'h0;
        frame_info <= 32'h0;
        expected_data_size <= 32'h0;
        received_data_size <= 32'h0;
        
        // Reset EEPROM control signals
        eeprom_read <= 1'b0;
        eeprom_write <= 1'b0;
        eeprom_addr <= 16'h0;
        eeprom_data_in <= 8'h0;
        
        // Reset Flash control signals
        flash_cmd_write <= 1'b0;
        flash_cmd_read <= 1'b0;
        flash_cmd_erasedies <= 1'b0;
        flash_addr <= 32'h0;
        flash_length <= 16'h0;
        flash_din <= 8'h0;

        eeprom_byte_counter <= 2'h0;
        eeprom_addr_bytes <= 32'h0;
        eeprom_index <= 11'd0;
    end else begin
        // Default signal values
        eeprom_read <= 1'b0;
        eeprom_write <= 1'b0;
        flash_cmd_write <= 1'b0;
        flash_cmd_read <= 1'b0;
        flash_cmd_erasedies <= 1'b0;
        
        case (state)
            INIT_STATE: begin
                eeprom_read_counter <= 32'h0;
                eeprom_byte_counter <= 2'h0;
                state <= READ_EEPROM_STATE1;
            end

            READ_EEPROM_STATE1: begin
                if (~eeprom_busy) begin
                    if (eeprom_read_counter < L) begin
                        eeprom_addr <= (eeprom_read_counter << 2) + {14'h0, eeprom_byte_counter};
                        eeprom_read <= 1'b1;
                        state <= READ_EEPROM_STATE2;
                    end else begin
                        write_address <= last_addr + frame_size;
                        state <= WAIT_CAN_STATE;
                    end
                end
            end
            READ_EEPROM_STATE2: begin
                eeprom_read <= 1'b0;
                if (~eeprom_busy) begin
                    case (eeprom_byte_counter)
                        2'h3: eeprom_addr_bytes[7:0] <= eeprom_data_out;
                        2'h2: eeprom_addr_bytes[15:8] <= eeprom_data_out;
                        2'h1: eeprom_addr_bytes[23:16] <= eeprom_data_out;
                        2'h0: eeprom_addr_bytes[31:24] <= eeprom_data_out;
                    endcase
                    eeprom_byte_counter <= eeprom_byte_counter + 1;
                    state <= READ_EEPROM_STATE3;
                end
            end
            READ_EEPROM_STATE3: begin
                if (eeprom_byte_counter == 2'h4) begin
                    if (eeprom_read_counter == 0) begin
                        last_addr <= eeprom_addr_bytes;
                        eeprom_byte_counter <= 2'h0;
                        eeprom_read_counter <= eeprom_read_counter + 1;
                        state <= READ_EEPROM_STATE1;
                    end else begin
                        if (last_addr > eeprom_addr_bytes) begin
                            write_address <= last_addr + frame_size;
                            state <= WAIT_CAN_STATE;
                        end else begin
                            last_addr <= eeprom_addr_bytes;
                            eeprom_byte_counter <= 2'h0;
                            eeprom_read_counter <= eeprom_read_counter + 1;
                            state <= READ_EEPROM_STATE1;
                        end
                    end
                end else begin
                    state <= READ_EEPROM_STATE1;
                end
            end
            
            WAIT_CAN_STATE: begin
                // Wait for CAN data
                header_state <= 2'h0;
                footer_state <= 2'h0;
                byte_counter <= 32'h0;
                buffer_write_index <= 32'h0;
                
                if (can_rx_valid) begin
                    // Start receiving new frame
                    header_buffer <= {header_buffer[23:0], can_rx_data};
                    
                    // Check if we have frame header
                    if ({header_buffer[23:0], can_rx_data} == FRAME_HEADER) begin
                        // Header detected, start new frame
                        buffer_select <= ~buffer_a_ready & ~buffer_b_ready ? 1'b0 : 
                                         ~buffer_a_ready ? 1'b0 : 1'b1;
                        
                        // Store header in buffer
                        if (~buffer_a_ready & ~buffer_b_ready) begin
                            buffer_a[0] <= FRAME_HEADER[31:24];
                            buffer_a[1] <= FRAME_HEADER[23:16];
                            buffer_a[2] <= FRAME_HEADER[15:8];
                            buffer_a[3] <= FRAME_HEADER[7:0];
                        end else if (~buffer_a_ready) begin
                            buffer_a[0] <= FRAME_HEADER[31:24];
                            buffer_a[1] <= FRAME_HEADER[23:16];
                            buffer_a[2] <= FRAME_HEADER[15:8];
                            buffer_a[3] <= FRAME_HEADER[7:0];
                        end else begin
                            buffer_b[0] <= FRAME_HEADER[31:24];
                            buffer_b[1] <= FRAME_HEADER[23:16];
                            buffer_b[2] <= FRAME_HEADER[15:8];
                            buffer_b[3] <= FRAME_HEADER[7:0];
                        end
                        
                        buffer_write_index <= 4; // Next position after header
                        state <= RECEIVE_FRAME_INFO1;
                    end
                end
            end
            
            RECEIVE_FRAME_INFO1: begin
                if (can_rx_valid) begin
                    frame_info <= {frame_info[23:0], can_rx_data};
                    state <= RECEIVE_FRAME_INFO2;
                end
            end
            RECEIVE_FRAME_INFO2: begin
                if (buffer_select == 1'b0) begin
                    buffer_a[buffer_write_index] <= can_rx_data;
                end else begin
                    buffer_b[buffer_write_index] <= can_rx_data;
                end
                state <= RECEIVE_FRAME_INFO3;
            end
            RECEIVE_FRAME_INFO3: begin
                buffer_write_index <= buffer_write_index + 1;
                if (can_rx_valid) begin
                    frame_info <= {frame_info[23:0], can_rx_data};
                    state <= RECEIVE_FRAME_INFO4;
                end
            end
            RECEIVE_FRAME_INFO4: begin
                if (buffer_select == 1'b0) begin
                    buffer_a[buffer_write_index] <= can_rx_data;
                end else begin
                    buffer_b[buffer_write_index] <= can_rx_data;
                end
                byte_counter <= byte_counter + 1;
                state <= RECEIVE_FRAME_INFO5;
            end
            RECEIVE_FRAME_INFO5: begin
                buffer_write_index <= buffer_write_index + 1;
                if (byte_counter == 2) begin
                    expected_data_size <= {frame_info[23:0], can_rx_data};
                    byte_counter <= 0;
                    state <= RECEIVE_TIME1;
                end else begin
                    state <= RECEIVE_FRAME_INFO3;
                end
            end
            
            RECEIVE_TIME1: begin
                // Receive timestamp byte 1
                if (can_rx_valid) begin
                    if (buffer_select == 1'b0) begin
                        buffer_a[buffer_write_index] <= can_rx_data;
                    end else begin
                        buffer_b[buffer_write_index] <= can_rx_data;
                    end
                    state <= RECEIVE_TIME2;
                end
            end
            RECEIVE_TIME2: begin
                // Receive timestamp byte 2
                byte_counter <= byte_counter + 1;
                buffer_write_index <= buffer_write_index + 1;
                state <= RECEIVE_TIME3;
            end
            RECEIVE_TIME3: begin
                // Receive timestamp byte 3
                if (byte_counter == 7) begin 
                    byte_counter <= 0;
                    received_data_size <= 0;
                    state <= RECEIVE_DATA1;
                end else begin
                    state <= RECEIVE_TIME1;
                end
            end
            
            RECEIVE_DATA1: begin
                // Receive N data bytes
                if (can_rx_valid) begin
                    // Store data in buffer
                    if (buffer_select == 1'b0) begin
                        buffer_a[buffer_write_index] <= can_rx_data;
                    end else begin
                        buffer_b[buffer_write_index] <= can_rx_data;
                    end
                    received_data_size <= received_data_size + 1;
                end
            end
            RECEIVE_DATA2: begin
                buffer_write_index <= buffer_write_index + 1;
                
                // Update footer detection buffer
                footer_buffer <= {footer_buffer[23:0], can_rx_data};
                
                // Check if we have frame footer
                if ({footer_buffer[23:0], can_rx_data} == FRAME_FOOTER && 
                    received_data_size >= expected_data_size) begin
                    // Footer detected, frame complete
                    state <= RECEIVE_FOOTER;
                end
            end
            
            RECEIVE_FOOTER: begin
                // Validate frame and prepare for storage
                valid_frame <= (received_data_size == expected_data_size);
                
                // Update buffer status
                if (buffer_select == 1'b0) begin
                    buffer_a_size <= buffer_write_index;
                    buffer_a_ready <= 1'b1;
                end else begin
                    buffer_b_size <= buffer_write_index;
                    buffer_b_ready <= 1'b1;
                end
                
                // Check if frame is valid
                if (received_data_size == expected_data_size) begin
                    // Valid frame, write address to EEPROM
                    state <= WRITE_EEPROM;
                    
                    // Check if frame size changed
                    if (frame_size != expected_data_size + 16) begin // 16 = header(4) + info(4) + time(8)
                        // Frame size changed, set error flag
                        status_a[16] <= 1'b1;
                        frame_size <= expected_data_size + 16;
                    end
                end else begin
                    // Invalid frame, update status and wait for next frame
                    status_b[19:0] <= status_b[19:0] + 1;
                    state <= WAIT_CAN_STATE;
                end
            end
            
            WRITE_EEPROM: begin
                // Write current flash address to EEPROM (MSB first)
                if (~eeprom_busy) begin
                    eeprom_addr <= eeprom_index << 2;  // Base address
                    eeprom_data_in <= write_address[31:24];  // MSB
                    eeprom_write <= 1'b1;
                    eeprom_byte_counter <= 2'h0;
                    state <= WRITE_EEPROM1;
                end
            end
            WRITE_EEPROM1: begin
                if (~eeprom_busy) begin
                    eeprom_addr <= (eeprom_index << 2) + 1;
                    eeprom_data_in <= write_address[23:16];
                    eeprom_write <= 1'b1;
                    state <= WRITE_EEPROM2;
                end
            end
            WRITE_EEPROM2: begin
                if (~eeprom_busy) begin
                    eeprom_addr <= (eeprom_index << 2) + 2;
                    eeprom_data_in <= write_address[15:8];
                    eeprom_write <= 1'b1;
                    state <= WRITE_EEPROM3;
                end
            end
            WRITE_EEPROM3: begin
                if (~eeprom_busy) begin
                    eeprom_addr <= (eeprom_index << 2) + 3;
                    eeprom_data_in <= write_address[7:0];  // LSB
                    eeprom_write <= 1'b1;
                    state <= WRITE_EEPROM4;
                end
            end
            WRITE_EEPROM4: begin
                if (~eeprom_busy) begin
                    if (eeprom_index < L-1)
                        eeprom_index <= eeprom_index + 11'd1;
                    else
                        eeprom_index <= 11'd0;
                    state <= WRITE_FLASH1;
                end
            end
            
            WRITE_FLASH1: begin
                // Write buffer data to flash
                if (~flash_busy) begin
                    // Start flash write
                    flash_cmd_write <= 1'b1;
                    flash_addr <= write_address;
                    
                    // Determine which buffer to write
                    if (buffer_a_ready) begin
                        flash_length <= buffer_a_size;
                        flash_din <= buffer_a[flash_write_counter];
                    end else if (buffer_b_ready) begin
                        flash_length <= buffer_b_size;
                        flash_din <= buffer_b[flash_write_counter];
                    end
                    state <= WRITE_FLASH2;
                end
            end
            WRITE_FLASH2: begin
                flash_write_counter <= flash_write_counter + 1;
                    
                // Check if write is complete
                if (flash_write_counter >= (buffer_a_ready ? buffer_a_size : buffer_b_size)) begin
                    // Write complete, update address
                    state <= UPDATE_ADDR;
                end
            end
            
            UPDATE_ADDR: begin
                // Update write address and buffer status
                write_address <= write_address + frame_size;
                
                // Clear buffer ready flag
                if (buffer_a_ready) begin
                    buffer_a_ready <= 1'b0;
                end else if (buffer_b_ready) begin
                    buffer_b_ready <= 1'b0;
                end
                
                // Return to wait state
                state <= WAIT_CAN_STATE;
            end
            
            default: begin
                state <= INIT_STATE;
            end
        endcase
    end
end

endmodule
