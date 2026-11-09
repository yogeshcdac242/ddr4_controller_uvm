// Top-Level Testbench Module for DDR4 Memory Controller UVM Simulation
`timescale 1ns / 1ps

import uvm_pkg::*;
import ddr4_pkg::*;

module tb_top;

    // Clock and Reset Signals
    logic clock;
    logic clock2x;
    logic reset;

    // Clock Generation
    // 100 MHz clock (10ns period)
    initial begin
        clock = 1'b0;
        forever #5ns clock = ~clock;
    end

    // 200 MHz clock (5ns period)
    initial begin
        clock2x = 1'b0;
        forever #2.5ns clock2x = ~clock2x;
    end

    // Reset Generation
    initial begin
        reset = 1'b1;
        #100ns;
        @(negedge clock);
        reset = 1'b0;
    end

    // Instantiate Interfaces
    C2MInterface  c2m_if  (.clock(clock), .reset(reset));
    DDR4Interface ddr4_if (.clock(clock), .reset(reset));

    // Instantiate DDR4 Memory Model (BFM)
    // Responds to DDR4 commands driven by the memory controller
    Memory memory_model_inst (
        .Bus(ddr4_if.Memory),
        .clock2x(clock2x)
    );

    // Instantiate Memory Controller (DUT)
    MemoryController dut (
        .reset(reset),
        .clock(clock),
        .clock2x(clock2x),
        .DDR4Bus(ddr4_if.Controller),
        .MCTx(c2m_if.Mem_data),
        .MCRx(c2m_if.Mem_tran)
    );

    // Register Interfaces and Run UVM Test
    initial begin
        // Set virtual interfaces in config db
        uvm_config_db#(virtual C2MInterface)::set(null, "*", "vif", c2m_if);
        uvm_config_db#(virtual C2MInterface)::set(null, "*", "vif_c2m", c2m_if);
        uvm_config_db#(virtual DDR4Interface)::set(null, "*", "vif_ddr4", ddr4_if);

        // Run the UVM Test
        run_test();
    end

    // Waveform Dump Setup
    initial begin
        if ($test$plusargs("WAVE")) begin
            $shm_open("waves.shm");
            $shm_probe("as");
        end
    end

endmodule : tb_top
