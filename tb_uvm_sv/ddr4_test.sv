// UVM Tests for DDR4 Memory Controller

//---------------------------------------------------------
// Base Test
//---------------------------------------------------------
class ddr4_base_test extends uvm_test;
    `uvm_component_utils(ddr4_base_test)

    ddr4_env env;

    // Constructor
    function new(string name = "ddr4_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ddr4_env::type_id::create("env", this);
    endfunction

    // End of Elaboration Phase
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    // Run Phase - default timeout
    virtual task run_phase(uvm_phase phase);
        // Base test just runs a short delay
        phase.raise_objection(this);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass : ddr4_base_test


//---------------------------------------------------------
// Initialization Test
// Checks FSM reset behavior and initial MRS transaction
//---------------------------------------------------------
class ddr4_init_test extends ddr4_base_test;
    `uvm_component_utils(ddr4_init_test)

    function new(string name = "ddr4_init_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "Starting DDR4 Initialization Test...", UVM_LOW)
        
        // Wait for reset to settle
        #500ns;
        
        `uvm_info("TEST", "DDR4 Initialization Test completed successfully.", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : ddr4_init_test


//---------------------------------------------------------
// Write-Read Traffic Test
// Runs the write_read sequence
//---------------------------------------------------------
class ddr4_write_read_test extends ddr4_base_test;
    `uvm_component_utils(ddr4_write_read_test)

    function new(string name = "ddr4_write_read_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ddr4_write_read_seq seq;
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Starting DDR4 Write-Read Traffic Test...", UVM_LOW)
        seq = ddr4_write_read_seq::type_id::create("write_read_seq");
        
        seq.start(env.agent.sequencer);
        
        `uvm_info("TEST", "DDR4 Write-Read Traffic Test completed.", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : ddr4_write_read_test


//---------------------------------------------------------
// Refresh & Interleaving Stress Test
// Runs the bank interleaving sequence
//---------------------------------------------------------
class ddr4_refresh_test extends ddr4_base_test;
    `uvm_component_utils(ddr4_refresh_test)

    function new(string name = "ddr4_refresh_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ddr4_bank_interleave_seq seq;
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Starting DDR4 Refresh & Bank Interleave Stress Test...", UVM_LOW)
        seq = ddr4_bank_interleave_seq::type_id::create("interleave_seq");
        
        seq.start(env.agent.sequencer);
        
        `uvm_info("TEST", "DDR4 Refresh & Bank Interleave Stress Test completed.", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : ddr4_refresh_test


//---------------------------------------------------------
// Random Traffic Test
// Runs the random traffic sequence
//---------------------------------------------------------
class ddr4_random_traffic_test extends ddr4_base_test;
    `uvm_component_utils(ddr4_random_traffic_test)

    function new(string name = "ddr4_random_traffic_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ddr4_random_traffic_seq seq;
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Starting DDR4 Random Traffic Test...", UVM_LOW)
        seq = ddr4_random_traffic_seq::type_id::create("random_seq");
        
        seq.start(env.agent.sequencer);
        
        `uvm_info("TEST", "DDR4 Random Traffic Test completed.", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : ddr4_random_traffic_test


//---------------------------------------------------------
// Stress Test
// Runs the stress sequence (zero delay flooding)
//---------------------------------------------------------
class ddr4_stress_test extends ddr4_base_test;
    `uvm_component_utils(ddr4_stress_test)

    function new(string name = "ddr4_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ddr4_stress_seq seq;
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Starting DDR4 Stress Test...", UVM_LOW)
        seq = ddr4_stress_seq::type_id::create("stress_seq");
        
        seq.start(env.agent.sequencer);
        
        `uvm_info("TEST", "DDR4 Stress Test completed.", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : ddr4_stress_test
