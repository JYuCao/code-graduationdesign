# Created by Microsemi Libero Software 11.8.2.4
# Wed Mar 05 10:23:35 2025

# (OPEN DESIGN)

open_design "uart_rx.adb"

# set default back-annotation base-name
set_defvar "BA_NAME" "uart_rx_ba"
set_defvar "IDE_DESIGNERVIEW_NAME" {Impl1}
set_defvar "IDE_DESIGNERVIEW_COUNT" "1"
set_defvar "IDE_DESIGNERVIEW_REV0" {Impl1}
set_defvar "IDE_DESIGNERVIEW_REVNUM0" "1"
set_defvar "IDE_DESIGNERVIEW_ROOTDIR" {D:\files\fpga\rs485\designer}
set_defvar "IDE_DESIGNERVIEW_LASTREV" "1"


layout -timing_driven
report -type "status" {uart_rx_place_and_route_report.txt}
report -type "globalnet" {uart_rx_globalnet_report.txt}
report -type "globalusage" {uart_rx_globalusage_report.txt}
report -type "iobank" {uart_rx_iobank_report.txt}
report -type "pin" -listby "name" {uart_rx_report_pin_byname.txt}
report -type "pin" -listby "number" {uart_rx_report_pin_bynumber.txt}

save_design
