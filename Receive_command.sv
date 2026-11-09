//This module is used by the Memory controller to receive commands from the Cache
//Author: Niraj Thakkar
module receive_command #(
    parameter DWIDTH = 512,
    parameter AWIDTH = 32
) (
	C2MInterface.Mem_tran IF,
	input logic fifo_full, 
	input logic [2:0] tag_gen,
	output logic rw_out, 
	output logic valid,
	output logic [AWIDTH-1:0] addr_out,
	output logic [DWIDTH-1:0] data_out
);

logic [DWIDTH-1:0] data;
logic [AWIDTH-1:0] addr;
logic [2:0] tag;
logic rw;
logic full;
logic ack;

assign valid = IF.ack_tran;

//Enumerated types of States
typedef enum logic [1:0] {init=2'b00, receive=2'b01, wait_deassert=2'b10} st;
st state,next_state;

assign data_out = data;
assign addr_out = addr;
assign rw_out = rw;

//Sequential Logic
always_ff @(posedge IF.clock)
begin
if(IF.reset)
	state<=init;
else begin
	state<=next_state;
	end
end

wire valid_tran_local = IF.valid_tran;
wire [AWIDTH-1:0] addr_local = IF.addr;
wire [DWIDTH-1:0] data_tran_local = IF.data_tran;
wire rw_local = IF.rw;

//Next State Logic
always_comb
begin
	case(state)
	init:	if(fifo_full || !valid_tran_local)
				next_state=init;
		 	else
				next_state=receive;
	
	receive: next_state=wait_deassert;
	
	wait_deassert: if(valid_tran_local)
				next_state=wait_deassert;
			 else
				next_state=init;
	default: next_state=init;
	endcase
end

always_comb
begin
	// Default assignments to prevent latches and resolve implicit states
	IF.full = fifo_full;
	IF.ack_tran = 0;
	IF.tag_tran = tag_gen;
	addr = addr_local;
	data = data_tran_local;
	rw = rw_local;
	tag = tag_gen;
	full = fifo_full;
	ack = 0;

	case(state)
	init:
		begin
		// Default values cover init state
		end
	receive:
		begin
		IF.ack_tran = 1;
		ack = 1;
		end
	wait_deassert:
		begin
		// Default values cover wait_deassert state
		end
	endcase
end

endmodule
