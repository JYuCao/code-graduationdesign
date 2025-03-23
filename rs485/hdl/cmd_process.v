module cmd_process(
    input wire sys_clk,
    input wire rx,
    output reg done,
    output reg error,
    output reg [2:0] data_length,
    output reg [7:0] cmd,
    output wire tx,
    output reg re
);

    // System reset and baud rate settings
    wire sys_rst_n;
    wire [2:0] baud_set;
    assign sys_rst_n = 1'b1;
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
    localparam STAT_IDLE        = 4'd0;
    localparam STAT_GET_LEN     = 4'd1;
    localparam STAT_GET_CMD     = 4'd2;
    localparam STAT_GET_DATA    = 4'd3;
    localparam STAT_EXEC_CMD    = 4'd4;
    localparam STAT_ECHO1       = 4'd5;
    localparam STAT_ECHO2       = 4'd6;
    localparam STAT_ECHO3       = 4'd7;
    localparam STAT_ERROR       = 4'd15;

    // Command list
    localparam ECHO_DATA = 8'hFF;

    // protocol
    localparam CMD_HEAD = 8'hAA;
    localparam CMD_TAIL = 8'h55;
    
    reg [3:0] state;
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
        end
        else begin
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
                        if(rx_data > 4'd3) begin 
                            state <= STAT_ERROR;
                        end
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
                        if(rx_data == CMD_TAIL) begin  // Command tail
                            state <= STAT_EXEC_CMD;
                        end
                        else begin
                            data_buffer[data_cnt] <= rx_data;
                            if(data_cnt >= data_length - 1 || data_cnt == 2'b11) begin 
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
                        default: state <= STAT_ERROR;
                    endcase
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

endmodule
