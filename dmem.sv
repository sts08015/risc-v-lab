/* ********************************************
 *	COSE222 Lab #2
 *
 *	Module: data memory (dmem.sv)
 *	- 1 address input port
 *	- 32-bit 1 data input and output ports
 *	- A single entry size is 64-bit
 *
 *	Author: Gunjae Koo (gunjaekoo@korea.ac.kr)
 *
 * ********************************************
 */

`timescale 1ns/1ps

module dmem
#(  parameter DMEM_DEPTH = 1024,    // dmem depth (default: 1024 entries = 8 KB)
              DMEM_ADDR_WIDTH = 10 )
(
    input           clk,
    input   [DMEM_ADDR_WIDTH-1:0]   addr,
    input   [31:0]  din,
    input           mem_read,
    input           mem_write,
    output  [31:0]  dout
);

    /* Data memory does not receive the clock signal in the textbook.
     * Without clock we need to implement the data memory with latches.
     * However, you must avoid generating latches in real RTL design.
     * If latches are generated after synthesis, then it means your design includes critical bugs.
     * Hence, in this design you are requested to design the data memory with the clock signal.
     * That means the written data is updated at the rising edge of the clock signal.
     */

    // Actually RISC-V supports misaligned data accesses to memory, however it this design the data memory will only support
    // the aligned memory accesses.

    logic   [31:0]  data[0:DMEM_DEPTH-1];

    // Write operation:
    always_ff @ (posedge clk) begin
        if (mem_write)
            data[addr] <= din;
    end

    // Read operation:
    // - dout = 0 if (mem_read==0) 
    assign dout = (mem_read) ? data[addr]: 'b0;

// synthesis translate_off
    initial begin
        $readmemh("dmem.mem", data);
    end
// synthesis translate_on

endmodule
