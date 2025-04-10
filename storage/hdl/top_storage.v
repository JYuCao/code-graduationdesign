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

    // Internal signals for CAN module
    reg         can_tx_valid;
    wire        can_tx_ready;
    reg  [31:0] can_tx_data;
    wire        can_rx_valid;
    wire        can_rx_last;
    wire [7:0]  can_rx_data;
    wire [28:0] can_rx_id;
    wire        can_rx_ide;
    wire [31:0] status_a;
    wire [31:0] status_b;

    // Internal signals for UART modules
    wire [7:0]  uart_rx_data;
    wire        uart_rx_done;
    wire        uart_tx_done;
    wire        uart_tx_busy;
    wire [2:0]  baud_set;
    wire        tx_start;
    wire [7:0]  tx_data;
    wire        uart_re;

    // Internal signals for Flash module
    wire        flash_cmd_erasedies_uart, flash_cmd_erasedies_can;
    wire        flash_cmd_write_uart, flash_cmd_write_can;
    wire        flash_cmd_read_uart, flash_cmd_read_can;
    wire [31:0] flash_addr_uart, flash_addr_can;
    wire [15:0] flash_length_uart, flash_length_can;
    wire [7:0]  flash_din_uart, flash_din_can;
    wire [7:0]  flash_dout;
    wire        flash_read;
    wire        flash_write;
    wire        flash_done;
    wire        flash_error;
    wire        flash_busy;

    // Internal signals for EEPROM module
    wire [7:0]  eeprom_data_in;
    wire [15:0] eeprom_addr;
    wire [7:0]  eeprom_data_out;
    wire        eeprom_read;
    wire        eeprom_write;
    wire        eeprom_busy;

    // CAN receive detection
    reg [2:0] can_rx_buf;
    reg [19:0] can_idle_cnt;  // Counter for detecting CAN bus idle time
    reg work_mode;            // 1: CAN acquisition mode, 0: UART read mode

    // Multiplexer for Flash control signals based on work_mode
    assign flash_cmd_erasedies = work_mode ? flash_cmd_erasedies_can : flash_cmd_erasedies_uart;
    assign flash_cmd_write = work_mode ? flash_cmd_write_can : flash_cmd_write_uart;
    assign flash_cmd_read = work_mode ? flash_cmd_read_can : flash_cmd_read_uart;
    assign flash_addr = work_mode ? flash_addr_can : flash_addr_uart;
    assign flash_length = work_mode ? flash_length_can : flash_length_uart;
    assign flash_din = work_mode ? flash_din_can : flash_din_uart;

    // CAN module instantiation
    can_top #(
        .LOCAL_ID(11'h456),
        .RX_ID_SHORT_FILTER(11'h123),
        .RX_ID_SHORT_MASK(11'h7ff),
        .RX_ID_LONG_FILTER(29'h12345678),
        .RX_ID_LONG_MASK(29'h1fffffff),
        .default_c_PTS(16'd12),
        .default_c_PBS1(16'd2),
        .default_c_PBS2(16'd5)
    ) u_can_top (
        .clk(clk),
        .rstn(rstn),
        .can_rx(can_rx),
        .can_tx(can_tx),
        .tx_valid(can_tx_valid),
        .tx_ready(can_tx_ready),
        .tx_data(can_tx_data),
        .rx_valid(can_rx_valid),
        .rx_last(can_rx_last),
        .rx_data(can_rx_data),
        .rx_id(can_rx_id),
        .rx_ide(can_rx_ide)
    );

    // UART RX module instantiation
    uart_rx u_uart_rx (
        .sys_clk(clk),
        .sys_rst_n(rstn),
        .baud_set(baud_set),
        .rx(rx),
        .data(uart_rx_data),
        .Rx_Done(uart_rx_done)
    );

    // UART TX module instantiation
    uart_tx u_uart_tx (
        .sys_clk(clk),
        .sys_rst_n(rstn),
        .data(tx_data),
        .send_en(tx_start),
        .baud_set(baud_set),
        .tx(tx),
        .Tx_Done(uart_tx_done),
        .uart_state(uart_tx_busy)
    );

    // Flash controller module instantiation
    flash_c u_flash_c (
        .clk(clk),
        .reset(rstn),
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
        .busy(flash_busy),
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_d(flash_d),
        .flash_reset_n(flash_reset_n),
        .flash_s_n(flash_s_n)
    );

    // EEPROM controller module instantiation
    eeprom_b u_eeprom_b (
        .clk(clk),
        .reset(rstn),
        .cmd_write(eeprom_write),
        .cmd_read(eeprom_read),
        .din(eeprom_data_in),
        .dout(eeprom_data_out),
        .addr(eeprom_addr),
        .busy(eeprom_busy),
        .eeprom_q(spi_miso),
        .eeprom_c(spi_sck),
        .eeprom_s_n(spi_cs),
        .eeprom_d(spi_mosi)
    );

    // Command processing module instantiation
    top_cmd_process u_cmd_process (
        .sys_clk(clk),
        .sys_rst_n(rstn & ~work_mode),  // reset when work_mode=1
        .rx(rx),
        .tx(tx),
        .re(uart_re),
        .baud_set(baud_set),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done),
        .tx_done(uart_tx_done),
        .tx_busy(uart_tx_busy),
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_d(flash_d),
        .flash_s_n(flash_s_n),
        .flash_reset_n(flash_reset_n),
        .flash_cmd_erasedies(flash_cmd_erasedies_uart),
        .flash_cmd_write(flash_cmd_write_uart),
        .flash_cmd_read(flash_cmd_read_uart),
        .flash_addr(flash_addr_uart),
        .flash_length(flash_length_uart),
        .flash_din(flash_din_uart),
        .flash_dout(flash_dout),
        .flash_read(flash_read),
        .flash_write(flash_write),
        .flash_done(flash_done),
        .flash_error(flash_error),
        .flash_busy(flash_busy)
    );

    top_can_flash #(
        .LOCAL_ID(11'h456),
        .RX_ID_SHORT_FILTER(11'h123),
        .RX_ID_SHORT_MASK(11'h7ff),
        .RX_ID_LONG_FILTER(29'h12345678),
        .RX_ID_LONG_MASK(29'h1fffffff),
        .default_c_PTS(16'd12),
        .default_c_PBS1(16'd2),
        .default_c_PBS2(16'd5),
        .L(11'd1024),
        .M(32'd28)
    ) u_can_flash (
        .clk(clk),
        .rstn(rstn & ~work_mode),  // reset when work_mode=0
        .can_rx(can_rx),
        .can_tx(can_tx),
        .can_tx_valid(can_tx_valid),
        .can_tx_ready(can_tx_ready),
        .can_tx_data(can_tx_data),
        .can_rx_valid(can_rx_valid),
        .can_rx_last(can_rx_last),
        .can_rx_data(can_rx_data),
        .can_rx_id(can_rx_id),
        .can_rx_ide(can_rx_ide),
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_d(flash_d),
        .flash_reset_n(flash_reset_n),
        .flash_s_n(flash_s_n),
        .flash_cmd_erasedies(flash_cmd_erasedies_can),
        .flash_cmd_write(flash_cmd_write_can),
        .flash_cmd_read(flash_cmd_read_can),
        .flash_addr(flash_addr_can),
        .flash_length(flash_length_can),
        .flash_din(flash_din_can),
        .flash_dout(flash_dout),
        .flash_read(flash_read),
        .flash_write(flash_write),
        .flash_done(flash_done),
        .flash_error(flash_error),
        .flash_busy(flash_busy),
        .spi_miso(spi_miso),
        .spi_mosi(spi_mosi),
        .spi_sck(spi_sck),
        .spi_cs(spi_cs),
        .eeprom_data_in(eeprom_data_in),
        .eeprom_addr(eeprom_addr),
        .eeprom_data_out(eeprom_data_out),
        .eeprom_read(eeprom_read),
        .eeprom_write(eeprom_write),
        .eeprom_busy(eeprom_busy),
        .status_a(status_a),
        .status_b(status_b)
    );

    // Initial block for signal initialization
    initial begin
        can_tx_valid = 1'b0;
        can_tx_data = 32'h0;
        can_rx_buf = 3'b111;
        can_idle_cnt = 20'd0;
        work_mode = 1'b0;
    end
    
    // Monitor CAN bus status
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            can_rx_buf <= 3'b111;
            can_idle_cnt <= 20'd0;
            work_mode <= 1'b0;  // Default to UART mode
        end else begin
            can_rx_buf <= {can_rx_buf[1:0], can_rx};
            
            // Detect CAN bus activity
            if (can_rx_buf[2] != can_rx_buf[1]) begin
                can_idle_cnt <= 20'd0;  // Reset idle counter when activity detected
                work_mode <= 1'b1;      // Switch to CAN acquisition mode
            end else begin
                if (can_idle_cnt < 20'h4E20)  // About 1ms@20MHz
                    can_idle_cnt <= can_idle_cnt + 1'b1;
                else
                    work_mode <= 1'b0;  // Switch to UART mode after 1ms of inactivity
            end
        end
    end

endmodule
