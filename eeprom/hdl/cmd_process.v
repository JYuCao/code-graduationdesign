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

    // EEPROM接口
    input  wire        eeprom_q,
    output wire        eeprom_c,
    output wire        eeprom_s_n,
    output wire        eeprom_d
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
    localparam STAT_EEPROM_WAIT = 8'd8;
    localparam STAT_READ_DATA   = 8'd9;
    localparam STAT_ERROR       = 8'd15;

    // Command list
    localparam ECHO_DATA    = 8'hFF;
    localparam EEPROM_WRITE = 8'hA0;
    localparam EEPROM_READ  = 8'hA1;

    // protocol
    localparam CMD_HEAD = 8'hAA;
    localparam CMD_TAIL = 8'h55;
    
    reg [7:0] state;
    reg [1:0] data_cnt;
    reg [7:0] data_buffer [3:0];
    reg [1:0] send_cnt;
    reg         eeprom_cmd_write;
    reg         eeprom_cmd_read;
    reg [15:0]  eeprom_addr;
    reg [15:0]  eeprom_length;
    reg [7:0]   eeprom_din;
    wire [7:0]  eeprom_dout;
    wire        eeprom_busy;

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

            eeprom_cmd_write <= 1'b0;
            eeprom_cmd_read <= 1'b0;
            eeprom_addr <= 16'd0;
            eeprom_length <= 16'd0;
            eeprom_din <= 8'd0;
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
                        data_buffer[data_cnt] <= rx_data;
                        if(data_cnt >= data_length - 1) begin 
                            state <= STAT_EXEC_CMD;
                        end
                        else begin
                            data_cnt <= data_cnt + 1'b1;
                        end
                    end
                end
                
                STAT_EXEC_CMD: begin
                    case(cmd)
                        ECHO_DATA: begin 
                            tx_data <= data_buffer[0];
                            state <= STAT_ECHO1;
                        end
                        EEPROM_WRITE: begin
                            eeprom_addr <= {data_buffer[0], data_buffer[1]};
                            eeprom_din <= data_buffer[2];
                            eeprom_length <= 16'd1;
                            eeprom_cmd_write <= 1'b1;
                            state <= STAT_EEPROM_WAIT;
                        end
                        EEPROM_READ: begin
                            eeprom_addr <= {data_buffer[0], data_buffer[1]};
                            eeprom_length <= {data_buffer[2], data_buffer[3]};
                            eeprom_cmd_read <= 1'b1;
                            state <= STAT_EEPROM_WAIT;
                        end
                        default: state <= STAT_ERROR;
                    endcase
                end

                STAT_EEPROM_WAIT: begin
                    eeprom_cmd_write <= 1'b0;
                    eeprom_cmd_read <= 1'b0;
                    if(!eeprom_busy) begin
                        if(cmd == EEPROM_READ) begin
                            tx_data <= eeprom_dout;
                            tx_start <= 1'b1;
                            state <= STAT_READ_DATA;
                        end
                        else begin
                            done <= 1'b1;
                            state <= STAT_IDLE;
                        end
                    end
                end

                // 添加读取数据状态
                STAT_READ_DATA: begin
                    tx_start <= 1'b0;
                    if(tx_done) begin
                        done <= 1'b1;
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

    eeprom_b eeprom_b_inst(
        .clk(sys_clk),
        .reset(~sys_rst_n),
        .cmd_write(eeprom_cmd_write),
        .cmd_read(eeprom_cmd_read),
        .addr(eeprom_addr),
        .length(eeprom_length),
        .din(eeprom_din),
        .dout(eeprom_dout),
        .busy(eeprom_busy),
        .eeprom_q(eeprom_q),
        .eeprom_c(eeprom_c),
        .eeprom_s_n(eeprom_s_n),
        .eeprom_d(eeprom_d)
    );

endmodule
