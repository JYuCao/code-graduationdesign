# Top Level Design Parameters

# Clocks

create_clock -name {ident_coreinst.comm_block_INST.dr2_tck} -period 1000.000000 -waveform {0.000000 500.000000} ident_coreinst/comm_block_INST/jtagi/jtag_clkint_prim:Y
create_clock -name {uart_top|sys_clk} -period 10.000000 -waveform {0.000000 5.000000} sys_clk
create_clock -name {uart_top|atck} -period 10.000000 -waveform {0.000000 5.000000} atck

# False Paths Between Clocks


# False Path Constraints


# Maximum Delay Constraints


# Multicycle Constraints


# Virtual Clocks
# Output Load Constraints
# Driving Cell Constraints
# Wire Loads
# set_wire_load_mode top

# Other Constraints
