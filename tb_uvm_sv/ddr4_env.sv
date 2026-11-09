// UVM Environment for DDR4 Memory Controller
// Instantiates and connects the Agent and the Scoreboard

class ddr4_env extends uvm_env;
    `uvm_component_utils(ddr4_env)

    // Components
    ddr4_agent      agent;
    ddr4_scoreboard scoreboard;

    // Constructor
    function new(string name = "ddr4_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = ddr4_agent::type_id::create("agent", this);
        scoreboard = ddr4_scoreboard::type_id::create("scoreboard", this);
    endfunction

    // Connect Phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect Monitor's request analysis port to Scoreboard's request imp
        agent.monitor.req_ap.connect(scoreboard.req_imp);
        
        // Connect Monitor's read data analysis port to Scoreboard's read imp
        agent.monitor.read_ap.connect(scoreboard.read_imp);
    endfunction

endclass : ddr4_env
