# High-Performance DDR4 Memory Controller: Design & Complete UVM 1.2 Verification Architecture

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![UVM](https://img.shields.io/badge/Methodology-UVM%201.2-orange.svg)](https://www.accellera.org/downloads/standards/uvm)
[![Protocol](https://img.shields.io/badge/Standard-JEDEC%20DDR4%20(JESD79--4)-brightgreen.svg)](https://www.jedec.org/)
[![Verification](https://img.shields.io/badge/Verification-Coverage%20Driven%20%26%20ABV-purple.svg)]()
[![Simulation](https://img.shields.io/badge/Simulator-Cadence%20Xcelium%20%2F%20QuestaSim%20%2F%20VCS-red.svg)]()

A production-grade **DDR4 Memory Controller ASIC** featuring an **Open-Page Policy**, **Out-of-Order Command Scheduling** (8-entry request queue), and an exhaustive **Universal Verification Methodology (UVM 1.2)** testbench with **Assertion-Based Verification (SVA)** and **Functional Coverage Closure**.

---

## 📌 Executive Summary

Modern multi-core processors demand memory sub-systems that achieve maximum bandwidth while adhering to rigorous JEDEC physical DRAM timing constraints. This repository provides:
1. **The Synthesizable RTL Design:** A high-throughput DDR4 Memory Controller managing 16 banks partitioned across 4 Bank Groups, capable of reordering requests to maximize Page Hits while maintaining low latency.
2. **The Complete UVM 1.2 Verification Environment:** An end-to-end simulation framework featuring an Active UVM Agent, an ID-tracked Golden Memory Scoreboard, JEDEC timing SVA protocol checkers, and cross-coverage closure.
3. **Behavioral DDR4 Memory BFM:** A slave responder model (`Memory.sv`) enabling full closed-loop write-and-readback simulation.

---

## 🏛️ System Architecture

```
  +-----------------------------------------------------------------------------------------------+
  |                                      VERIFICATION ENVIRONMENT                                 |
  |                                                                                               |
  |   +-----------------------+                         +-------------------------------------+   |
  |   |    UVM ACTIVE AGENT   |                         |            UVM SCOREBOARD           |   |
  |   |  - ddr4_seq (5 tests) |                         |  - Golden Associative Memory Model  |   |
  |   |  - ddr4_driver        |                         |    mem_model [logic [31:0]]         |   |
  |   |  - ddr4_monitor       |                         |  - Out-of-Order Tag Matcher         |   |
  |   +-----------+-----------+                         |  - Functional Coverage (c2m_cov_cg) |   |
  |               |                                     +------------------^------------------+   |
  |               | (512-bit Cache Line Handshake)                         |                      |
  |               v                                                        |                      |
  |        C2MInterface.sv                                            Analysis Ports              |
  |               |                                                  (req_ap, read_ap)            |
  +---------------|--------------------------------------------------------|----------------------+
                  |                                                        |
                  v                                                        |
  +------------------------------------------------------------------------|----------------------+
  |                                      DESIGN UNDER TEST (DUT)           |                      |
  |   +--------------------------------------------------------------------v------------------+   |
  |   |                                     MemoryController.sv                               |   |
  |   |                                                                                       |   |
  |   |   +---------------------+   +---------------------+   +---------------------------+   |   |
  |   |   |  receive_command.sv |-->|    Scheduler.sv     |-->|    Controller_FSM.sv      |   |   |
  |   |   |  (Request Receiver) |   |  (8-Entry Out-of-   |   |  (Bank FSM: ACT, RD, WR,  |   |   |
  |   |   +---------------------+   |   Order Scheduler)  |   |   PRE, REFRESH, Auto-Pre) |   |   |
  |   |                             +----------+----------+   +-------------+-------------+   |   |
  |   |                                        |                            |                 |   |
  |   |                                        v                            v                 |   |
  |   |                              CalcMax.sv (Priority)         Timer.sv / ShiftReg.sv     |   |   |
  |   |                                                                     |                 |   |
  |   |   +---------------------+                                           v                 |   |
  |   |   |  Read_data_comm.sv  |<----------------------------------  ReadWrite.sv            |   |   |
  |   |   |  (Host Return Unit) |                                    (DDR PHY DQS Modules)    |   |   |
  |   +---------------------------------------------------------------------+-----------------+   |
  +-------------------------------------------------------------------------|---------------------+
                                                                            |
                                                                     DDR4Interface.sv
                                                                   *JEDEC SVA Assertions*
                                                                            |
                                                                            v
                                                              +---------------------------+
                                                              |      Memory.sv (BFM)      |
                                                              |  (Behavioral DDR4 DRAM)   |
                                                              +---------------------------+
```

---

## ⚡ Key Architectural Highlights

### 1. 512-Bit Cache Line Architecture
The controller communicates with the host CPU cache across a 512-bit (64-byte) data bus (`C2MInterface.sv`). This matches standard modern CPU cache line boundaries, maximizing spatial locality and memory bandwidth.

### 2. Open-Page Policy & Out-of-Order Command Scheduling
DRAM accesses are categorized into three latency tiers:
- **Page Hit:** The requested row is already open in the sense amplifiers $\rightarrow$ Immediate `READ`/`WRITE` (Zero cycle penalty).
- **Page Empty:** The bank is idle $\rightarrow$ `ACTIVATE` $\rightarrow$ `READ`/`WRITE`.
- **Page Miss (Conflict):** A different row is active $\rightarrow$ `PRECHARGE` (wait $t_{RP}$) $\rightarrow$ `ACTIVATE` (wait $t_{RCD}$) $\rightarrow$ `READ`/`WRITE`.

The hardware scheduler (`Scheduler.sv`) inspects all requests in its 8-entry queue and prioritizes **Page Hits** ahead of older Page Conflicts, significantly reducing average latency.

### 3. DDR4 Bank Group Partitioning
Supports 16 banks split across 4 Bank Groups (`BG0` - `BG3`), exploiting DDR4-specific timing rules:
- **$t_{CCD\_S} = 4$ clock cycles:** Column-to-column delay when switching across **different Bank Groups** (Fast).
- **$t_{CCD\_L} = 6$ clock cycles:** Column-to-column delay when accessing the **same Bank Group** (Slower).

---

## 🧪 Comprehensive UVM 1.2 Verification Architecture

The testbench is located in [`tb_uvm_sv/`](tb_uvm_sv/) and follows strict Accellera UVM standards:

### 1. Out-of-Order Scoreboard with Golden Memory Model (`ddr4_scoreboard.sv`)
- **Golden Reference:** Maintains an associative array `logic [511:0] mem_model [logic [31:0]]` mapping 32-bit addresses to 512-bit cache lines.
- **Dynamic Tag Matching:** Tracks in-flight requests using an associative table `outstanding_reads [tag] = addr`. When read data returns out-of-order, the scoreboard retrieves the exact address using the returned 3-bit tag and verifies data integrity.
- **Dual Stream Handling:** Uses `` `uvm_analysis_imp_decl(_req) `` and `` `uvm_analysis_imp_decl(_read) `` to handle multiple analysis ports without callback name collisions.

### 2. Assertion-Based Verification (SVA in `DDR4Interface.sv`)
Physical pin transitions are monitored by concurrent assertions:
- **$t_{RCD}$ Check (`Act_RW`):** Verifies that after `act_n` falls (Activate), column command signals (`CAS`) are delayed by at least `TRCD` cycles (16 clock cycles):
  ```systemverilog
  property Act_RW;
      @(posedge clock)
      ((cs_n === LOW) && (cke === `HIGH) && $fell(act_n)) |-> ##TRCD ($fell(`CAS) || $rose(act_n));
  endproperty
  assert property(Act_RW) else $warning("TRCD Violation");
  ```
- **$t_{CL}$ CAS Latency Check (`RW_to_Data`):** Verifies that exactly `TCL` clock cycles following a `READ` command, valid data appears on `pin_dq` (`!$isunknown(pin_dq)`).

### 3. Functional Coverage Model (`c2m_cov_cg`)
Embedded inside the scoreboard to measure verification completeness:
- **`OP_TYPE`:** Coverage of both `READ` (0) and `WRITE` (1) operations.
- **`BANK_GROUP`:** Accesses across all 4 Bank Groups (`BG0` to `BG3`, address bits `[7:6]`).
- **`BANK`:** Accesses across all 4 Banks (`B0` to `B3`, address bits `[16:15]`).
- **Cross Coverage:** `OP_x_BG` and `OP_x_B` ensuring read and write traffic are exhaustively exercised across all 16 banks.

---

## 📁 Repository Structure

```text
ddr4_controller_uvm/
├── C2MInterface.sv            # Host CPU-to-Controller interface (512-bit cache lines)
├── DDR4Interface.sv           # DRAM physical interface + SVA timing assertions
├── Definitions.pkg            # System parameters, timing constants, bus widths
├── MemoryController.sv        # Top-level DUT wrapper
├── Controller_FSM.sv          # Bank FSM (ACT, RD, WR, PRE, Auto-Precharge)
├── Scheduler.sv               # 8-entry request buffer & out-of-order scheduler
├── CalcMax.sv                 # Priority arbitration logic for scheduler
├── ReadWrite.sv               # Double Data Rate (DDR) PHY modules with DQS strobes
├── ShiftReg.sv                # CAS latency tracking shift registers
├── Timer.sv                   # Countdown timers for tRCD, tRP, tCL, tCCD
├── Read_data_comm.sv          # Read data return communication module
├── Receive_command.sv         # Request receiver module
├── Memory.sv                  # Behavioral DDR4 Memory BFM (slave responder)
├── tb_uvm_sv/                 # UVM 1.2 Verification Environment
│   ├── ddr4_pkg.sv            # Testbench package importing UVM and components
│   ├── ddr4_seq_item.sv       # 512-bit cache line sequence item with 3-bit tag
│   ├── ddr4_seq.sv            # Constrained random sequence library (5 scenarios)
│   ├── ddr4_driver.sv         # UVM Driver with backpressure (full) flow control
│   ├── ddr4_monitor.sv        # Passive 3-thread monitor (C2M reqs, reads, DDR4 cmds)
│   ├── ddr4_agent.sv          # UVM Agent (Driver, Monitor, Sequencer)
│   ├── ddr4_scoreboard.sv     # Golden memory array, tag matching, functional coverage
│   ├── ddr4_env.sv            # UVM Environment wiring analysis ports
│   ├── ddr4_test.sv           # Test suite (Init, WriteRead, Refresh, Random, Stress)
│   ├── tb_top.sv              # Testbench top instantiating DUT, BFM, interfaces
│   └── Makefile               # Cadence Xcelium automation makefile
└── README.md                  # Comprehensive documentation
```

---

## 🚀 Test Suite & Verification Scenarios

| Test Case | Sequence Class | Purpose & Scenario Tested |
| :--- | :--- | :--- |
| **`ddr4_init_test`** | Base | Verifies clean power-on sequence and reset deassertion. |
| **`ddr4_write_read_test`** | `ddr4_write_read_seq` | Writes to 10 random memory locations and reads them back to verify basic data integrity. |
| **`ddr4_refresh_test`** | `ddr4_write_read_seq` | Injects traffic, forces delay to trigger auto-refresh cycles, and verifies data persistence. |
| **`ddr4_random_traffic_test`** | `ddr4_random_traffic_seq` | High-volume constrained random stimulus generating mixed Page Hits and Page Misses. |
| **`ddr4_stress_test`** | `ddr4_stress_seq` | Saturates the 8-entry request queue to test backpressure (`full`) handling. |

---

## 🛠️ How to Compile & Simulate

### Using Cadence Xcelium:
```bash
cd tb_uvm_sv

# Run default regression test (ddr4_write_read_test)
make run_write_read

# Run with full code & functional coverage collection
make run_random_traffic COV=1

# Run full regression suite
make all
```

### Using Synopsys VCS:
```bash
cd tb_uvm_sv
vcs -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    +incdir+.. +incdir+. \
    ../C2MInterface.sv ../DDR4Interface.sv ../Definitions.pkg \
    ../Memory.sv ../Timer.sv ../ShiftReg.sv ../CalcMax.sv \
    ../ReadWrite.sv ../Receive_command.sv ../Read_data_comm.sv \
    ../Controller_FSM.sv ../Scheduler.sv ../MemoryController.sv \
    ddr4_pkg.sv tb_top.sv -R +UVM_TESTNAME=ddr4_write_read_test
```

---

## 📊 Verification Proof & Simulation Logs

### 1. Lockstep Scoreboard Data Match Log:
```text
UVM_INFO ddr4_driver.sv(46) @ 105000: uvm_test_top.env.agent.driver [DRV_DRIVE] Driving Item: Tag: 2 | OP: WRITE | Addr: 32'h00000040 | Data: 512'ha5a5a5a5...5a5a5a5a
UVM_INFO ddr4_monitor.sv(58) @ 125000: uvm_test_top.env.agent.monitor [MON_C2M_REQ] Observed C2M Request: Tag: 2 | OP: WRITE | Addr: 32'h00000040
UVM_INFO ddr4_driver.sv(46) @ 135000: uvm_test_top.env.agent.driver [DRV_DRIVE] Driving Item: Tag: 5 | OP: READ  | Addr: 32'h00000040 | Data: 512'h00000000...00000000
UVM_INFO ddr4_monitor.sv(72) @ 295000: uvm_test_top.env.agent.monitor [MON_C2M_READ] Observed C2M Read Data Return: Tag=5, Data=512'ha5a5a5a5...5a5a5a5a
UVM_INFO ddr4_scoreboard.sv(75) @ 295000: uvm_test_top.env.scoreboard [SCB_MATCH] 512-bit Data matched perfectly for Tag=5 at Addr=32'h00000040!
```

### 2. Final Scoreboard Report:
```text
-----------------------------------------------------------------
[SCB_REPORT] ==================== SCOREBOARD REPORT ====================
[SCB_REPORT] Total Writes Recorded:  50
[SCB_REPORT] Total Reads Processed:  50
[SCB_REPORT] Total Data Matches:     50
[SCB_REPORT] Total Data Mismatches:  0
[SCB_REPORT] Outstanding Reads Left: 0
[SCB_REPORT] STATUS: TEST PASSED (ZERO DATA CORRUPTION)
-----------------------------------------------------------------
```

### 3. JEDEC Protocol Assertion Status:
```text
Assertion Report:
- Act_RW (tRCD check):       PASSED (0 Violations)
- RW_to_Data (tCL check):    PASSED (0 Violations)
```

---

## 👥 Authors & Credits

- **Verification Engineering & Testbench Architecture:** **[Yogeshwar Dayal](https://github.com/yogeshcdac242)**
  - Architected and implemented the complete UVM 1.2 verification framework (`tb_uvm_sv/`: driver, monitor, scoreboard, sequences, agent, environment, tests).
  - Developed pin-level JEDEC DDR4 protocol and timing SystemVerilog Assertions (SVA) in `DDR4Interface.sv` for $t_{RCD}$ and $t_{CL}$ timing closure.
  - Implemented the golden associative memory model, out-of-order transaction tag tracking, and functional cross-coverage (`c2m_cov_cg`).
  - Authored comprehensive verification architecture documentation and test plans.

- **Original Synthesizable RTL Design:** **Ananth Bhat** ([@ananthbhat94](https://github.com/ananthbhat94))
  - Sourced and referenced the base synthesizable DDR4 Memory Controller RTL modules (`MemoryController.sv`, `Scheduler.sv`, `Controller_FSM.sv`, `ReadWrite.sv`, `Receive_command.sv`, `Send_command.sv`, `ShiftReg.sv`, `Timer.sv`, `CalcMax.sv`).
  - Sincere gratitude and full credit are extended to the original RTL designer for providing the synthesizable memory controller core used as the Design Under Test (DUT) for this verification environment.

---

## 📜 License
This project is open-source under the MIT License. See [LICENSE.txt](LICENSE.txt) for details.
