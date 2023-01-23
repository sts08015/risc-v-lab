`timescale 1ns/1ps

module alu
#(  parameter REG_WIDTH = 32 )  // ALU input data width is equal to the width of register file
(
    input   [REG_WIDTH-1:0] in1,    // Operand 1
    input   [REG_WIDTH-1:0] in2,    // Operand 2
    input   [3:0]   alu_control,    // ALU control signal
    output  logic [REG_WIDTH-1:0] result, // ALU output
    output          zero,           // Zero detection
    output          sign,            // Sign bit
    output          carry           //carry flag
);
    logic [REG_WIDTH:0] tmp;

    always_comb begin
        case (alu_control)
            4'b0000: tmp = {1'b0,in1} & {1'b0,in2};
            4'b0001: tmp = {1'b0,in1} | {1'b0,in2};
            4'b0010: tmp = {1'b0,in1} + {1'b0,in2};
			4'b0011: tmp = {1'b0,in1} ^ {1'b0,in2};
            4'b0110: tmp = {1'b0,in1} - {1'b0,in2};
            4'b0111: tmp = {1'b0,in1} << {1'b0,in2};
            4'b1000: tmp = {1'b0,in1} >> {1'b0,in2};
            4'b1001: tmp = {1'b0,in1} >>> {1'b0,in2};
            default: begin
            end
		endcase
    end

    assign result = tmp[REG_WIDTH-1:0];
    assign carry = tmp[REG_WIDTH];
    assign zero = ~|result;
    assign sign = result[REG_WIDTH-1];

endmodule
