quietly set ACTELLIBNAME ProASIC3
quietly set PROJECT_DIR "D:/files/fpga/CAN"

if {[file exists presynth/_info]} {
   echo "INFO: Simulation library presynth already exists"
} else {
   file delete -force presynth 
   vlib presynth
}
vmap presynth presynth
vmap proasic3 "C:/Microsemi/Libero_SoC_v11.8/Designer/lib/modelsim/precompiled/vlog/proasic3"

vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/can_level_bit.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/can_level_packet.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/can_top.v"
vlog "+incdir+${PROJECT_DIR}/stimulus" -vlog01compat -work presynth "${PROJECT_DIR}/stimulus/tb_can_top.v"

vsim -L proasic3 -L presynth  -t 1ps presynth.tb_can_top
add wave /tb_can_top/*
run 1000ns
