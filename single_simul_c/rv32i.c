#include "rv32i.h"

struct imem_output_t imem(struct imem_input_t imem_in)
{
	struct imem_output_t output = { 0 };
	output.dout = imem_in.imem_data[imem_in.addr];
	return output;
}

struct rf_output_t regfile(struct rf_input_t regfile_in)
{
	if (regfile_in.reg_write) regfile_in.rf_data[regfile_in.rd] = regfile_in.rd_din;

	struct rf_output_t output = { 0 };
	output.rs1_dout = (regfile_in.rs1) ? regfile_in.rf_data[regfile_in.rs1] : 0;
	output.rs2_dout = (regfile_in.rs2) ? regfile_in.rf_data[regfile_in.rs2] : 0;

	return output;
}

struct alu_output_t alu(struct alu_input_t alu_in)
{
	uint32_t result; //ALU output
	uint8_t zero;    //zero detection
	uint8_t sign;    //sign bit
	uint8_t carry;   //carry flag

	uint64_t tmp = 0;

	switch (alu_in.alu_control)
	{
	case 0:
		tmp = alu_in.in1 & alu_in.in2;
		break;
	case 1:
		tmp = alu_in.in1 | alu_in.in2;
		break;
	case 2:
		tmp = (uint64_t)alu_in.in1 + alu_in.in2;
		break;
	case 3:
		tmp = alu_in.in1 ^ alu_in.in2;
		break;
	case 6:
		tmp = (uint64_t)alu_in.in1 - alu_in.in2;
		break;
	case 7:
		tmp = (uint64_t)alu_in.in1 << alu_in.in2;
		break;
	case 8:
		tmp = alu_in.in1 >> alu_in.in2;
		break;
	case 9:
		tmp = ((int64_t)alu_in.in1) >> alu_in.in2;
		break;
	default:
		break;
	}


	struct alu_output_t output = { 0 };
	output.result = tmp;
	output.carry = (tmp >> REG_WIDTH) & 0x1;
	output.zero = (output.result == 0);
	output.sign = (output.result >> (REG_WIDTH - 1)) & 0x1;
	return output;
}

struct dmem_output_t dmem(struct dmem_input_t dmem_in)
{

	if (dmem_in.mem_write) {
		dmem_in.dmem_data[dmem_in.addr] = dmem_in.din;
	}

	struct dmem_output_t output;
	output.dout = dmem_in.mem_read ? dmem_in.dmem_data[dmem_in.addr] : 0;
	return output;
}

void show_state(uint32_t* reg_data, uint32_t* dmem_data)
{
	int i;
	puts("\nREGISTER FILE");
	for (i = 0; i < 32; i++) printf("RF[%03d]: %08X\n", i, reg_data[i]);

	puts("\nDMEM");
	for (i = 0; i < 15; i++) printf("DMEM[%03d]: %08X\n", i, dmem_data[i]);
}