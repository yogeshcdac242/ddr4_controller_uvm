// UVM Monitor for DDR4 Memory Controller
// Observes Front-End transactions (C2MInterface) and Back-End physical pin commands (DDR4Interface)

class ddr4_monitor extends uvm_monitor;
    `uvm_component_utils(ddr4_monitor)

    // Virtual Interfaces
    virtual C2MInterface vif_c2m;
    virtual DDR4Interface vif_ddr4;

    // Analysis Ports
    uvm_analysis_port #(ddr4_seq_item) req_ap;      // Cache commands accepted by controller
    uvm_analysis_port #(ddr4_seq_item) read_ap;     // Read data returns to cache
    uvm_analysis_port #(string)        phy_cmd_ap;  // Physical DDR4 commands executed

    // Constructor
    function new(string name = "ddr4_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        req_ap = new("req_ap", this);
        read_ap = new("read_ap", this);
        phy_cmd_ap = new("phy_cmd_ap", this);

        if (!uvm_config_db#(virtual C2MInterface)::get(this, "", "vif_c2m", vif_c2m)) begin
            `uvm_fatal("MON_NO_C2M", "Virtual C2MInterface not found in uvm_config_db")
        end
        if (!uvm_config_db#(virtual DDR4Interface)::get(this, "", "vif_ddr4", vif_ddr4)) begin
            `uvm_fatal("MON_NO_DDR4", "Virtual DDR4Interface not found in uvm_config_db")
        end
    endfunction

    // Run Phase - runs parallel monitoring processes
    virtual task run_phase(uvm_phase phase);
        fork
            monitor_c2m_requests();
            monitor_c2m_reads();
            monitor_ddr4_commands();
        join
    endtask

    // Monitor Front-End Cache Requests (Write & Read commands)
    virtual task monitor_c2m_requests();
        forever begin
            @(posedge vif_c2m.clock);
            // Request is accepted when valid_tran and ack_tran are both high
            if (vif_c2m.valid_tran && vif_c2m.ack_tran) begin
                ddr4_seq_item item = ddr4_seq_item::type_id::create("c2m_req_item");
                item.addr = vif_c2m.addr;
                item.data = vif_c2m.data_tran;
                item.rw   = vif_c2m.rw;
                item.tag  = vif_c2m.tag_tran;
                
                `uvm_info("MON_C2M_REQ", $sformatf("Observed C2M Request: %s", item.convert2string()), UVM_MEDIUM)
                req_ap.write(item);
            end
        end
    endtask

    // Monitor Front-End Read Data Returns
    virtual task monitor_c2m_reads();
        forever begin
            @(posedge vif_c2m.clock);
            if (vif_c2m.valid_data) begin
                ddr4_seq_item item = ddr4_seq_item::type_id::create("c2m_read_item");
                item.read_data  = vif_c2m.read_data;
                item.read_tag   = vif_c2m.tag_data;
                item.read_valid = 1'b1;

                `uvm_info("MON_C2M_READ", $sformatf("Observed C2M Read Data Return: Tag=%0d, Data=512'h%016h...%016h", 
                                                    item.read_tag, item.read_data[511:480], item.read_data[31:0]), UVM_MEDIUM)
                read_ap.write(item);
            end
        end
    endtask

    // Monitor Back-End DDR4 Command Interface (Physical commands)
    virtual task monitor_ddr4_commands();
        forever begin
            @(posedge vif_ddr4.clock);
            if (!vif_ddr4.reset) begin
                // Check commands based on the helper functions defined inside DDR4Interface.sv
                if (vif_ddr4.IsActivate()) begin
                    `uvm_info("MON_DDR4_CMD", $sformatf("DDR4 Pin Command: ACTIVATE (BG=%0d, Bank=%0d, Row=15'h%04h)", 
                                                        vif_ddr4.bg, vif_ddr4.b, vif_ddr4.pin_A[14:0]), UVM_MEDIUM)
                    phy_cmd_ap.write("ACT");
                end
                else if (vif_ddr4.IsRefresh()) begin
                    `uvm_info("MON_DDR4_CMD", "DDR4 Pin Command: AUTO-REFRESH", UVM_MEDIUM)
                    phy_cmd_ap.write("REF");
                end
                else if (vif_ddr4.IsWrite()) begin
                    `uvm_info("MON_DDR4_CMD", $sformatf("DDR4 Pin Command: WRITE (BG=%0d, Bank=%0d, Col=10'h%03h)", 
                                                        vif_ddr4.bg, vif_ddr4.b, vif_ddr4.pin_A[9:0]), UVM_MEDIUM)
                    phy_cmd_ap.write("WR");
                end
                else if (vif_ddr4.IsRead()) begin
                    `uvm_info("MON_DDR4_CMD", $sformatf("DDR4 Pin Command: READ (BG=%0d, Bank=%0d, Col=10'h%03h)", 
                                                        vif_ddr4.bg, vif_ddr4.b, vif_ddr4.pin_A[9:0]), UVM_MEDIUM)
                    phy_cmd_ap.write("RD");
                end
                else if (vif_ddr4.IsWriteA()) begin
                    `uvm_info("MON_DDR4_CMD", $sformatf("DDR4 Pin Command: WRITE WITH AUTO-PRECHARGE (BG=%0d, Bank=%0d)", 
                                                        vif_ddr4.bg, vif_ddr4.b), UVM_MEDIUM)
                    phy_cmd_ap.write("WRA");
                end
                else if (vif_ddr4.IsReadA()) begin
                    `uvm_info("MON_DDR4_CMD", $sformatf("DDR4 Pin Command: READ WITH AUTO-PRECHARGE (BG=%0d, Bank=%0d)", 
                                                        vif_ddr4.bg, vif_ddr4.b), UVM_MEDIUM)
                    phy_cmd_ap.write("RDA");
                end
                else if (vif_ddr4.IsPrePreA()) begin
                    `uvm_info("MON_DDR4_CMD", $sformatf("DDR4 Pin Command: PRECHARGE (BG=%0d, Bank=%0d)", 
                                                        vif_ddr4.bg, vif_ddr4.b), UVM_MEDIUM)
                    phy_cmd_ap.write("PRE");
                end
            end
        end
    endtask

endclass : ddr4_monitor
