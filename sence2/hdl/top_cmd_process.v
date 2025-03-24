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

    reg [2:0] baud_set;

    wire [7:0] rx_data;
    wire rx_done;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_done;
    wire tx_busy;
    reg [7:0] addr;
    reg [7:0] addr_check;
    
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
    localparam CMD_BAUD_SET = 8'hA9;
    localparam CMD_ECHO = 8'hFF;

    // Main state machine
    // Main state machine
    localparam STAT_IDLE = 6'd0;         // Idle state
    localparam STAT_GET_ADDR = 6'd1;     // Get address
    localparam STAT_ADDR_CHECK1 = 6'd2;  // Address check 1
    localparam STAT_ADDR_CHECK2 = 6'd3;  // Address check 2
    localparam STAT_GET_LEN_L = 6'd4;    // Get data length low byte
    localparam STAT_GET_LEN_L_CRC8 = 6'd5;    // CRC8 check for length low byte
    localparam STAT_GET_LEN_H = 6'd6;    // Get data length high byte
    localparam STAT_GET_LEN_H_CRC8 = 6'd7;    // CRC8 check for length high byte
    localparam STAT_GET_CMD = 6'd8;      // Get command
    localparam STAT_GET_CMD_CRC8 = 6'd9;      // CRC8 check for command
    localparam STAT_GET_DATA = 6'd10;     // Get data
    localparam STAT_GET_DATA_CRC8 = 6'd11;     // CRC8 check for data
    localparam STAT_CRC8_check = 6'd12;         // Final CRC8 verification
    localparam STAT_ERROR = 6'd13;       // Error state
    localparam STAT_DONE = 6'd14;        // Complete state

    // Read state machine
    localparam READ_IDLE = 6'd15;        // Read idle
    localparam READ_ADDR = 6'd16;        // Read address
    localparam READ_WAIT = 6'd17;        // Wait for read
    localparam READ_DATA = 6'd18;        // Read data
    localparam READ_SEND = 6'd19;        // Send data

    // Write state machine
    localparam WRITE_IDLE = 6'd20;       // Write idle
    localparam WRITE_ADDR = 6'd21;       // Write address
    localparam WRITE_DATA = 6'd22;       // Write data
    localparam WRITE_WAIT = 6'd23;       // Wait for write
    localparam WRITE_DONE = 6'd24;       // Write complete

    // Erase state machine
    localparam ERASE_IDLE = 6'd25;       // Erase idle
    localparam ERASE_ADDR = 6'd26;       // Erase address
    localparam ERASE_WAIT = 6'd27;       // Wait for erase
    localparam ERASE_DONE = 6'd28;       // Erase complete 

    // Baud set state machine
    localparam STAT_BAUD_SET = 6'd29;

    // ECHO state machine for test
    localparam STAT_ECHO1 = 6'd58;
    localparam STAT_ECHO2 = 6'd59;
    localparam STAT_ECHO3 = 6'd60;
    localparam STAT_ECHO4 = 6'd61;
    
    reg [5:0] state;
    reg [15:0] data_length;
    reg [7:0] cmd;
    reg [15:0] data_cnt;
    reg [7:0] data_buffer [15:0];
    reg [7:0] calc_crc8;     
    
    // CRC8Table(x^8 + x^2 + x^1 + 1)
    reg [7:0] crc8_table [255:0];
    initial begin
        crc8_table[0] = 8'h00; crc8_table[1] = 8'h07; crc8_table[2] = 8'h0E; crc8_table[3] = 8'h09;
        crc8_table[4] = 8'h1C; crc8_table[5] = 8'h1B; crc8_table[6] = 8'h12; crc8_table[7] = 8'h15;
        crc8_table[8] = 8'h38; crc8_table[9] = 8'h3F; crc8_table[10] = 8'h36; crc8_table[11] = 8'h31;
        crc8_table[12] = 8'h24; crc8_table[13] = 8'h23; crc8_table[14] = 8'h2A; crc8_table[15] = 8'h2D;
        crc8_table[16] = 8'h70; crc8_table[17] = 8'h77; crc8_table[18] = 8'h7E; crc8_table[19] = 8'h79;
        crc8_table[20] = 8'h6C; crc8_table[21] = 8'h6B; crc8_table[22] = 8'h62; crc8_table[23] = 8'h65;
        crc8_table[24] = 8'h48; crc8_table[25] = 8'h4F; crc8_table[26] = 8'h46; crc8_table[27] = 8'h41;
        crc8_table[28] = 8'h54; crc8_table[29] = 8'h53; crc8_table[30] = 8'h5A; crc8_table[31] = 8'h5D;
        crc8_table[32] = 8'hE0; crc8_table[33] = 8'hE7; crc8_table[34] = 8'hEE; crc8_table[35] = 8'hE9;
        crc8_table[36] = 8'hFC; crc8_table[37] = 8'hFB; crc8_table[38] = 8'hF2; crc8_table[39] = 8'hF5;
        crc8_table[40] = 8'hD8; crc8_table[41] = 8'hDF; crc8_table[42] = 8'hD6; crc8_table[43] = 8'hD1;
        crc8_table[44] = 8'hC4; crc8_table[45] = 8'hC3; crc8_table[46] = 8'hCA; crc8_table[47] = 8'hCD;
        crc8_table[48] = 8'h90; crc8_table[49] = 8'h97; crc8_table[50] = 8'h9E; crc8_table[51] = 8'h99;
        crc8_table[52] = 8'h8C; crc8_table[53] = 8'h8B; crc8_table[54] = 8'h82; crc8_table[55] = 8'h85;
        crc8_table[56] = 8'hA8; crc8_table[57] = 8'hAF; crc8_table[58] = 8'hA6; crc8_table[59] = 8'hA1;
        crc8_table[60] = 8'hB4; crc8_table[61] = 8'hB3; crc8_table[62] = 8'hBA; crc8_table[63] = 8'hBD;
        crc8_table[64] = 8'hC7; crc8_table[65] = 8'hC0; crc8_table[66] = 8'hC9; crc8_table[67] = 8'hCE;
        crc8_table[68] = 8'hDB; crc8_table[69] = 8'hDC; crc8_table[70] = 8'hD5; crc8_table[71] = 8'hD2;
        crc8_table[72] = 8'hFF; crc8_table[73] = 8'hF8; crc8_table[74] = 8'hF1; crc8_table[75] = 8'hF6;
        crc8_table[76] = 8'hE3; crc8_table[77] = 8'hE4; crc8_table[78] = 8'hED; crc8_table[79] = 8'hEA;
        crc8_table[80] = 8'hB7; crc8_table[81] = 8'hB0; crc8_table[82] = 8'hB9; crc8_table[83] = 8'hBE;
        crc8_table[84] = 8'hAB; crc8_table[85] = 8'hAC; crc8_table[86] = 8'hA5; crc8_table[87] = 8'hA2;
        crc8_table[88] = 8'h8F; crc8_table[89] = 8'h88; crc8_table[90] = 8'h81; crc8_table[91] = 8'h86;
        crc8_table[92] = 8'h93; crc8_table[93] = 8'h94; crc8_table[94] = 8'h9D; crc8_table[95] = 8'h9A;
        crc8_table[96] = 8'h27; crc8_table[97] = 8'h20; crc8_table[98] = 8'h29; crc8_table[99] = 8'h2E;
        crc8_table[100] = 8'h3B; crc8_table[101] = 8'h3C; crc8_table[102] = 8'h35; crc8_table[103] = 8'h32;
        crc8_table[104] = 8'h1F; crc8_table[105] = 8'h18; crc8_table[106] = 8'h11; crc8_table[107] = 8'h16;
        crc8_table[108] = 8'h03; crc8_table[109] = 8'h04; crc8_table[110] = 8'h0D; crc8_table[111] = 8'h0A;
        crc8_table[112] = 8'h57; crc8_table[113] = 8'h50; crc8_table[114] = 8'h59; crc8_table[115] = 8'h5E;
        crc8_table[116] = 8'h4B; crc8_table[117] = 8'h4C; crc8_table[118] = 8'h45; crc8_table[119] = 8'h42;
        crc8_table[120] = 8'h6F; crc8_table[121] = 8'h68; crc8_table[122] = 8'h61; crc8_table[123] = 8'h66;
        crc8_table[124] = 8'h73; crc8_table[125] = 8'h74; crc8_table[126] = 8'h7D; crc8_table[127] = 8'h7A;
        crc8_table[128] = 8'h89; crc8_table[129] = 8'h8E; crc8_table[130] = 8'h87; crc8_table[131] = 8'h80;
        crc8_table[132] = 8'h95; crc8_table[133] = 8'h92; crc8_table[134] = 8'h9B; crc8_table[135] = 8'h9C;
        crc8_table[136] = 8'hB1; crc8_table[137] = 8'hB6; crc8_table[138] = 8'hBF; crc8_table[139] = 8'hB8;
        crc8_table[140] = 8'hAD; crc8_table[141] = 8'hAA; crc8_table[142] = 8'hA3; crc8_table[143] = 8'hA4;
        crc8_table[144] = 8'hF9; crc8_table[145] = 8'hFE; crc8_table[146] = 8'hF7; crc8_table[147] = 8'hF0;
        crc8_table[148] = 8'hE5; crc8_table[149] = 8'hE2; crc8_table[150] = 8'hEB; crc8_table[151] = 8'hEC;
        crc8_table[152] = 8'hC1; crc8_table[153] = 8'hC6; crc8_table[154] = 8'hCF; crc8_table[155] = 8'hC8;
        crc8_table[156] = 8'hDD; crc8_table[157] = 8'hDA; crc8_table[158] = 8'hD3; crc8_table[159] = 8'hD4;
        crc8_table[160] = 8'h69; crc8_table[161] = 8'h6E; crc8_table[162] = 8'h67; crc8_table[163] = 8'h60;
        crc8_table[164] = 8'h75; crc8_table[165] = 8'h72; crc8_table[166] = 8'h7B; crc8_table[167] = 8'h7C;
        crc8_table[168] = 8'h51; crc8_table[169] = 8'h56; crc8_table[170] = 8'h5F; crc8_table[171] = 8'h58;
        crc8_table[172] = 8'h4D; crc8_table[173] = 8'h4A; crc8_table[174] = 8'h43; crc8_table[175] = 8'h44;
        crc8_table[176] = 8'h19; crc8_table[177] = 8'h1E; crc8_table[178] = 8'h17; crc8_table[179] = 8'h10;
        crc8_table[180] = 8'h05; crc8_table[181] = 8'h02; crc8_table[182] = 8'h0B; crc8_table[183] = 8'h0C;
        crc8_table[184] = 8'h21; crc8_table[185] = 8'h26; crc8_table[186] = 8'h2F; crc8_table[187] = 8'h28;
        crc8_table[188] = 8'h3D; crc8_table[189] = 8'h3A; crc8_table[190] = 8'h33; crc8_table[191] = 8'h34;
        crc8_table[192] = 8'h4E; crc8_table[193] = 8'h49; crc8_table[194] = 8'h40; crc8_table[195] = 8'h47;
        crc8_table[196] = 8'h52; crc8_table[197] = 8'h55; crc8_table[198] = 8'h5C; crc8_table[199] = 8'h5B;
        crc8_table[200] = 8'h76; crc8_table[201] = 8'h71; crc8_table[202] = 8'h78; crc8_table[203] = 8'h7F;
        crc8_table[204] = 8'h6A; crc8_table[205] = 8'h6D; crc8_table[206] = 8'h64; crc8_table[207] = 8'h63;
        crc8_table[208] = 8'h3E; crc8_table[209] = 8'h39; crc8_table[210] = 8'h30; crc8_table[211] = 8'h37;
        crc8_table[212] = 8'h22; crc8_table[213] = 8'h25; crc8_table[214] = 8'h2C; crc8_table[215] = 8'h2B;
        crc8_table[216] = 8'h06; crc8_table[217] = 8'h01; crc8_table[218] = 8'h08; crc8_table[219] = 8'h0F;
        crc8_table[220] = 8'h1A; crc8_table[221] = 8'h1D; crc8_table[222] = 8'h14; crc8_table[223] = 8'h13;
        crc8_table[224] = 8'hAE; crc8_table[225] = 8'hA9; crc8_table[226] = 8'hA0; crc8_table[227] = 8'hA7;
        crc8_table[228] = 8'hB2; crc8_table[229] = 8'hB5; crc8_table[230] = 8'hBC; crc8_table[231] = 8'hBB;
        crc8_table[232] = 8'h96; crc8_table[233] = 8'h91; crc8_table[234] = 8'h98; crc8_table[235] = 8'h9F;
        crc8_table[236] = 8'h8A; crc8_table[237] = 8'h8D; crc8_table[238] = 8'h84; crc8_table[239] = 8'h83;
        crc8_table[240] = 8'hDE; crc8_table[241] = 8'hD9; crc8_table[242] = 8'hD0; crc8_table[243] = 8'hD7;
        crc8_table[244] = 8'hC2; crc8_table[245] = 8'hC5; crc8_table[246] = 8'hCC; crc8_table[247] = 8'hCB;
        crc8_table[248] = 8'hE6; crc8_table[249] = 8'hE1; crc8_table[250] = 8'hE8; crc8_table[251] = 8'hEF;
        crc8_table[252] = 8'hE3; crc8_table[253] = 8'hE4; crc8_table[254] = 8'hED; crc8_table[255] = 8'hEA;
    end
    
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            re <= 1'b0;  
        else if(tx_start)
            re <= 1'b1; 
        else if(tx_done)
            re <= 1'b0; 
    end

    reg power_on_rst = 1'b1;
    reg [3:0] rst_cnt = 4'd0;
    
    always @(posedge sys_clk) begin
        if(rst_cnt < 4'hF)
            rst_cnt <= rst_cnt + 1'b1;
        else
            power_on_rst <= 1'b0;
    end

    // Main state machine
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n || power_on_rst) begin
            baud_set <= 3'd0;
            state <= STAT_IDLE;
            cmd <= 8'd0;
            data_length <= 16'd0;
            error <= 1'b0;
            done <= 1'b0;
            data_cnt <= 16'd0;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
            calc_crc8 <= 8'd0;
        end
        else begin
            case(state)
                STAT_IDLE: begin
                    cmd <= 8'd0;
                    data_length <= 3'd0;
                    error <= 1'b0;
                    done <= 1'b0;
                    data_cnt <= 16'd0;
                    tx_start <= 1'b0;
                    tx_data <= 8'd0;
                    calc_crc8 <= 8'd0;
                    if(rx_done)
                        state <= STAT_GET_ADDR;
                end

                STAT_GET_ADDR: begin
                    addr <= rx_data;
                    state <= STAT_ADDR_CHECK1;
                end
                STAT_ADDR_CHECK1: begin
                    if (rx_done) begin
                        addr_check <= rx_data;
                        state <= STAT_ADDR_CHECK2;
                    end
                end
                STAT_ADDR_CHECK2: begin
                    if(addr + addr_check == 8'h00)
                        state <= STAT_GET_LEN_L;
                    else 
                        state <= STAT_ERROR;
                end

                STAT_GET_LEN_L: begin
                    if (rx_done) begin
                        data_length[7:0] <= rx_data;
                        state <= STAT_GET_LEN_L_CRC8;
                    end
                end
                STAT_GET_LEN_L_CRC8: begin
                    calc_crc8 <= crc8_table[rx_data];
                    state <= STAT_GET_LEN_H;
                end
                STAT_GET_LEN_H: begin
                    if (rx_done) begin
                        data_length[15:8] <= rx_data;
                        state <= STAT_GET_LEN_H_CRC8;
                    end
                end
                STAT_GET_LEN_H_CRC8: begin
                    calc_crc8 <= crc8_table[rx_data ^ calc_crc8];
                    state <= STAT_GET_CMD;
                end

                STAT_GET_CMD: begin
                    if (rx_done) begin
                        cmd <= rx_data;
                        state <= STAT_GET_CMD_CRC8;
                    end
                end
                STAT_GET_CMD_CRC8: begin
                    calc_crc8 <= crc8_table[rx_data ^ calc_crc8];
                    state <= STAT_GET_DATA;
                end

                STAT_GET_DATA: begin
                    if(rx_done) begin
                        data_buffer[data_cnt] <= rx_data;
                        state <= STAT_GET_DATA_CRC8;
                    end
                end
                STAT_GET_DATA_CRC8: begin
                    calc_crc8 <= crc8_table[rx_data ^ calc_crc8];
                    if(data_cnt >= data_length - 1) begin 
                        state <= STAT_CRC8_check;
                    end
                    else begin
                        data_cnt <= data_cnt + 1'b1;
                        state <= STAT_GET_DATA;
                    end
                end

                STAT_CRC8_check: begin
                    if(rx_done) begin
                        if(calc_crc8 == rx_data) begin
                            case(cmd)
                                CMD_READ: state <= READ_ADDR;
                                CMD_WRITE: state <= WRITE_ADDR;
                                CMD_ERASE: state <= ERASE_ADDR;
                                CMD_ECHO: state <= STAT_ECHO1;
                                CMD_BAUD_SET: state <= STAT_BAUD_SET;
                                default: state <= STAT_ERROR;
                            endcase
                        end
                        else
                            state <= STAT_ERROR;
                    end
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

                // STATE BAUD SET
                STAT_BAUD_SET: begin
                    baud_set <= data_buffer[0][2:0];
                    state <= STAT_DONE;
                end

                // STATE ECHO
                STAT_ECHO1: begin
                    data_cnt <= 16'd0;
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
                        if (data_cnt >= data_length - 1) begin
                            done <= 1'b1;
                            state <= STAT_ECHO4;
                        end
                        else begin
                            data_cnt <= data_cnt + 1'b1;
                            tx_data <= data_buffer[data_cnt + 1];
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
