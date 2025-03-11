quietly set ACTELLIBNAME ProASIC3
quietly set PROJECT_DIR "C:/Users/jycao/Desktop/1/code-graduationdesign/rs485"

if {[file exists presynth/_info]} {
   echo "INFO: Simulation library presynth already exists"
} else {
   file delete -force presynth 
   vlib presynth
}
vmap presynth presynth
vmap proasic3 "C:/Microsemi/Libero_SoC_v11.8/Designer/lib/modelsim/precompiled/vlog/proasic3"

vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/uart_rx.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/uart_tx.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/uart_top.v"
vlog "+incdir+${PROJECT_DIR}/stimulus" -vlog01compat -work presynth "${PROJECT_DIR}/stimulus/tb_uart_top.v"

vsim -L proasic3 -L presynth  -t 1ps presynth.tb_uart_top
add wave /tb_uart_top/*
run 1000ns
