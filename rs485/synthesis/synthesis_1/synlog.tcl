project -load C:/Users/jycao/Desktop/1/code-graduationdesign/rs485/synthesis/uart_top_syn.prj
puts "Generating SRS instrumentation file: C:\Users\jycao\Desktop\1\code-graduationdesign\rs485\synthesis\synthesis_1\instr_sources\syn_dics.v"
 if { [catch {write instrumentation} err] } {
    puts stderr "write instrumentation failed $err"
    exit 9
}
