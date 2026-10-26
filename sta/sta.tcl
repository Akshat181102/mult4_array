# -----------------------------------------------------------------------------
# sta.tcl: OpenSTA static timing analysis of the synthesized mult_array netlist
# Run from the repository root:  sta -exit sta/sta.tcl
# The clock period T (ns) is set below to T_min = 2.788 ns, found as follows:
#   T=10 sta -exit sta/sta.tcl      worst slack 7.213 ns, so 10 - 7.213 = 2.787
#   T=2.787 sta -exit sta/sta.tcl   worst slack -0.000 ns (negative by < 0.5 ps,
#                                   because 7.213 is rounded to 1 ps)
# so T_min is rounded up to the next picosecond, 2.788 ns.
# T=<value> on the command line overrides the period without editing the file.
# Library: sky130_fd_sc_hd, typical corner (tt, 25 C, 1.80 V); ideal clock and
# wires (no placement or routing yet)
# -----------------------------------------------------------------------------
set lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
set T 2.788
if {[info exists ::env(T)]} { set T $::env(T) }

# 1. read the cell library
read_liberty $lib
# 2. read the gate-level netlist from Part B
read_verilog synth/mult_array_netlist.v
# 3. link the design (top module mult_array)
link_design mult_array
# 4. define the clock on port clk with period T
create_clock -name clk -period $T [get_ports clk]
# 5. input and output delays of 1 ns relative to clk (all ports except clk)
set_input_delay 1.0 -clock clk [delete_from_list [all_inputs] [get_ports clk]]
set_output_delay 1.0 -clock clk [all_outputs]
# 6. print the worst setup slack
puts "Clock period T = $T ns"
report_worst_slack -max -digits 3
# 7. write the worst setup path of each path group to the timing report
report_checks -path_delay max -fields {net} -digits 3 > sta/mult_array_timing.rpt
puts "Critical path written to sta/mult_array_timing.rpt"
