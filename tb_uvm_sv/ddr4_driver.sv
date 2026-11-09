// UVM Driver for DDR4 Memory Controller
// Connects to the Front-End C2MInterface to drive requests from UVM sequences

class ddr4_driver extends uvm_driver #(ddr4_seq_item);
    `uvm_component_utils(ddr4_driver)

    // Virtual Interface pointer
    virtual C2MInterface vif;

    // Constructor
    function new(string name = "ddr4_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase - get interface from config db
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual C2MInterface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV_NO_VIF", "Virtual interface C2MInterface not found in uvm_config_db")
        end
    endfunction

    // Run Phase
    virtual task run_phase(uvm_phase phase);
        // Reset signals
        vif.addr        <= 0;
        vif.data_tran   <= 0;
        vif.rw          <= 0;
        vif.valid_tran  <= 0;
        vif.ack_data    <= 1'b1; // Always ready to receive read data

        // Wait for reset to be deasserted
        @(negedge vif.reset);
        `uvm_info("DRV", "Reset released. Ready to drive traffic.", UVM_LOW)

        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    // Drives a single transaction onto the C2MInterface
    virtual task drive_transfer(ddr4_seq_item item);
        `uvm_info("DRV_DRIVE", $sformatf("Driving Item: %s", item.convert2string()), UVM_LOW)

        // Wait for clock edge
        @(posedge vif.clock);

        // If FIFO is full, wait until it clears
        while (vif.full) begin
            `uvm_info("DRV_STALL", "DUT FIFO is full, stalling driver...", UVM_DEBUG)
            @(posedge vif.clock);
        end

        // Drive signals
        vif.addr        <= item.addr;
        vif.data_tran   <= item.data;
        vif.rw          <= item.rw;
        vif.valid_tran  <= 1'b1;

        // Wait for acknowledgement from the controller
        // The controller should assert ack_tran when it accepts the transaction
        @(posedge vif.clock);
        while (!vif.ack_tran) begin
            @(posedge vif.clock);
        end

        // Hold signals for 1 extra clock cycle so the Scheduler can sample them safely
        @(posedge vif.clock);

        // Capture returned tag if needed (optional since monitor also does this)
        item.ack_tran = 1'b1;

        // Deassert valid_tran
        vif.valid_tran  <= 1'b0;
        vif.addr        <= 0;
        vif.data_tran   <= 0;
        vif.rw          <= 0;

        // Insert a small idle spacing if desired
        @(posedge vif.clock);
    endtask

endclass : ddr4_driver
