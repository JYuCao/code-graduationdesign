new_project \
    -name {uart_top} \
    -location {C:\Users\jycao\Desktop\1\code-graduationdesign\rs485\designer\impl1\uart_top_fp} \
    -mode {single}
set_programming_file -file {C:\Users\jycao\Desktop\1\code-graduationdesign\rs485\designer\impl1\uart_top.pdb}
set_programming_action -action {PROGRAM}
run_selected_actions
save_project
close_project
