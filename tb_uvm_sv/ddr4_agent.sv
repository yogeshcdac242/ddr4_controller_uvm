// UVM Agent for DDR4 Memory Controller
// Bundles Sequencer, Driver, and Monitor

typedef uvm_sequencer #(ddr4_seq_item) ddr4_sequencer;

class ddr4_agent extends uvm_agent;
    `uvm_component_utils(ddr4_agent)

    // Components
    ddr4_sequencer  sequencer;
    ddr4_driver     driver;
    ddr4_monitor    monitor;

    // Constructor
    function new(string name = "ddr4_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Always build the monitor
        monitor = ddr4_monitor::type_id::create("monitor", this);

        // Build sequencer and driver only if agent is active
        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = ddr4_sequencer::type_id::create("sequencer", this);
            driver    = ddr4_driver::type_id::create("driver", this);
        end
    endfunction

    // Connect Phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if (get_is_active() == UVM_ACTIVE) begin
            // Connect Driver to Sequencer
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass : ddr4_agent
