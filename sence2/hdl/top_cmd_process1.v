module top_cmd_process(
    input wire sys_clk,
    input wire sys_rst_n,
    input wire rx,
    output wire tx,
    output reg re,
    output reg done,
    output reg error,
    
    // Flash interface
    input wire flash_q,
    output wire flash_c,
    output wire flash_d,
    output wire [3:0] flash_cs
);

    wire [2:0] baud_set;
    assign baud_set = 3'd0;  // 9600 baud rate

    wire [7:0] rx_data;
    wire rx_done;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_done;
    wire tx_busy;
    
    // Flash control signals
    reg cmd_erasedies;
    reg cmd_write;
    reg cmd_read;
    reg [31:0] flash_addr;
    reg [15:0] flash_length;
    reg [7:0] flash_din;
    wire [7:0] flash_dout;
    wire flash_read;
    wire flash_write;
    wire flash_done;
    wire flash_error;

    // Command list
    localparam CMD_READ = 8'h01;
    localparam CMD_WRITE = 8'h02;
    localparam CMD_ERASE = 8'h03;
    localparam CMD_ECHO = 8'hFF;

    // Protocol definition
    localparam CMD_HEAD = 8'hAA;
    localparam CMD_TAIL = 8'h55;

    // Main state machine
    localparam STAT_IDLE = 6'd0;
    localparam STAT_GET_LEN = 6'd1;
    localparam STAT_GET_CMD = 6'd2;
    localparam STAT_GET_DATA = 6'd3;
    localparam STAT_EXEC_CMD = 6'd4;
    localparam STAT_DONE = 6'd5;
    localparam STAT_ERROR = 6'd63;

    // Read state machine
    localparam READ_IDLE = 6'd6;
    localparam READ_ADDR = 6'd7;
    localparam READ_WAIT = 6'd8;
    localparam READ_DATA = 6'd9;
    localparam READ_SEND = 6'd10;

    // Write state machine
    localparam WRITE_IDLE = 6'd11;
    localparam WRITE_ADDR = 6'd12;
    localparam WRITE_DATA = 6'd13;
    localparam WRITE_WAIT = 6'd14;
    localparam WRITE_DONE = 6'd15;

    // Erase state machine
    localparam ERASE_IDLE = 6'd16;
    localparam ERASE_ADDR = 6'd17;
    localparam ERASE_WAIT = 6'd18;
    localparam ERASE_DONE = 6'd19;

    // ECHO state machine for test
    localparam STAT_ECHO1       = 6'd59;
    localparam STAT_ECHO2       = 6'd60;
    localparam STAT_ECHO3       = 6'd61;
    localparam STAT_ECHO4       = 6'd62;
    
    reg [5:0] state;
    reg [2:0] data_length;
    reg [7:0] cmd;
    reg [2:0] addr_cnt;
    reg [1:0] data_cnt;
    reg [1:0] send_cnt;
    reg [7:0] data_buffer [3:0];
    
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            re <= 1'b0;  
        else if(tx_start)
            re <= 1'b1; 
        else if(tx_done)
            re <= 1'b0; 
    end

    // Main state machine
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            state <= STAT_IDLE;
            cmd <= 8'd0;
            data_length <= 3'd0;
            error <= 1'b0;
            done <= 1'b0;
            data_cnt <= 2'd0;
            send_cnt <= 2'd0;
            re <= 1'b0;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
        end
        else begin
            case(state)
                STAT_IDLE: begin
                    cmd <= 8'd0;
                    data_length <= 3'd0;
                    error <= 1'b0;
                    done <= 1'b0;
                    data_cnt <= 2'd0;
                    send_cnt <= 2'd0;
                    re <= 1'b0;
                    tx_start <= 1'b0;
                    tx_data <= 8'd0;
                    if(rx_done)
                        if(rx_data == CMD_HEAD) begin
                            state <= STAT_GET_LEN;
                        end
                    else
                        state <= STAT_ERROR;
                end

                STAT_GET_LEN: begin
                    if(rx_done) begin
                        if(rx_data > 4'd3)
                            state <= STAT_ERROR;
                        else begin
                            data_length <= rx_data;
                            state <= STAT_GET_CMD;
                        end
                    end
                end
                
                STAT_GET_CMD: begin
                    if(rx_done) begin
                        cmd <= rx_data;
                        state <= STAT_GET_DATA;
                    end
                end
                
                STAT_GET_DATA: begin
                    if(rx_done) begin
                        if(rx_data == CMD_TAIL)
                            state <= STAT_EXEC_CMD;
                        else begin
                            data_buffer[data_cnt] <= rx_data;
                            if(data_cnt >= data_length - 1 || data_cnt == 2'b11)
                                state <= STAT_EXEC_CMD;
                            else
                                data_cnt <= data_cnt + 1'b1;
                        end
                    end
                end
                
                STAT_EXEC_CMD: begin
                    case(cmd)
                        CMD_READ: state <= READ_ADDR;
                        CMD_WRITE: state <= WRITE_ADDR;
                        CMD_ERASE: state <= ERASE_ADDR;
                        CMD_ECHO: state <= STAT_ECHO1;
                        default: state <= STAT_ERROR;
                    endcase
                end

                STAT_ERROR: begin
                    error <= 1'b1;
                    state <= STAT_IDLE;
                end

                STAT_DONE: begin
                    done <= 1'b1;
                    state <= STAT_IDLE;
                end

                // STATE READ
                READ_IDLE: begin
                    cmd_read <= 1'b0;
                end

                READ_ADDR: begin
                    flash_addr <= {data_buffer[3], data_buffer[2], 
                                 data_buffer[1], data_buffer[0]};
                    flash_length <= data_length;
                    cmd_read <= 1'b1;
                    state <= READ_WAIT;
                end

                READ_WAIT: begin
                    if(flash_done) begin
                        tx_data <= flash_dout;
                        tx_start <= 1'b1;
                        state <= READ_SEND;
                    end
                end

                READ_SEND: begin
                    tx_start <= 1'b0;
                    if(tx_done) begin
                        if(data_cnt < flash_length - 1) begin
                            data_cnt <= data_cnt + 1'b1;
                            state <= READ_DATA;
                        end
                        else
                            state <= STAT_DONE;
                    end
                end

                // STATE WRITE
                WRITE_IDLE: begin
                    cmd_write <= 1'b0;
                end

                WRITE_ADDR: begin
                    flash_addr <= {data_buffer[3], data_buffer[2], 
                                 data_buffer[1], data_buffer[0]};
                    state <= WRITE_DATA;
                end

                WRITE_DATA: begin
                    flash_din <= data_buffer[0];
                    cmd_write <= 1'b1;
                    state <= WRITE_WAIT;
                end

                WRITE_WAIT: begin
                    if(flash_done) begin
                        cmd_write <= 1'b0;
                        state <= STAT_DONE;
                    end
                end

                // STATE ERASE
                ERASE_IDLE: begin
                    cmd_erasedies <= 1'b0;
                end

                ERASE_ADDR: begin
                    flash_addr <= {data_buffer[3], data_buffer[2], 
                                 data_buffer[1], data_buffer[0]};
                    flash_length <= data_length;
                    cmd_erasedies <= 1'b1;
                    state <= ERASE_WAIT;
                end

                ERASE_WAIT: begin
                    if(flash_done) begin
                        cmd_erasedies <= 1'b0;
                        state <= STAT_DONE;
                    end
                end

                // STATE ECHO
                STAT_ECHO1: begin
                    tx_data <= data_buffer[0];
                    state <= STAT_ECHO2;
                end

                STAT_ECHO2: begin
                    tx_start <= 1'b1;
                    state <= STAT_ECHO3;
                end

                STAT_ECHO3: begin
                    tx_start <= 1'b0;
                    if (tx_done) begin
                        if (send_cnt >= data_length - 1) begin
                            done <= 1'b1;
                            state <= STAT_ECHO4;
                        end
                        else begin
                            send_cnt <= send_cnt + 1'b1;
                            tx_data <= data_buffer[send_cnt + 1];
                            state <= STAT_ECHO2;
                        end
                    end
                end

                STAT_ECHO4: begin
                    state <= STAT_DONE;
                end
                
                default: state <= STAT_IDLE;
            endcase
        end
    end

    uart_rx uart_rx_inst(
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .baud_set(baud_set),
        .rx(rx),
        .data(rx_data),
        .Rx_Done(rx_done)
    );
    
    uart_tx uart_tx_inst(
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .data(tx_data),
        .send_en(tx_start),
        .baud_set(baud_set),
        .tx(tx),
        .Tx_Done(tx_done),
        .uart_state(tx_busy)
    );

    flash_c flash_ctrl(
        .clk(sys_clk),
        .reset(!sys_rst_n),
        .cmd_erasedies(cmd_erasedies),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .addr(flash_addr),
        .length(flash_length),
        .din(flash_din),
        .dout(flash_dout),
        .read(flash_read),
        .write(flash_write),
        .done(flash_done),
        .error(flash_error),
        .cs(flash_cs),
        .flash_q(flash_q),
        .flash_c(flash_c),
        .flash_d(flash_d)
    );

endmodule
