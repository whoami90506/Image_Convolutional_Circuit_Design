#Import design
read_file -format verilog "./CONV.v"
source -echo -verbose ./CONV.sdc
set high_fanout_net_threshold 0

#compile design
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
check_design
check_design > syn/check_design.report
compile_ultra

#output
remove_unconnected_ports -blast_buses [get_cells -hierarchical *]
set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true
change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule
write -format verilog -hierarchy -output "syn/CONV_syn.v"
write_sdf -version 1.0 -context verilog -load_delay net syn/lcd_ctrl_syn.sdf
report_timing > syn/timing.report
report_area > syn/area.report
report_power > syn/power.report
report_timing
quit