// available hyper connections - for debug and ip models
// timestamp: 1741346785


`ifndef SYN_HYPER_CONNECT
`define SYN_HYPER_CONNECT 1
module syn_hyper_connect(out) /* synthesis syn_black_box=1 syn_noprune=1 */;
parameter w = 1;
parameter tag = "xxx";
parameter dflt = 0;
parameter mustconnect = 1'b1;
output [w-1:0] out;
endmodule
`endif

module uart_top_hyper_debug(dummy);
input dummy; /* avoid compiler error for no ports */

wire sys_clk_0;
syn_hyper_connect sys_clk_connect_0(sys_clk_0);
defparam sys_clk_connect_0.tag = "sys_clk";


wire [2:0] baud_set_0;
syn_hyper_connect baud_set_connect_0(baud_set_0);
defparam baud_set_connect_0.w = 3;
defparam baud_set_connect_0.tag = "baud_set";


wire Rx_Done_0;
syn_hyper_connect Rx_Done_connect_0(Rx_Done_0);
defparam Rx_Done_connect_0.tag = "Rx_Done";


wire send_en_0;
syn_hyper_connect send_en_connect_0(send_en_0);
defparam send_en_connect_0.tag = "send_en";


wire [7:0] data_to_send_0;
syn_hyper_connect data_to_send_connect_0(data_to_send_0);
defparam data_to_send_connect_0.w = 8;
defparam data_to_send_connect_0.tag = "data_to_send";


wire [7:0] received_data_0;
syn_hyper_connect received_data_connect_0(received_data_0);
defparam received_data_connect_0.w = 8;
defparam received_data_connect_0.tag = "received_data";


wire tx_0;
syn_hyper_connect tx_connect_0(tx_0);
defparam tx_connect_0.tag = "uart_byte_tx.tx";


wire rx_0;
syn_hyper_connect rx_connect_0(rx_0);
defparam rx_connect_0.tag = "uart_byte_rx.rx";


wire nedege_0;
syn_hyper_connect nedege_connect_0(nedege_0);
defparam nedege_connect_0.tag = "uart_byte_rx.nedege";


wire identify_sampler_ready_0;
syn_hyper_connect identify_sampler_ready_connect_0(identify_sampler_ready_0);
defparam identify_sampler_ready_connect_0.tag = "ident_coreinst.IICE_INST.b3_SoW.identify_sampler_ready";


wire Identify_IICE_trigger_ext_0;
syn_hyper_connect Identify_IICE_trigger_ext_connect_0(Identify_IICE_trigger_ext_0);
defparam Identify_IICE_trigger_ext_connect_0.tag = "ident_coreinst.IICE_INST.Identify_IICE_trigger_ext";


wire [7:0] ujtag_wrapper_uireg_0;
syn_hyper_connect ujtag_wrapper_uireg_connect_0(ujtag_wrapper_uireg_0);
defparam ujtag_wrapper_uireg_connect_0.w = 8;
defparam ujtag_wrapper_uireg_connect_0.tag = "ident_coreinst.comm_block_INST.jtagi.ujtag_wrapper_uireg";


wire ujtag_wrapper_urstb_0;
syn_hyper_connect ujtag_wrapper_urstb_connect_0(ujtag_wrapper_urstb_0);
defparam ujtag_wrapper_urstb_connect_0.tag = "ident_coreinst.comm_block_INST.jtagi.ujtag_wrapper_urstb";


wire ujtag_wrapper_udrupd_0;
syn_hyper_connect ujtag_wrapper_udrupd_connect_0(ujtag_wrapper_udrupd_0);
defparam ujtag_wrapper_udrupd_connect_0.tag = "ident_coreinst.comm_block_INST.jtagi.ujtag_wrapper_udrupd";


wire ujtag_wrapper_udrck_0;
syn_hyper_connect ujtag_wrapper_udrck_connect_0(ujtag_wrapper_udrck_0);
defparam ujtag_wrapper_udrck_connect_0.tag = "ident_coreinst.comm_block_INST.jtagi.ujtag_wrapper_udrck";


wire ujtag_wrapper_udrcap_0;
syn_hyper_connect ujtag_wrapper_udrcap_connect_0(ujtag_wrapper_udrcap_0);
defparam ujtag_wrapper_udrcap_connect_0.tag = "ident_coreinst.comm_block_INST.jtagi.ujtag_wrapper_udrcap";


wire ujtag_wrapper_udrsh_0;
syn_hyper_connect ujtag_wrapper_udrsh_connect_0(ujtag_wrapper_udrsh_0);
defparam ujtag_wrapper_udrsh_connect_0.tag = "ident_coreinst.comm_block_INST.jtagi.ujtag_wrapper_udrsh";


wire ujtag_wrapper_utdi_0;
syn_hyper_connect ujtag_wrapper_utdi_connect_0(ujtag_wrapper_utdi_0);
defparam ujtag_wrapper_utdi_connect_0.tag = "ident_coreinst.comm_block_INST.jtagi.ujtag_wrapper_utdi";

endmodule
