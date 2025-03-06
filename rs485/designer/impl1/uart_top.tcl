# Created by Microsemi Libero Software 11.8.2.4
# Thu Mar 06 13:05:36 2025

# (NEW DESIGN)

# create a new design
new_design -name "uart_top" -family "ProASIC3"
set_device -die {A3P250} -package {100 VQFP} -speed {STD} -voltage {1.5} -IO_DEFT_STD {LVTTL} -RESERVEMIGRATIONPINS {1} -RESTRICTPROBEPINS {1} -RESTRICTSPIPINS {0} -TARGETDEVICESFORMIGRATION {IS4X4M1} -TEMPR {COM} -UNUSED_MSS_IO_RESISTOR_PULL {None} -VCCI_1.5_VOLTR {COM} -VCCI_1.8_VOLTR {COM} -VCCI_2.5_VOLTR {COM} -VCCI_3.3_VOLTR {COM} -VOLTR {COM}


# set default back-annotation base-name
set_defvar "BA_NAME" "uart_top_ba"
set_defvar "IDE_DESIGNERVIEW_NAME" {Impl1}
set_defvar "IDE_DESIGNERVIEW_COUNT" "1"
set_defvar "IDE_DESIGNERVIEW_REV0" {Impl1}
set_defvar "IDE_DESIGNERVIEW_REVNUM0" "1"
set_defvar "IDE_DESIGNERVIEW_ROOTDIR" {D:\files\fpga\rs485\designer}
set_defvar "IDE_DESIGNERVIEW_LASTREV" "1"

# set working directory
set_defvar "DESDIR" "D:/files/fpga/rs485/designer/impl1"

# set back-annotation output directory
set_defvar "BA_DIR" "D:/files/fpga/rs485/designer/impl1"

# enable the export back-annotation netlist
set_defvar "BA_NETLIST_ALSO" "1"

# set EDIF options
set_defvar "EDNINFLAVOR" "GENERIC"

# set HDL options
set_defvar "NETLIST_NAMING_STYLE" "VERILOG"

# setup status report options
set_defvar "EXPORT_STATUS_REPORT" "1"
set_defvar "EXPORT_STATUS_REPORT_FILENAME" "uart_top.rpt"

# legacy audit-mode flags (left here for historical reasons)
set_defvar "AUDIT_NETLIST_FILE" "1"
set_defvar "AUDIT_DCF_FILE" "1"
set_defvar "AUDIT_PIN_FILE" "1"
set_defvar "AUDIT_ADL_FILE" "1"

# import of input files
import_source  \
-format "edif" -edif_flavor "GENERIC" -netlist_naming "VERILOG" {../../synthesis/uart_top.edn}

# save the design database
save_design {uart_top.adb}


compile
report -type "status" {uart_top_compile_report.txt}
report -type "pin" -listby "name" {uart_top_report_pin_byname.txt}
report -type "pin" -listby "number" {uart_top_report_pin_bynumber.txt}

save_design
