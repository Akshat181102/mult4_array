# -----------------------------------------------------------------------------
# synth.tcl: Yosys synthesis of mult_array to SKY130 standard cells
# Run from the repository root:  yosys -c synth/synth.tcl
# Library: sky130_fd_sc_hd, typical corner (tt, 25 C, 1.80 V)
# -----------------------------------------------------------------------------
set lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 1. read the design
yosys read_verilog rtl/full_adder.v rtl/mult_array.v
# 2. generic synthesis; flatten the 12 full adders into one module
yosys synth -top mult_array -flatten
# 3. map the flip-flops to SKY130 flip-flop cells
yosys dfflibmap -liberty $lib
# 4. map the combinational logic to SKY130 gate cells
yosys abc -liberty $lib
# 5. remove unused wires
yosys opt_clean -purge
# 6. write the cell and area report
yosys tee -o synth/mult_array_stat.rpt stat -liberty $lib
# 7. write the gate-level netlist
yosys write_verilog -noattr synth/mult_array_netlist.v
