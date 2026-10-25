# 4-bit Array Multiplier: RTL to GDSII on SKY130

A 4-bit × 4-bit unsigned array multiplier (16 AND gates, 12 full adders, registered inputs and output) written in Verilog, verified with an exhaustive self-checking testbench, and taken through logic synthesis, static timing analysis and place and route to a GDSII layout on the SkyWater SKY130 130 nm process, using only open-source tools.

## Team

| Name | Roll number |
|---|---|
| Akshat Agrawal | 2026203014 |
| *Partner name* | *Partner roll number* |

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
| Yosys | 0.70 |
| OpenSTA | 3.1.0 |
| LibreLane | 3.1.0.dev3 |

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

*Pending.*

## B. Logic synthesis

*Pending.*

## C. Static timing analysis

*Pending.*

## D. Physical design

*Pending.*
