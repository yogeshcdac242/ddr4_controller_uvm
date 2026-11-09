///////////////////////MEMORY CONTROLLER FSM/////////////////////////////////
//This module handles the communication between the memory controller and the memory.
//It uses the methods from the DDR4 interface to communicate with the memory.
//It uses the ReadMod and WriteMod modules from ReadWrite.sv to transfer data at DDR.
//Author: Ananth Bhat
`define DPRINT $display($time, "\t%m\t STATE: %s",state.name)
module MemContFSM
#(
	//Parameters included from Definitions.h
	`include "Definitions.pkg"
)
(
	input logic reset, clock,clock2x,
	input logic start,rw,refresh,ap,
	input logic [BuffBits-1:0] tagreadin,
	input logic [BWIDTH-1:0] bank,
	input logic [BGWIDTH-1:0] bankgroup,
	input logic [RWIDTH-1:0] row,
	input logic [CWIDTH-1:0] column,
	input logic [1:0] PageHit,
	input logic PageMiss,PageEmpty,
	output logic done,buff,
	output logic [BuffBits-1:0] tagreadout,
	output wire [DATAWIDTH-1:0] dataread,
	input wire [DATAWIDTH-1:0] datawrite,
	interface DDR4Bus
);
//Enumerated State Definitions
enum {Reset,Wait,Activate,Read,Write,DataRead,DataWrite,Done,Refresh,Precharge,LoadTimer} state,next,prev;

//Variable definitions
logic HitZero,set,StartRd_n,StartWr_n,read,write;
logic [31:0] Load;
logic [SHIFTBITS:0] ShiftInputRd,ShiftOutputRd, ShiftInputWr, ShiftOutputWr;
wire [DATAWIDTH-1:0] DataHost;

///////////Module Instantiations///////////////
CountdownTimer C (.clock,.Load, .Reset(set),.HitZero(HitZero));
ReadMod RC (.read,.reset(StartRd_n),.DataHost(dataread),.DataBus(DDR4Bus.pin_dq), .DQS_t(DDR4Bus.dqs_t), .DQS_c(DDR4Bus.dqs_c));
WriteMod WC(.write,.clock2x,.reset(StartWr_n),.DataHost,.DataBus(DDR4Bus.pin_dq),.DQS_t(DDR4Bus.dqs_t), .DQS_c(DDR4Bus.dqs_c));
ShiftRegMC ShiftRead (.clock, .reset, .ShiftInput(ShiftInputRd), .ShiftOutput(ShiftOutputRd));
ShiftRegMC ShiftWrite (.clock, .reset, .ShiftInput(ShiftInputWr), .ShiftOutput(ShiftOutputWr));

//Variable Definitions
logic [DATAWIDTH-1:0]WriteArray [TCL-1:0]; 
logic WriteFlag;
logic [SHIFTBITS-1:0] pointer,LatchPointer;
logic [3:0] WaitRegWr;
logic [4:0] WaitRegRd;
logic [4:0][BuffBits-1:0] TagRegRd;
wire waitrd,waitwr;
logic shiftrd,shiftwr;

// 1-cycle delay register for ShiftOutputRd.
// Controller ShiftRegMC (TCL-1 stages) fires 1 cycle before
// Memory ShiftRegMem (TCL-2 stages), causing ReadMod to start
// 2 DQS edges early. This 1-cycle delay compensates exactly.
logic [SHIFTBITS:0] ShiftOutputRd_d;

assign DataHost = WriteArray[LatchPointer];

//Continuous Assignments
assign buff = WaitRegRd[0]; //Buff tells the scheduler that a read is done
assign waitrd = ~|WaitRegRd;//Logic to determine start, read, write signals
assign waitwr = ~|WaitRegWr;
assign {StartRd_n,StartWr_n} = {waitrd,waitwr};
assign {read,write} = {~waitrd,~waitwr};


	// 1-cycle delay for ShiftOutputRd to align ReadMod start with memory drive
	always_ff @(posedge clock) begin
		if(reset) ShiftOutputRd_d <= '0;
		else ShiftOutputRd_d <= ShiftOutputRd;
	end

	//Shift Register, Write Array, Pointer logic 
	always_ff @(posedge clock)
	begin
	if(reset) begin
		pointer <= 1'b0;
		WaitRegRd <= 5'b0;
		WaitRegWr <= 4'b0;
		TagRegRd <= '0;
	end
	else begin 
		WaitRegRd <= {ShiftOutputRd_d[SHIFTBITS],WaitRegRd[4:1]};
		WaitRegWr <= {ShiftOutputWr[SHIFTBITS],WaitRegWr[3:1]};
		TagRegRd <= {ShiftOutputRd_d[SHIFTBITS-1:1], TagRegRd[4:1]};
		assert( !$isunknown(WaitRegWr) && $countones(WaitRegWr)<=1)
			else $fatal(1, "Write Timing Violation:WaitRegWr value isnt perfect\tWaitRegWr:%b",WaitRegWr);
		assert(!$isunknown(WaitRegRd) && $countones(WaitRegRd)<=1)
			else $fatal(1, "Read Timing Violation:WaitRegRd value isnt perfect\tWaitRegRd:%b",WaitRegRd);
		if(WriteFlag==1'b1)
			pointer <= pointer + 1'b1;
		
	end

end // always_ff

//Logic to latch pointer during data read/write
always_ff @(posedge clock) begin
		if(reset)
			LatchPointer <= '0;
		else if(ShiftOutputWr[SHIFTBITS])
			LatchPointer <= ShiftOutputWr[SHIFTBITS-1:0];
end

assign tagreadout = TagRegRd[0];


//LatchPointer should remain constant for 4 clock cycles
property Latch_Pointer;
@(posedge clock)
	ShiftOutputWr[SHIFTBITS] |=> ##1 !($changed(LatchPointer))[*3];
endproperty

assert property (Latch_Pointer)
	else $fatal(1, "RW Address not constant during transfer. Latch pointer not constant\tLatchPointer:%0d",LatchPointer);


////////// FINITE STATE MACHINE ///////////
always_ff @(posedge clock)
begin
	if(reset)
		state <= Reset;
	else begin
		state <= next;
		prev <= state;
	end
end

//Next State Logic
always_comb
begin
next = state;
case (state)
	Reset:		case({start,refresh}) inside
					2'b0x:	next = Reset;
					2'b11:	next = Refresh;
					2'b10:	next = LoadTimer;
				endcase
	LoadTimer:	begin
				unique case(prev) 
					Reset:	begin
								assert(PageEmpty)
									else $fatal(1, "Protocol Violation:First access to bank without precharge is not allowed");
								next = Activate;
								
							end
				Precharge: next = Activate;
					Done:	begin		
								if(PageEmpty)
									next = Activate;
								else
									next =  Wait;
							end
				endcase
				end

	Wait:		begin
					case ({HitZero,rw}) inside
						2'b0x:	next = Wait;
						2'b10:	next = Read;
						2'b11:	next = Write;
					endcase

				end
	Activate:	begin
					case ({HitZero,rw}) inside
						2'b0x:	next = Wait;
						2'b10:	next = Read;
						2'b11:	next = Write;
					endcase
				end
	Read:		next = Done;
	Write:		next = Done;
	Done:		if(start) begin
					assert($countones({PageEmpty,PageMiss,PageHit})>0)
						else $fatal(1, "Protocol Violation: Check Page Inputs from Scheduler");
					unique case ({PageEmpty,PageMiss,PageHit,refresh}) inside
						5'b10000:	next = LoadTimer;
						5'b01000:	next = Precharge;
						5'b00100:	next = LoadTimer;
						5'b00110:	next = LoadTimer;
						5'bxxxx1:	next = Refresh;
					endcase
				end
				else
					next = Done;
	Precharge:	next = LoadTimer;	
	Refresh:	next = Done;

endcase
end

//Output Function Logic
always_comb
begin
`DPRINT;
ShiftInputWr='0;
ShiftInputRd='0;
WriteFlag = 1'b0;
done=1'b0;
set = 1'b0;
DDR4Bus.dq_c = 'z;
case (state)
	Reset:		begin
					DDR4Bus.MRS(3'b0,13'b0);
					done = 1'b1;//Done is made high to tell the 
								//sceduler to send the first request
				end
	LoadTimer:	begin
					set = 1'b1;
					unique case(prev) 
						Reset:		Load = TRCD-1;
						Activate:	Load = TCL-1;
						Precharge:	Load = TRP-1;
						Done:		begin 
									unique case ({PageEmpty,PageHit}) inside
										3'b100:	Load = TRCD -1;
										3'b010: Load = TCCD_S-1;
										3'b011: Load = TCCD_L-1;
									endcase
									end
						
				endcase
				end
	Wait:		DDR4Bus.DES;
	Activate:	begin
					DDR4Bus.ACT(row,bankgroup,bank);
				end
	Read:		begin
					ShiftInputRd = {1'b1,tagreadin,1'b0};
					if(ap)
						DDR4Bus.RDA(column,bankgroup,bank);
					else
						DDR4Bus.RD(column,bankgroup,bank);
				end

	Write:		begin
					ShiftInputWr = {1'b1,pointer};
					WriteArray[pointer] = datawrite;
					WriteFlag = 1'b1;
					if(ap)
						DDR4Bus.WRA(column,bankgroup,bank);
					else
						DDR4Bus.WR(column,bankgroup,bank);
				end

	Done:		begin
					DDR4Bus.DES;
					done =1'b1;
				end
	Precharge:	DDR4Bus.PRE(bankgroup,bank);
	Refresh:	DDR4Bus.REF;
endcase
end

endmodule
