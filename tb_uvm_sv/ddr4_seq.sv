// UVM Sequences for DDR4 Memory Controller Verification

//---------------------------------------------------------
// Base DDR4 Sequence
//---------------------------------------------------------
class ddr4_base_seq extends uvm_sequence #(ddr4_seq_item);
    `uvm_object_utils(ddr4_base_seq)

    function new(string name = "ddr4_base_seq");
        super.new(name);
    endfunction
endclass : ddr4_base_seq


//---------------------------------------------------------
// Write-then-Read Sequence
// Writes a set of locations, then reads them back to verify data integrity
//---------------------------------------------------------
class ddr4_write_read_seq extends ddr4_base_seq;
    `uvm_object_utils(ddr4_write_read_seq)

    int num_loops = 10;

    function new(string name = "ddr4_write_read_seq");
        super.new(name);
    endfunction

    virtual task body();
        ddr4_seq_item write_item;
        ddr4_seq_item read_item;

        `uvm_info("SEQ", $sformatf("Starting Sequential Write-Read Sequence with %0d iterations", num_loops), UVM_LOW)

        for (int i = 0; i < num_loops; i++) begin
            // 1. Send WRITE command
            write_item = ddr4_seq_item::type_id::create($sformatf("write_item_%0d", i));
            
            start_item(write_item);
            if (!write_item.randomize() with {
                rw == 1'b1;              // Force Write
                addr[5:0] == 6'b0;      // Align to 64-byte burst boundaries (512 bits)
                addr[31:20] == 12'b0;   // Keep within memory bounds
            }) begin
                `uvm_fatal("SEQ_RAND_FAIL", "Randomization failed for Write item")
            end
            
            `uvm_info("SEQ_TX_WRITE", $sformatf("Sending Write request [%0d]: Addr=32'h%08h", i, write_item.addr), UVM_MEDIUM)
            finish_item(write_item);
            
            // Wait for the FSM to process the write and update the memory model
            #1500ns;

            // 2. Send READ command to the same address
            read_item = ddr4_seq_item::type_id::create($sformatf("read_item_%0d", i));
            
            start_item(read_item);
            if (!read_item.randomize() with {
                rw == 1'b0;                      // Force Read
                addr == write_item.addr;        // Match written address
            }) begin
                `uvm_fatal("SEQ_RAND_FAIL", "Randomization failed for Read item")
            end
            
            `uvm_info("SEQ_TX_READ", $sformatf("Sending Read request [%0d]: Addr=32'h%08h", i, read_item.addr), UVM_MEDIUM)
            finish_item(read_item);
            
            // Wait for the read data to return to the BFM
            #1500ns;
        end
    endtask
endclass : ddr4_write_read_seq


//---------------------------------------------------------
// Bank Interleaving Sequence
// Stress-tests the Scheduler's out-of-order page policy by targetting different Banks and Bank Groups
//---------------------------------------------------------
class ddr4_bank_interleave_seq extends ddr4_base_seq;
    `uvm_object_utils(ddr4_bank_interleave_seq)

    function new(string name = "ddr4_bank_interleave_seq");
        super.new(name);
    endfunction

    virtual task body();
        ddr4_seq_item item;
        logic [31:0] test_addrs[8];
        
        `uvm_info("SEQ_INTERLEAVE", "Starting Bank Interleaving traffic pattern...", UVM_LOW)

        // Pre-calculate addresses targetting different bank groups and banks
        // Address structure:
        // [31:17] Row | [16:15] Bank | [14:8] Column | [7:6] BankGroup | [5:0] Offset
        for (int bg = 0; bg < 4; bg++) begin
            for (int b = 0; b < 2; b++) begin
                test_addrs[bg*2 + b] = {15'h1234, b[1:0], 7'h0A, bg[1:0], 6'b0};
            end
        end

        // 1. Write to all banks
        for (int i = 0; i < 8; i++) begin
            item = ddr4_seq_item::type_id::create($sformatf("interleave_write_%0d", i));
            start_item(item);
            if (!item.randomize()) begin
                `uvm_fatal("SEQ_RAND_FAIL", "Randomization failed for Interleave Write item")
            end
            item.addr = test_addrs[i];
            item.rw = 1'b1; // Write
            finish_item(item);
            #20ns;
        end

        #100ns;

        // 2. Read from all banks
        for (int i = 0; i < 8; i++) begin
            item = ddr4_seq_item::type_id::create($sformatf("interleave_read_%0d", i));
            start_item(item);
            item.addr = test_addrs[i];
            item.rw = 1'b0; // Read
            finish_item(item);
            #20ns;
        end

        #4000ns;
    endtask
endclass : ddr4_bank_interleave_seq


//---------------------------------------------------------
// Random Traffic Sequence
// Generates random mix of Reads and Writes across random addresses
//---------------------------------------------------------
class ddr4_random_traffic_seq extends ddr4_base_seq;
    `uvm_object_utils(ddr4_random_traffic_seq)

    int num_items = 50;

    function new(string name = "ddr4_random_traffic_seq");
        super.new(name);
    endfunction

    virtual task body();
        ddr4_seq_item item;
        
        `uvm_info("SEQ_RANDOM", $sformatf("Starting Random Traffic Sequence with %0d items", num_items), UVM_LOW)

        for (int i = 0; i < num_items; i++) begin
            item = ddr4_seq_item::type_id::create($sformatf("random_item_%0d", i));
            start_item(item);
            if (!item.randomize() with {
                addr[5:0] == 6'b0; // Align to 64-byte burst boundaries
            }) begin
                `uvm_fatal("SEQ_RAND_FAIL", "Randomization failed")
            end
            finish_item(item);
            #($urandom_range(10, 100) * 1ns);
        end

        // Wait for all outstanding transactions to complete
        #5000ns;
    endtask
endclass : ddr4_random_traffic_seq


//---------------------------------------------------------
// Stress Sequence
// Floods the controller with 0-delay requests
//---------------------------------------------------------
class ddr4_stress_seq extends ddr4_base_seq;
    `uvm_object_utils(ddr4_stress_seq)

    int num_items = 30;

    function new(string name = "ddr4_stress_seq");
        super.new(name);
    endfunction

    virtual task body();
        ddr4_seq_item item;
        
        `uvm_info("SEQ_STRESS", $sformatf("Starting Stress Sequence with %0d items (0-delay)", num_items), UVM_LOW)

        for (int i = 0; i < num_items; i++) begin
            item = ddr4_seq_item::type_id::create($sformatf("stress_item_%0d", i));
            start_item(item);
            if (!item.randomize() with {
                addr[5:0] == 6'b0; // Align to 64-byte burst boundaries
            }) begin
                `uvm_fatal("SEQ_RAND_FAIL", "Randomization failed")
            end
            finish_item(item);
            // 0 delay! The scheduler's full flag will push back if needed via the driver/interface
        end

        // Wait for all outstanding transactions to complete
        #8000ns;
    endtask
endclass : ddr4_stress_seq
