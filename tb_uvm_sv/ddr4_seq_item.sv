// UVM Sequence Item for DDR4 Memory Controller
// Defines transactions sent from the Cache/TB to the Memory Controller

class ddr4_seq_item extends uvm_sequence_item;
    // Transaction fields
    rand bit [31:0]  addr;
    rand bit [511:0] data;
    rand bit         rw;    // 0 = Read, 1 = Write
    rand bit [2:0]   tag;

    // Output status fields (captured by monitor)
    bit              ack_tran;
    bit              full;
    bit [511:0]      read_data;
    bit [2:0]        read_tag;
    bit              read_valid;

    // UVM Macros
    `uvm_object_utils_begin(ddr4_seq_item)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(rw, UVM_ALL_ON)
        `uvm_field_int(tag, UVM_ALL_ON)
        `uvm_field_int(ack_tran, UVM_ALL_ON)
        `uvm_field_int(full, UVM_ALL_ON)
        `uvm_field_int(read_data, UVM_ALL_ON)
        `uvm_field_int(read_tag, UVM_ALL_ON)
        `uvm_field_int(read_valid, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "ddr4_seq_item");
        super.new(name);
    endfunction

    // Custom display helper for logs
    virtual function string convert2string();
        return $sformatf("Tag: %0d | OP: %s | Addr: 32'h%08h | Data: 512'h%016h...%016h",
                         tag, (rw ? "WRITE" : "READ"), addr, data[511:480], data[31:0]);
    endfunction

endclass : ddr4_seq_item
