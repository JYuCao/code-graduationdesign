quietly set ACTELLIBNAME ProASIC3
quietly set PROJECT_DIR "D:/files/fpga/flash_test"

if {[file exists presynth/_info]} {
   echo "INFO: Simulation library presynth already exists"
} else {
   file delete -force presynth 
   vlib presynth
}
vmap presynth presynth
vmap proasic3 "C:/Microsemi/Libero_SoC_v11.8/Designer/lib/modelsim/precompiled/vlog/proasic3"

vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/flash_a.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/flash_b.v"
vlog -vlog01compat -work presynth "${PROJECT_DIR}/hdl/flash_c.v"
vlog "+incdir+${PROJECT_DIR}/stimulus" -vlog01compat -work presynth "${PROJECT_DIR}/stimulus/tb_flash_c.v"

vsim -L proasic3 -L presynth  -t 1ps presynth.tb_flash_c
add wave /tb_flash_c/*
run 1000ns
