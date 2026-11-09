// UVM Scoreboard for DDR4 Memory Controller
// Implements an associative memory array (Golden Model) and collects Functional Coverage

`uvm_analysis_imp_decl(_req)
`uvm_analysis_imp_decl(_read)

class ddr4_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ddr4_scoreboard)

    // Analysis Imps
    uvm_analysis_imp_req  #(ddr4_seq_item, ddr4_scoreboard) req_imp;
    uvm_analysis_imp_read #(ddr4_seq_item, ddr4_scoreboard) read_imp;

    // Golden Memory Model (Associative array)
    // Key: 32-bit Address, Value: 512-bit Data
    logic [511:0] mem_model [logic [31:0]];

    // Outstanding Read Queue mapping Tag -> Address
    logic [31:0] outstanding_reads [logic [2:0]];

    // Stats
    int writes_count = 0;
    int reads_count = 0;
    int match_count = 0;
    int mismatch_count = 0;

    // Covergroup to capture functional coverage of cache transactions
    covergroup c2m_cov_cg;
        option.per_instance = 1;
        option.name = "c2m_transaction_coverage";

        // Cover the operation type
        OP_TYPE: coverpoint cov_item.rw {
            bins READ = {1'b0};
            bins WRITE = {1'b1};
        }

        // Cover the targeted Bank Group (Address bits [7:6])
        BANK_GROUP: coverpoint cov_item.addr[7:6] {
            bins BG0 = {2'b00};
            bins BG1 = {2'b01};
            bins BG2 = {2'b10};
            bins BG3 = {2'b11};
        }

        // Cover the targeted Bank (Address bits [16:15])
        BANK: coverpoint cov_item.addr[16:15] {
            bins B0 = {2'b00};
            bins B1 = {2'b01};
            bins B2 = {2'b10};
            bins B3 = {2'b11};
        }

        // Cross of Op Type and Bank Group
        OP_x_BG: cross OP_TYPE, BANK_GROUP;

        // Cross of Op Type and Bank
        OP_x_B: cross OP_TYPE, BANK;

    endgroup

    // Temporary item for covergroup sampling
    ddr4_seq_item cov_item;

    // Constructor
    function new(string name = "ddr4_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        req_imp = new("req_imp", this);
        read_imp = new("read_imp", this);
        c2m_cov_cg = new();
    endfunction

    // Process observed Cache requests (Writes & Reads)
    virtual function void write_req(ddr4_seq_item item);
        cov_item = item;
        c2m_cov_cg.sample(); // Sample functional coverage

        if (item.rw == 1'b1) begin
            // WRITE Transaction
            mem_model[item.addr] = item.data;
            writes_count++;
            `uvm_info("SCB_WRITE", $sformatf("Golden Model Update: Addr=32'h%08h | Data=512'h%016h...", 
                                             item.addr, item.data[31:0]), UVM_HIGH)
        end else begin
            // READ Transaction
            outstanding_reads[item.tag] = item.addr;
            reads_count++;
            `uvm_info("SCB_READ_REQ", $sformatf("Read Registered: Tag=%0d -> Expecting Addr=32'h%08h", 
                                                item.tag, item.addr), UVM_HIGH)
        end
    endfunction

    // Process returned Read Data
    virtual function void write_read(ddr4_seq_item item);
        logic [31:0]  expected_addr;
        logic [511:0] expected_data;

        // Check if this tag exists in outstanding reads
        if (outstanding_reads.exists(item.read_tag)) begin
            expected_addr = outstanding_reads[item.read_tag];
            
            // Check if address was written previously
            if (mem_model.exists(expected_addr)) begin
                expected_data = mem_model[expected_addr];
            end else begin
                expected_data = '0; // Default if read before write
            end

            // Compare data
            if (item.read_data === expected_data) begin
                `uvm_info("SCB_MATCH", $sformatf("DATA MATCH! Addr=32'h%08h | Tag=%0d | Data=512'h%016h...", 
                                                 expected_addr, item.read_tag, item.read_data[31:0]), UVM_LOW)
                match_count++;
            end else begin
                `uvm_error("SCB_MISMATCH", $sformatf("DATA MISMATCH! Addr=32'h%08h | Tag=%0d\nExpected: 512'h%0h\nObserved: 512'h%0h", 
                                                      expected_addr, item.read_tag, expected_data, item.read_data))
                mismatch_count++;
            end

            // Clear outstanding read entry
            outstanding_reads.delete(item.read_tag);
        end else begin
            // Tag wasn't registered
            `uvm_warning("SCB_UNEXPECTED_TAG", $sformatf("Observed Read Data with Tag=%0d, but no matching outstanding read request exists!", 
                                                         item.read_tag))
        end
    endfunction

    // Report Phase - summarize scoreboarding results
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB_REPORT", "--------------------------------------------------", UVM_LOW)
        `uvm_info("SCB_REPORT", "             DDR4 SCOREBOARD SUMMARY              ", UVM_LOW)
        `uvm_info("SCB_REPORT", "--------------------------------------------------", UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("  Total Writes Processed:     %0d", writes_count), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("  Total Reads Processed:      %0d", reads_count), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("  Total Matches:              %0d", match_count), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("  Total Mismatches:           %0d", mismatch_count), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("  Pending Reads Remaining:    %0d", outstanding_reads.size()), UVM_LOW)
        `uvm_info("SCB_REPORT", "--------------------------------------------------", UVM_LOW)

        if (mismatch_count > 0) begin
            `uvm_fatal("SCB_FAIL", "Verification failed due to data mismatches!")
        end
    endfunction

endclass : ddr4_scoreboard
