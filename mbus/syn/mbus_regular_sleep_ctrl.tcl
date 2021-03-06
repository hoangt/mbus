# TCL script for Design Compiler

# Load common variables, artisan standard cells
source -verbose "common.tcl"

# Set top level name
set top_level "mbus_regular_sleep_ctrl"

# Read verilog files
read_verilog "../verilog/mbus_regular_sleep_ctrl.v "
analyze -format verilog "../verilog/mbus_regular_sleep_ctrl.v"
current_design $top_level

list_designs

# Timing setup for synthesis

# Clock period
set clk_period 2500
set clk_uncertainty 1
set clk_transition 1
set clk_name "CLKIN"
set clk_port "CLKIN"
create_clock -name $clk_name -period $clk_period [get_ports $clk_port] 
set_drive 0 [get_clocks $clk_name] 
set_clock_uncertainty $clk_uncertainty [get_clocks $clk_name]
set_clock_transition $clk_transition [get_clocks $clk_name]

set_operating_conditions "typical" -library "typical" 
set_wire_load_model -name "tsmc18_wl50" -library "typical" 
set_wire_load_mode "segmented" 

set typical_input_delay 0.100
set typical_output_delay 0.100
set typical_wire_load 0.010 

# Link the design
link

# Set maximum fanout of gates
set_max_fanout 4 $top_level 

# Configure the clock network
set_fix_hold [all_clocks] 
set_dont_touch_network $clk_port

# Set delays: Input, Output
set_driving_cell -lib_cell INVX2 [all_inputs]
set_input_delay $typical_input_delay [all_inputs] -clock $clk_name 
remove_input_delay -clock $clk_name [find port $clk_port]
set_output_delay $typical_output_delay [all_outputs] -clock $clk_name 

# Set loading of outputs 
set_load $typical_wire_load [all_outputs]

# Verify the design
check_design

# Uniquify repeated modules
uniquify

# Synthesize the design
compile_ultra 

# Rename modules, signals according to the naming rules
# Used for tool exchange
source -verbose "namingrules.tcl"

# Generate structural verilog netlist
write -hierarchy -format verilog -output "${top_level}.nl.v"

# Generate Standard Delay Format (SDF) file
write_sdf -context verilog "${top_level}.pt.sdf"
#Write SDC file
write_sdc "${top_level}.sdc"

#Reporting
set rpt_file "${top_level}.dc.rpt"
source -verbose "common_report.tcl"

#Exit dc_shell
quit
