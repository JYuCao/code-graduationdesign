quietly set ACTELLIBNAME ProASIC3
quietly set PROJECT_DIR "D:/files/fpga/eeprom"

if {[file exists presynth/_info]} {
   echo "INFO: Simulation library presynth already exists"
} else {
   file delete -force presynth 
   vlib presynth
}
vmap presynth presynth
vmap proasic3 "C:/Microsemi/Libero_SoC_v11.8/Designer/lib/modelsim/precompiled/vlog/proasic3"

vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/eeprom_a.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/eeprom_b.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/uart_rx.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/uart_tx.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/cmd_process.v"
vlog "+incdir+${PROJECT_DIR}/stimulus" -vlog01compat -work presynth "${PROJECT_DIR}/stimulus/tb_cmd_process.v"

vsim -L proasic3 -L presynth  -t 1ps presynth.tb_cmd_process
add wave /tb_cmd_process/*
run 1000ns
