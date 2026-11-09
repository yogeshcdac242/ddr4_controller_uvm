// Package compiling all DDR4 Memory Controller UVM classes

`timescale 1ns/1ps
package ddr4_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Package-scope parameters matching Definitions.pkg
    parameter TRP = 16;
    parameter TRCD = 16;
    parameter TCL = 16;
    parameter TCCD_L = 6;
    parameter TCCD_S = 4;
    parameter CWIDTH = 10;
    parameter RWIDTH = 15;
    parameter BWIDTH = 2;
    parameter BGWIDTH = 2;
    parameter TWIDTH = 3;
    parameter DATAWIDTH = 512;
    parameter ADDRESSWIDTH = 32;
    parameter AWIDTH = 18;
    parameter DWIDTH = 64;
    parameter BANKGROUP = 4;
    parameter BANKS = 4;
    parameter B_BITS = 2;
    parameter BG_BITS = 2;

    // Include sequence item first
    `include "ddr4_seq_item.sv"

    // Include driver and monitor
    `include "ddr4_driver.sv"
    `include "ddr4_monitor.sv"

    // Include scoreboard
    `include "ddr4_scoreboard.sv"

    // Include agent and environment
    `include "ddr4_agent.sv"
    `include "ddr4_env.sv"

    // Include sequences and test definitions
    `include "ddr4_seq.sv"
    `include "ddr4_test.sv"

endpackage : ddr4_pkg
