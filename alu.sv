/* ********************************************
 *	COSE222 Lab #2
 *
 *	Module: ALU (alu.sv)
 *  - 64-bit 2 input and 1 output ports
 *
 *  Author: Gunjae Koo (gunjaekoo@korea.ac.kr)
 *
 * ********************************************
 */

`timescale 1ns/1ps

module alu
#(  parameter REG_WIDTH = 32 )  // ALU input data width is equal to the width of register file
(
    input   [REG_WIDTH-1:0] in1,    // Operand 1
    input   [REG_WIDTH-1:0] in2,    // Operand 2
    input   [3:0]   alu_control,    // ALU control signal
    output  logic [REG_WIDTH-1:0] result, // ALU output
    output          zero,           // Zero detection
    output          sign            // Sign bit
);

    always_comb begin
        case (alu_control)
            4'b0000: result = in1 & in2;
            4'b0001: result = in1 | in2;
            4'b0010: result = in1 + in2;
			4'b0011: result = in1 ^ in2;
            4'b0110: result = in1 - in2;
            4'b0111: result = in1 << in2;
            4'b1000: result = in1 >> in2;
            4'b1001: result = in1 >>> in2;
            default: begin
            end
		endcase
    end

    assign zero = ~|result;
    assign sign = result[REG_WIDTH-1];

endmodule
