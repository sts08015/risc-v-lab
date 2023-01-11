/* ********************************************
 *	COSE222 Lab #2
 *
 *	Module: register file (regfile.sv)
 *	- 2 input and 1 output ports
 *	- 32 register entries including zero register (x0)
 *  - No internal forwarding is supported
 *
 *	Author: Gunjae Koo (gunjaekoo@korea.ac.kr)
 *
 * ********************************************
 */

`timescale 1ns/1ps

module regfile
#(  parameter   REG_WIDTH = 32 )    // the width of register file
(
    input           clk,
    input   [4:0]   rs1,    // source register 1
    input   [4:0]   rs2,    // source register 2
    input   [4:0]   rd,     // destination register
    input   [REG_WIDTH-1:0] rd_din,     // input data for rd
    input           reg_write,      // RegWrite signal
    output  [REG_WIDTH-1:0] rs1_dout,
    output  [REG_WIDTH-1:0] rs2_dout
);

    // Registers: RISC-V includes 32 architectural registers
    logic   [REG_WIDTH-1:0] rf_data[0:31];

    // Write operation:
    // - Note that clock is not used in the textbook, however in RTL design it can generate a infinite loop without clock.
    // Thus, the write operation is done at the rising edge of clock
    always_ff @ (posedge clk) begin
        if (reg_write)
            rf_data[rd] <= rd_din;
    end

    // Read operation
    assign rs1_dout = (|rs1) ? rf_data[rs1]: 'b0;
    assign rs2_dout = (|rs2) ? rf_data[rs2]: 'b0;

endmodule
