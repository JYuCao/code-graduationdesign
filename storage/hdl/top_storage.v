module top_storage (
    input  wire        clk,
    input  wire        rstn,
    
    // CAN interface
    input  wire        can_rx,
    output wire        can_tx,
    
    // UART interface
    input  wire        rx,
    output wire        tx,
    
    // Flash interface
    input  wire        flash_q,
    output wire [15:0] flash_c,
    output wire        flash_d,
    output wire [15:0] flash_reset_n,
    output wire [15:0] flash_s_n,
    
    // EEPROM interface
    input  wire        spi_miso,
    output wire        spi_mosi,
    output wire        spi_sck,
    output wire        spi_cs
);

    // CAN receive detection
    reg [2:0] can_rx_buf;
    reg [19:0] can_idle_cnt;  // Counter for detecting CAN bus idle time
    reg work_mode;            // 1: CAN acquisition mode, 0: UART read mode
    
    // Flash control signals
    wire [15:0] flash_c_can, flash_c_cmd;
    wire flash_d_can, flash_d_cmd;
    wire [15:0] flash_s_n_can, flash_s_n_cmd;
    wire [15:0] flash_reset_n_can, flash_reset_n_cmd;
    wire [3:0] flash_cs_cmd;
    
    // Monitor CAN bus status
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            can_rx_buf <= 3'b111;
            can_idle_cnt <= 20'd0;
            work_mode <= 1'b1;  // Default to CAN acquisition mode
        end else begin
            can_rx_buf <= {can_rx_buf[1:0], can_rx};
            
            // Detect CAN bus activity
            if (can_rx_buf[2] != can_rx_buf[1]) begin
                can_idle_cnt <= 20'd0;  // Reset idle counter when activity detected
                work_mode <= 1'b1;      // Switch to CAN acquisition mode
            end else begin
                if (can_idle_cnt < 20'hFFFFF)  // About 1ms@50MHz
                    can_idle_cnt <= can_idle_cnt + 1'b1;
                else
                    work_mode <= 1'b0;  // Switch to read mode after 1ms of inactivity
            end
        end
    end

    // Instantiate CAN acquisition module
    top_can_flash u_can_flash (
        .clk            (clk),
        .rstn           (rstn & work_mode),
        .can_rx         (can_rx),
        .can_tx         (can_tx),
        .flash_q        (flash_q),
        .flash_c        (flash_c_can),
        .flash_d        (flash_d_can),
        .flash_reset_n  (flash_reset_n_can),
        .spi_miso       (spi_miso),
        .spi_mosi       (spi_mosi),
        .spi_sck        (spi_sck),
        .spi_cs         (spi_cs),
        .flash_s_n(flash_s_n_can)
    );

    // Instantiate command processing module
    top_cmd_process u_cmd_process (
        .sys_clk        (clk),
        .sys_rst_n      (rstn & ~work_mode),
        .rx             (rx),
        .tx             (tx),
        .flash_q        (flash_q),
        .flash_c        (flash_c_cmd[3:0]),
        .flash_d        (flash_d_cmd),
        .flash_s_n      (flash_s_n_cmd),
        .flash_reset_n  (flash_reset_n_cmd)
    );

    // Flash interface multiplexing
    assign flash_c = work_mode ? flash_c_can : {12'b0, flash_c_cmd[3:0]};
    assign flash_d = work_mode ? flash_d_can : flash_d_cmd;
    assign flash_reset_n = work_mode ? flash_reset_n_can : flash_reset_n_cmd;
    assign flash_s_n = work_mode ? flash_s_n_can : flash_s_n_cmd;

endmodule
