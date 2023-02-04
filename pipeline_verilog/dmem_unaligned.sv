/* ********************************************
 *	RISC-V RV32I single-cycle processor design
 *
 *	Module: data memory (dmem.sv)
 *	- 1 address input port
 *	- 32-bit 1 data output port
 *	- This data memory supports byte-address
 *	- RISC-V does not restrict aligned word
 *
 *	Author: Dongkyun Lim (sts08015@korea.ac.kr)
 *
 * ********************************************
 */

`timescale 1ns/1ps
`define FF 1	// FF delay for just better waveform figures

module dmem
#(	parameter	DMEM_DEPTH = 1024,		// dmem depth in a word (4 bytes, default: 1024 entries = 4 KB)
				DMEM_ADDR_WIDTH = 12 )	// dmem address width in a byte
(
	input			clk,
	input	[DMEM_ADDR_WIDTH-1:0]	addr,
	input			rd_en,		// read enable
	input			wr_en,		// write enable
	input	[1:0]	sz,			// data size (LB, LH, LW)
	input	[31:0]	din,
	output	[31:0]	dout
);

	// dmem does not receive the clock signal in the textbook.
	// however, it requires clocked write operation for better operation and synthesis

	// memory entries. dmem is split into 4 banks to support various data granularity
	logic	[7:0]	d0[0:DMEM_DEPTH-1];
	logic	[7:0]	d1[0:DMEM_DEPTH-1];
	logic	[7:0]	d2[0:DMEM_DEPTH-1];
	logic	[7:0]	d3[0:DMEM_DEPTH-1];
	
	// address for each bank
	logic	[DMEM_ADDR_WIDTH-3:0]	addr0;	// address for bank 0
	logic	[DMEM_ADDR_WIDTH-3:0]	addr1;	// address for bank 1
	logic	[DMEM_ADDR_WIDTH-3:0]	addr2;	// address for bank 2
	logic	[DMEM_ADDR_WIDTH-3:0]	addr3;	// address for bank 3
	
	assign addr0 = addr[DMEM_ADDR_WIDTH-1:2] + |addr[1:0];
	assign addr1 = addr[DMEM_ADDR_WIDTH-1:2] + addr[1];
	assign addr2 = addr[DMEM_ADDR_WIDTH-1:2] + &addr[1:0];
	assign addr3 = addr[DMEM_ADDR_WIDTH-1:2];
	
	// data out from each bank
	wire	[7:0]	dout0, dout1, dout2, dout3;
	
	assign dout0 = d0[addr0];
	assign dout1 = d1[addr1];
	assign dout2 = d2[addr2];
	assign dout3 = d3[addr3];
	
	// read operation with rd_en
	logic	[31:0]	dout_tmp;	// need to be aligned by an address offset
	
	always_comb begin
		case (addr[1:0])	// synopsys full_case parallel_case
			2'b00: dout_tmp = {dout3, dout2, dout1, dout0};
			2'b01: dout_tmp = {dout0, dout3, dout2, dout1};
			2'b10: dout_tmp = {dout1, dout2, dout3, dout2};
			2'b11: dout_tmp = {dout2, dout1, dout0, dout3};
		endcase
	end
	
	assign dout = (rd_en) ? dout_tmp: 'b0;
	
	// write operation with wr_en
	logic	[3:0]	we;		// write enable for each bank
	
	always_comb begin
		if (sz==2'b00) begin
			case (addr[1:0])	// synopsys full_case
				2'b00: we = {3'b000, wr_en};
				2'b01: we = {2'b00, wr_en, 1'b0};
				2'b10: we = {1'b0, wr_en, 2'b00};
				2'b11: we = {wr_en, 3'b000};
			endcase
		end
		else if (sz==2'b01) begin
			case (addr[1:0])	// synopsys full_case
				2'b00: we = {2'b00, {2{wr_en}}};
				2'b01: we = {1'b0, {2{wr_en}}, 1'b0};
				2'b10: we = {{2{wr_en}}, 2'b00};
				2'b11: we = {wr_en, 2'b00, wr_en};
			endcase
		end
		else
			we = {4{wr_en}};	// store word
	end
	
	// write operation that supports unaligned words
	logic	[31:0]	din_tmp;
	
	always_comb begin
		case (addr[1:0])	// synopsys full_case parallel_case
			2'b00: din_tmp = din[31:0];
			2'b01: din_tmp = {din[23:0], din[31:24]};
			2'b10: din_tmp = {din[15:0], din[31:16]};
			2'b11: din_tmp = {din[7:0], din[31:8]};
		endcase
	end
	
	// in the textbook, dmem does not receive the clock signal
	// but clocked write operation is required for better operation and synthesis
	// we must avoid latch for the normal cases
	always_ff @ (posedge clk) begin
		if (we[0]) d0[addr0] <= din_tmp[7:0];
		if (we[1]) d1[addr1] <= din_tmp[15:8];
		if (we[2]) d2[addr2] <= din_tmp[24:16];
		if (we[3]) d3[addr3] <= din_tmp[31:25];
	end
	
endmodule