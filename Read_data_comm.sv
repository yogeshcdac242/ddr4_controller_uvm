//This file handles the communication between the memory controller and the \
//Cache BFM with respect to the data read by the controller from the memory.
//Send_read_data is used by the controller
//receive_read_data is used by the cache bfm
//Author: Niraj Thakkar
module send_read_data #(
    parameter DWIDTH = 512
) (	
	C2MInterface.Mem_data IF, 
	input logic internal_ready,
	input logic [DWIDTH-1:0] data_in, 
	input logic [2:0] tag_gen
);

assign IF.read_data = (internal_ready)?data_in:'z;
assign IF.tag_data = (internal_ready)?tag_gen:'z;
assign IF.valid_data = internal_ready;

endmodule

// receive_read_data module removed as it is unused in the UVM testbench
