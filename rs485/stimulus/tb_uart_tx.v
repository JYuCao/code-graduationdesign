//////////////////////////////////////////////////////////////////////
// Created by Microsemi SmartDesign Fri Jan 10 14:27:12 2025
// Testbench Template
// This is a basic testbench that instantiates your design with basic 
// clock and reset pins connected.  If your design has special
// clock/reset or testbench driver requirements then you should 
// copy this file and modify it. 
//////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: tb_uart_tx.v
// File history:
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//
// Description: 
//
// <Description here>
//
// Targeted device: <Family::ProASIC3> <Die::A3P250> <Package::100 VQFP>
// Author: <Name>
//
/////////////////////////////////////////////////////////////////////////////////////////////////// 

`timescale 1ns/100ps

module tb_uart_tx;

parameter SYSCLK_PERIOD = 20;// 50MHZ

reg SYSCLK;
reg NSYSRESET;

reg [7:0]data;
reg send_en;
reg [2:0]baud_set;

wire tx;
wire Tx_Done;
wire uart_state;

initial
begin
    SYSCLK = 1'b0;
    NSYSRESET = 1'b0;
    baud_set = 3'd4;
    data = 8'd0;
	send_en = 1'd0;
end


//////////////////////////////////////////////////////////////////////
// Clock Driver
//////////////////////////////////////////////////////////////////////
always @(SYSCLK)
    #(SYSCLK_PERIOD / 2.0) SYSCLK <= !SYSCLK;


//////////////////////////////////////////////////////////////////////
// Instantiate Unit Under Test:  uart_tx
//////////////////////////////////////////////////////////////////////
uart_tx uart_tx_0 (
    // Inputs
    .sys_clk(SYSCLK),
    .sys_rst_n(NSYSRESET),
    .data(data),
    .send_en(send_en),
    .baud_set(baud_set),

    // Outputs
    .tx(tx),
    .Tx_Done(Tx_Done),
    .uart_state(uart_state)

    // Inouts

);

initial begin
    #(SYSCLK_PERIOD*20 + 1)
    NSYSRESET = 1'b1;
    #(SYSCLK_PERIOD*50);
    data = 8'haa;
    send_en = 1'd1;
    #SYSCLK_PERIOD;
    send_en = 1'd0;

    @(posedge Tx_Done)
    
    #(SYSCLK_PERIOD);
    data = 8'h55;
    send_en = 1'd1;
    #SYSCLK_PERIOD;
    send_en = 1'd0;

    @(posedge Tx_Done)
    #(SYSCLK_PERIOD);
    $stop;
end

endmodule

