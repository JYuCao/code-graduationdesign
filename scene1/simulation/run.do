quietly set ACTELLIBNAME ProASIC3
quietly set PROJECT_DIR "D:/files/fpga/scene1"

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
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/eeprom_a.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/eeprom_b.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/flash_a.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/flash_b.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/flash_c.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/top_can_flash.v"
vlog "+incdir+${PROJECT_DIR}/stimulus" -vlog01compat -work presynth "${PROJECT_DIR}/stimulus/tb_top_can_flash.v"

vsim -L proasic3 -L presynth  -t 1ps presynth.tb_top_can_flash
add wave /tb_top_can_flash/*
run 1000ns
