module cmd_process(
    input wire sys_clk,
    input wire sys_rst_n,
    input wire rx,
    output reg done,
    output reg error,
    output reg [2:0] data_length,
    output reg [7:0] cmd,
    output wire tx,
    output reg re,

    // Flash interface
    input  wire        flash_q,
    output wire        flash_c,
    output wire        flash_s_n,
    output wire        flash_d
);

    // System reset and baud rate settings
    // wire sys_rst_n;
    // assign sys_rst_n = 1'b1;
    wire [2:0] baud_set;
    assign baud_set = 3'd0;  // Baud rate 9600

    // UART receive related signals
    wire [7:0] rx_data;
    wire rx_done;
    
    // UART transmit related signals
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_done;
    wire tx_busy;
    
    // Command processing state machine
    localparam STAT_IDLE        = 8'd0;
    localparam STAT_GET_LEN     = 8'd1;
    localparam STAT_GET_CMD     = 8'd2;
    localparam STAT_GET_DATA    = 8'd3;
    localparam STAT_EXEC_CMD    = 8'd4;
    localparam STAT_ECHO1       = 8'd5;
    localparam STAT_ECHO2       = 8'd6;
    localparam STAT_ECHO3       = 8'd7;
    localparam STAT_ERROR       = 8'd15;
    localparam STAT_FLASH_WAIT = 8'd8;

    // Command list
    localparam ECHO_DATA = 8'hFF;
    localparam FLASH_ERASE = 8'hA0;
    localparam FLASH_WRITE = 8'hA1;
    localparam FLASH_READ  = 8'hA2;

    // protocol
    localparam CMD_HEAD = 8'hAA;
    localparam CMD_TAIL = 8'h55;

    // Flash控制信号
    reg         flash_cmd_erasedies;
    reg         flash_cmd_write;
    reg         flash_cmd_read;
    reg [27:0]  flash_addr;
    reg [15:0]  flash_length;
    reg [7:0]   flash_din;
    wire [7:0]  flash_dout;
    wire        flash_read;
    wire        flash_write;
    wire        flash_done;
    wire        flash_error;
    
    reg [7:0] state;
    reg [1:0] data_cnt;
    reg [7:0] data_buffer [3:0];
    reg [1:0] send_cnt;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            re <= 1'b0;  
        else if(tx_start)
            re <= 1'b1; 
        else if(tx_done)
            re <= 1'b0; 
    end
    
    // State machine implementation
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            re <= 1'b0;
            state <= STAT_IDLE;
            cmd <= 8'd0;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            send_cnt <= 2'd0;
            data_cnt <= 2'd0;

            flash_cmd_erasedies <= 1'b0;
            flash_cmd_write <= 1'b0;
            flash_cmd_read <= 1'b0;
            flash_addr <= 28'd0;
            flash_length <= 16'd0;
            flash_din <= 8'd0;
        end
        else begin
            flash_cmd_erasedies <= 1'b0;
            flash_cmd_write <= 1'b0;
            flash_cmd_read <= 1'b0;

            case(state)
                STAT_IDLE: begin
                    re <= 1'b0;
                    state <= STAT_IDLE;
                    cmd <= 8'd0;
                    tx_start <= 1'b0;
                    tx_data <= 8'd0;
                    done <= 1'b0;
                    error <= 1'b0;
                    send_cnt <= 2'd0;
                    data_cnt <= 2'd0;
                    if(rx_done) begin
                        if(rx_data == CMD_HEAD) begin  // Command header
                            state <= STAT_GET_LEN;
                        end
                    end
                end

                STAT_GET_LEN: begin
                    if(rx_done) begin
                        data_length <= rx_data;
                        state <= STAT_GET_CMD;
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
                        if(rx_data == CMD_TAIL) begin  // Command tail
                            state <= STAT_EXEC_CMD;
                        end
                        else begin
                            data_buffer[data_cnt] <= rx_data;
                            if(data_cnt >= data_length - 1) begin 
                                state <= STAT_EXEC_CMD;
                            end
                            else begin
                                data_cnt <= data_cnt + 1'b1;
                            end
                        end
                    end
                end
                
                STAT_EXEC_CMD: begin
                    case(cmd)
                        ECHO_DATA: begin 
                            tx_data <= data_buffer[0];
                            state <= STAT_ECHO1;
                        end
                        FLASH_ERASE: begin
                            flash_addr <= {data_buffer[0], data_buffer[1], 
                                         data_buffer[2], data_buffer[3]};
                            flash_length <= 16'h0001;
                            flash_cmd_erasedies <= 1'b1;
                            state <= STAT_FLASH_WAIT;
                        end
                        FLASH_WRITE: begin
                            flash_addr <= {data_buffer[0], data_buffer[1], 
                                         data_buffer[2], data_buffer[3]};
                            flash_length <= 16'h0001;
                            flash_din <= data_buffer[4];
                            flash_cmd_write <= 1'b1;
                            state <= STAT_FLASH_WAIT;
                        end
                        FLASH_READ: begin
                            flash_addr <= {data_buffer[0], data_buffer[1], 
                                         data_buffer[2], data_buffer[3]};
                            flash_length <= {data_buffer[5], data_buffer[4]};
                            flash_cmd_read <= 1'b1;
                            state <= STAT_FLASH_WAIT;
                        end
                        default: state <= STAT_ERROR;
                    endcase
                end

                STAT_FLASH_WAIT: begin
                    if(flash_done) begin
                        if(cmd == FLASH_READ && flash_read) begin
                            tx_data <= flash_dout;
                            tx_start <= 1'b1;
                            if(send_cnt == flash_length - 1) begin
                                done <= 1'b1;
                                state <= STAT_IDLE;
                            end
                            else begin
                                send_cnt <= send_cnt + 1'b1;
                            end
                        end
                        else if(flash_done || flash_error) begin
                            done <= 1'b1;
                            state <= STAT_IDLE;
                        end
                    end
                    else if(flash_error) begin
                        error <= 1'b1;
                        state <= STAT_IDLE;
                    end
                end

                STAT_ECHO1: begin
                    tx_start <= 1'b1;
                    state <= STAT_ECHO2;
                end

                STAT_ECHO2: begin
                    tx_start <= 1'b0;
                    if (tx_done) begin
                        if (send_cnt >= data_length - 1) begin
                            done <= 1'b1;
                            state <= STAT_ECHO3;
                        end
                        else begin
                            send_cnt <= send_cnt + 1'b1;
                            tx_data <= data_buffer[send_cnt + 1];
                            state <= STAT_ECHO1;
                        end
                    end
                end

                STAT_ECHO3: begin
                    state <= STAT_IDLE;
                end

                STAT_ERROR: begin
                    error <= 1'b1;  
                    state <= STAT_IDLE;  
                end
                
                default: state <= STAT_IDLE;
            endcase
        end
    end

    // UART receive module instantiation
    uart_rx uart_rx_inst(
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .baud_set(baud_set),
        .rx(rx),
        .data(rx_data),
        .Rx_Done(rx_done)
    );
    
    // UART transmit module instantiation
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

    flash_b flash_b_inst(
        .clk(sys_clk),
        .reset(~sys_rst_n),
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
        .flash_s_n(flash_s_n),
        .flash_d(flash_d)
    );

endmodule
