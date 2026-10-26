# 4-bit Array Multiplier: RTL to GDSII on SKY130

A 4-bit × 4-bit unsigned array multiplier (16 AND gates, 12 full adders, registered inputs and output) written in Verilog, verified with an exhaustive self-checking testbench, and taken through logic synthesis, static timing analysis and place and route to a GDSII layout on the SkyWater SKY130 130 nm process, using only open-source tools.

## Team

| Name | Roll number |
|---|---|
| Akshat Agrawal | 2026203014 |
| Simon Shibu | 2026203003 |

## Repository structure

```
mult4_array/
├── README.md
├── rtl/      full_adder.v, mult_array.v
├── tb/       tb_mult.v
├── synth/    synth.tcl, mult_array_netlist.v, mult_array_stat.rpt
├── sta/      sta.tcl, mult_array_timing.rpt
├── pnr/      config.json, metrics.json, mult_array.gds
└── report/   report.pdf
```

## Environment

| Item | Version |
|---|---|
| Host | Ubuntu with Docker Engine |
| Tool container | `hpretl/iic-osic-tools:latest`, image digest `sha256:306585de35d198e70ea58950f77147c86f56c698726a19afea9f1c83009557be` |
| PDK and cell library | `sky130A`, `sky130_fd_sc_hd`, typical corner `tt_025C_1v80` |
| Icarus Verilog | 14.0 (devel) |
| GTKWave | 4.0.0-prealpha (f6d60e0) |
| Yosys | 0.70 |
| OpenSTA | 3.1.0 |
| LibreLane | 3.1.0.dev3 |
| KLayout | 0.30.12 |

Unless stated otherwise, every command below is run in a terminal inside the container, from the repository root (`/foss/designs/mult4_array`).

## 0. Environment setup

On the Ubuntu host:

```bash
sudo apt install -y docker.io git
sudo usermod -aG docker $USER            # then log out and back in
docker run --rm hello-world              # check Docker works without sudo

mkdir -p ~/eda/designs
echo 'source sak-pdk-script.sh sky130A sky130_fd_sc_hd > /dev/null || true' > ~/eda/designs/.designinit

git clone --depth 1 https://github.com/iic-jku/IIC-OSIC-TOOLS.git ~/IIC-OSIC-TOOLS
cd ~/IIC-OSIC-TOOLS
until docker pull docker.io/hpretl/iic-osic-tools:latest; do echo "Retrying in 10 s..."; sleep 10; done
./start_vnc.sh                           # desktop at http://localhost/?password=abc123
```

`~/eda/designs` on the host is mounted as `/foss/designs` in the container. The `.designinit` file is sourced by every container shell and selects the sky130A PDK (the container's default PDK is ihp-sg13g2). The `|| true` is needed because the container start-up script stops on any non-zero return code.

Tool check, inside the container:

```bash
iverilog -V | head -1      # Icarus Verilog version 14.0 (devel)
yosys -V                   # Yosys 0.70
sta -version               # 3.1.0
librelane --version        # LibreLane v3.1.0.dev3
echo $PDK_ROOT $PDK        # /foss/pdks sky130A
```

## A. RTL design and verification

Files:

- `rtl/full_adder.v`: 1-bit full adder written with `assign` statements.
- `rtl/mult_array.v`: registered 4-bit array multiplier with 16 AND gates, 12 `full_adder` instances (three `generate` loops) and 16 flip-flops; no `*` operator.
- `tb/tb_mult.v`: exhaustive self-checking testbench (10 ns clock, all 256 input combinations, 2-cycle latency respected, writes `mult.vcd`).

RTL simulation:

```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim                    # PASS: 256 vectors checked, 0 errors
```

Error test: in `rtl/full_adder.v`, `assign sum = a ^ b ^ cin;` was temporarily changed to `assign sum = a ^ b;`, then:

```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim                    # FAIL: 256 vectors checked, 95 errors
```

The change was undone on the host with `git restore rtl/full_adder.v`, and the two RTL simulation commands above were run again (PASS).

Waveform:

```bash
gtkwave --version | head -1
gtkwave mult.vcd &
```

Example from Akshat Agrawal's roll number 2026203014: A = 4 + 5 = 9, B = 7. The inputs are applied at 3040 ns, captured by the input registers at the rising edge at 3045 ns, and the product p = 63 is registered at the rising edge at 3055 ns, a latency of 2 clock cycles. In GTKWave, `clk`, `rst_n`, `a`, `b` and `p` were added, `a`, `b` and `p` shown in decimal, and two named markers placed at 3045 ns and 3055 ns (Markers → Show-Change Marker Data).

For the report, the output of the simulation, synthesis and timing commands was also saved by appending `| tee ../report_work/logs/<name>.log` (a folder outside the repository).

## B. Logic synthesis

Files:

- `synth/synth.tcl`: Yosys script with the seven steps (read_verilog, `synth -top mult_array -flatten`, dfflibmap, abc, `opt_clean -purge`, stat to a report, write_verilog), using the `tt_025C_1v80` Liberty file.
- `synth/mult_array_netlist.v`: gate-level netlist of SKY130 cells, written by Yosys.
- `synth/mult_array_stat.rpt`: cell count and area report, written by Yosys.

Synthesis:

```bash
yosys -c synth/synth.tcl
cat synth/mult_array_stat.rpt
```

Result: 61 cells, of which 16 are flip-flops (`sky130_fd_sc_hd__dfrtp_1`); total cell area 756.976 µm², of which 400.384 µm² (52.89 %) is flip-flops. The most-used cells are `dfrtp_1` (16), `nand2_1` (7), and `and2_0` and `maj3_1` (4 each). The only warnings are two harmless ABC messages: that the network is combinational, and that it detected 9 multi-output library cells (such as `sky130_fd_sc_hd__fa_1`), which it does not map to.

Gate-level (netlist) simulation, with the same testbench and the SKY130 cell models:

```bash
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls                    # PASS: 256 vectors checked, 0 errors
```

The testbench needed no change for the netlist: it checks `p` at the falling clock edge, 5 ns after the rising edge, which is later than the 1 ns delay of the cell models.

## C. Static timing analysis

Files:

- `sta/sta.tcl`: OpenSTA script with the seven steps (read_liberty with the `tt_025C_1v80` library, read_verilog of the Part B netlist, link_design, create_clock on `clk` with period T, 1 ns input and output delays, report_worst_slack, report_checks of the worst setup path). T is set to 2.79 ns (T_min rounded to 0.01 ns); `T=<value>` on the command line overrides it. The script ends with `exit`, so `sta sta/sta.tcl` also works.
- `sta/mult_array_timing.rpt`: worst setup path of each path group at T = 2.79 ns.

Each run used the same command; only the value of `set T` in `sta/sta.tcl` was changed before it:

```bash
sta -exit sta/sta.tcl     # set T 10.0  ->  worst slack max 7.213
sta -exit sta/sta.tcl     # set T 2.787 ->  worst slack max -0.000
sta -exit sta/sta.tcl     # set T 2.788 ->  worst slack max 0.001
sta -exit sta/sta.tcl     # set T 2.79  ->  worst slack max 0.003   (final, committed)
```

From the first run, T_min = T − WNS = 10 − 7.213 = 2.787 ns and F_max = 1000 / 2.787 = 358.8 MHz. The second and third runs checked the rounding of WNS (at 2.787 ns the slack is negative by less than 0.5 ps). The final run uses T_min rounded to 0.01 ns, as the assignment asks, and gives a slack close to 0.

Critical path: from the input register `a_r[1]` (flip-flop `_91_`) to the output register `p[6]` (flip-flop `_88_`), arrival time 2.652 ns. It has 8 logic cells (`clkinv_1`, `o311ai_0`, `a21oi_1`, `maj3_1`, `xnor3_1`, `maj3_1`, `maj3_1`, `xor3_1`), which run from the row 1, bit 1 adder diagonally down to row 3 and along the row 3 carry chain to `p[6]`. Clock-to-Q (0.398 ns), the logic (2.254 ns) and the setup time (0.135 ns) add up to 2.787 ns, which is T_min. Latency 2 × T_min = 5.574 ns; throughput 358.8 million products per second.

## D. Physical design

Files:

- `pnr/config.json`: LibreLane configuration (the two RTL files, clock port `clk`, `CLOCK_PERIOD` = 8.0 ns, fixed 150 µm × 150 µm die).
- `pnr/metrics.json`: metrics of the final, passing run.
- `pnr/mult_array.gds`: final layout.

The first `CLOCK_PERIOD` was 1.2 × T_min = 1.2 × 2.787 = 3.34 ns, rounded up to the next 0.5 ns, so 3.5 ns. In this container LibreLane checks setup timing at all nine corners and stops with an error if any corner has a violation, so the period was increased by 0.5 ns after each failed run until the flow completed. The runs were made with this loop (the run folders go to `pnr/runs/`, which is not committed):

```bash
cd pnr
for T in 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0; do
  sed -i "s/\"CLOCK_PERIOD\": [0-9.]*/\"CLOCK_PERIOD\": $T/" config.json
  echo "=== CLOCK_PERIOD = $T ns ==="
  if librelane config.json > ../../report_work/logs/partD_T${T}.log 2>&1; then
    echo "PASSED at $T ns"; break
  else
    echo "FAILED at $T ns"; grep -A4 -i "violations found" ../../report_work/logs/partD_T${T}.log | head -6
  fi
done
```

| Run | `CLOCK_PERIOD` (ns) | Worst setup slack (ns) | Slack at `nom_tt_025C_1v80` (ns) | Result |
|---|---|---|---|---|
| 1 | 3.5 | −2.188 | +0.509 | fail |
| 2 | 4.0 | −1.688 | +1.009 | fail |
| 3 | 4.5 | −1.188 | +1.509 | fail |
| 4 | 5.0 | −0.686 | +2.009 | fail |
| 5 | 5.5 | −0.208 | +2.509 | fail |
| 6 | 6.0 | −0.154 | +2.877 | fail |
| 7 | 6.5 | −0.220 | +3.119 | fail |
| 8 | 7.0 | −0.134 | +3.520 | fail |
| 9 | 7.5 | −0.104 | +3.737 | fail |
| 10 | 8.0 | +0.396 | +4.237 | pass |

The worst slack of every run is at the slow corner `max_ss_100C_1v60`; every failed run stopped with "Setup violations found in the following corners: max_ss_100C_1v60, min_ss_100C_1v60, nom_ss_100C_1v60".

Copying the results of the final run (`runs/RUN_2026-10-26_18-52-09`) into the repository and opening the layout:

```bash
cp runs/RUN_2026-10-26_18-52-09/final/metrics.json .
cp runs/RUN_2026-10-26_18-52-09/final/gds/mult_array.gds .
klayout -l $PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyp mult_array.gds &
```

Results of the final run:

- Magic and KLayout DRC: 0 errors; Netgen LVS: 0 differences; no antenna violations.
- Worst setup slack +0.396 ns (`max_ss_100C_1v60`), +4.237 ns at the typical corner; worst hold slack +0.136 ns.
- Post-route F_max = 1000 / (8.0 − 0.396) = 131.5 MHz at the worst corner, 1000 / (8.0 − 4.237) = 265.8 MHz at the typical corner (358.8 MHz in Part C).
- 1883 cells: the 62 logic cells of LibreLane's own synthesis (61 in Part B), 3 clock-tree buffers (`clkbuf_16`), 17 port buffers (`buf_2`), 4 fanout and wire buffers (`clkdlybuf4s50_1`, `clkdlybuf4s25_1`), 245 tap, 1298 decap and 254 fill cells.
- Core area 17759.5 µm²; routed wirelength 2499 µm.
- 11 max-slew warnings, only at the slow corners and all on the reset net (0.821 ns against a 0.75 ns limit); they do not stop the flow, and the recovery checks on those pins pass.

## Report

The full report, with the figures, tables and the answers to the assignment questions, is `report/report.pdf`.
