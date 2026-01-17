# dcache Project

This project implements a Data Cache Controller with an AHB interface (`dcache_ahb_ctrl`), written in SystemVerilog. It includes the RTL design, simulation environments, and build scripts managed via a Makefile.

## Project Structure

```text
/
├── .env                # Environment configuration
├── Makefile            # Main entry point for project commands
├── cores/              # Hardware cores (RTL, Sim, Syn)
│   ├── dcache_ahb_ctrl/ # The main Data Cache Controller core
│   └── pkg_dcache/      # Shared package definitions
└── scripts/            # Python scripts for project management and automation
```

## Getting Started

### Prerequisites

*   **Python 3**: Required for the environment setup and helper scripts.
*   **Simulator**: The Makefile supports `xsim` (Vivado) and `verilator`.
*   **Synthesis**: Xilinx Vivado is assumed for the build/project targets.

### Setup

To set up the Python virtual environment and install dependencies (cocotb, pyuvm, pytest):

```bash
make setup
```

This will create a `_env` directory and a `source_simpl` file.

### Simulation

To run the simulation for the target core (default: `dcache_ahb_ctrl`):

```bash
# Simulates using Xsim (Vivado)
make sim TARGET=dcache_ahb_ctrl
```

To run simulation using Verilator:

```bash
make verilator TARGET=dcache_ahb_ctrl
```

### Build / Implementation

To build the project (synthesis) using Vivado:

```bash
make build TARGET=dcache_ahb_ctrl
```

To create and open a Vivado project for GUI interaction:

```bash
make project TARGET=dcache_ahb_ctrl
```

## Cores

### dcache_ahb_ctrl

A direct-mapped (implied by current parameters) data cache controller.

*   **RTL**: `cores/dcache_ahb_ctrl/hdl/dcache_ahb_ctrl.sv`
*   **Testbench**: `cores/dcache_ahb_ctrl/sim/dcache_ahb_ctrl_tb.sv` (Currently empty/under construction)

### pkg_dcache

Contains shared type definitions and macros for the cache system.
