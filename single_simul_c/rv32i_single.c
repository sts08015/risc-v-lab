/* **************************************
 * Module: top design of rv32i single-cycle processor
 *
 * Author: Dongkyun Lim (sts08015@korea.ac.kr)
 *
 * **************************************
 */

#include "rv32i.h"

int main(int argc, char* argv[]) {

	// get input arguments
	FILE* f_imem, * f_dmem;
	if (argc < 3) {
		printf("usage: %s imem_data_file dmem_data_file\n", argv[0]);
		exit(1);
	}

	if ((f_imem = fopen(argv[1], "r")) == NULL) {
		printf("Cannot find %s\n", argv[1]);
		exit(1);
	}
	if ((f_dmem = fopen(argv[2], "r")) == NULL) {
		printf("Cannot find %s\n", argv[2]);
		exit(1);
	}

	// memory data (global)
	uint32_t* reg_data;
	uint32_t* imem_data;
	uint32_t* dmem_data;

	reg_data = (uint32_t*)malloc(32 * sizeof(uint32_t));
	imem_data = (uint32_t*)malloc(IMEM_DEPTH * sizeof(uint32_t));
	dmem_data = (uint32_t*)malloc(DMEM_DEPTH * sizeof(uint32_t));

	// initialize memory data
	int i,k;
	for (i = 0; i < 32; i++) reg_data[i] = 0;
	for (i = 0; i < IMEM_DEPTH; i++) imem_data[i] = 0;
	for (i = 0; i < DMEM_DEPTH; i++) dmem_data[i] = 0;

	uint32_t d, buf;
	i = 0;
	printf("\n*** Reading %s ***\n", argv[1]);	//read imem
	while (fscanf(f_imem, "%1d", &buf) != EOF) {
		d = buf << 31;
		for (k = 30; k >= 0; k--) {
			if (fscanf(f_imem, "%1d", &buf) != EOF) {
				d |= buf << k;
			}
			else {
				printf("Incorrect format!!\n");
				exit(1);
			}
		}
		imem_data[i] = d;
		printf("imem[%03d]: %08X\n", i, imem_data[i]);
		i++;
	}

	i = 0;
	printf("\n*** Reading %s ***\n", argv[2]);	//read dmem
	while (fscanf(f_dmem, "%8x", &buf) != EOF) {
		dmem_data[i] = buf;
		printf("dmem[%03d]: %08X\n", i, dmem_data[i]);
		i++;
	}

	fclose(f_imem);
	fclose(f_dmem);


	// processor model
	uint32_t pc_curr = 0, pc_next;	// program counter

	struct imem_input_t imem_in = { 0 };
	imem_in.imem_data = imem_data;

	struct imem_output_t imem_out = { 0 };

	struct rf_input_t regfile_in = { 0 };
	regfile_in.rf_data = reg_data;
	struct rf_output_t regfile_out = { 0 };

	struct alu_input_t alu_in = { 0 };
	struct alu_output_t alu_out = { 0 };

	struct dmem_input_t dmem_in = { 0 };
	dmem_in.dmem_data = dmem_data;
	struct dmem_output_t dmem_out = { 0 };


	uint32_t cc = 2;	// clock count
	while (cc < CLK_NUM) {
		// instruction fetch
		imem_in.addr = pc_curr >> 2;
		imem_out = imem(imem_in, imem_data);
		uint32_t inst = imem_out.dout;

		// instruction decode
		uint8_t opcode = inst & 0x7f;
		uint8_t funct3 = (inst >> 12) & 0x7;
		uint8_t branch[7] = { 0 };
		if (opcode == 0x63) {
			branch[0] = (funct3 == 0);    //beq
			branch[1] = (funct3 == 1);    //bne
			branch[2] = (funct3 == 4);    //blt
			branch[3] = (funct3 == 5);    //bge
			branch[4] = (funct3 == 6);    //bltu
			branch[5] = (funct3 == 7);    //bgeu
		}
		else if (opcode == 0x6f || opcode == 0x67) {	//unconditional branch (jal, jalr)
			branch[6] = 1;
		}
		else for (int i = 0; i < 7; i++) branch[i] = 0;

		uint8_t mem_read = (opcode == 3);    // ld
		uint8_t mem_write = (opcode == 0x23);   // sd
		uint8_t mem_to_reg = (opcode == 3);   //ld
		uint8_t reg_write = (opcode == 3 || opcode == 0x33 || opcode == 0x13 || opcode == 0x67 || opcode == 0x6f || opcode == 0x37 || opcode == 0x17);
		uint8_t alu_src = (opcode == 3 || opcode == 0x23 || opcode == 0x13 || opcode == 0x67 || opcode == 0x6f || opcode == 0x17);

		uint8_t alu_op = 0;
		switch (opcode)
		{
		case 0x63:
			alu_op = 1;
			break;
		case 0x33:
			alu_op = 2;
			break;
		case 0x13:
			alu_op = 3;
			break;
		case 3:
		case 0x23:
		case 0x6f:
		case 0x67:
		case 0x17:
		default:
			alu_op = 0;
			break;
		}
		uint8_t funct7 = (inst >> 25) & 0x7f;
		uint8_t alu_control = 0;
		uint8_t slt = 0;
		if (alu_op == 0) {
			alu_control = 2;  //add
			slt = 0;
		}
		else if (alu_op == 1) {  //conditional branches
			alu_control = 6;      //sub --> to compare
			slt = 0;
		}
		else {
			if (funct3 == 0 && ((alu_op == 2 && funct7 == 0) || (alu_op == 3))) {  //add
				alu_control = 2;
				slt = 0;
			}
			else if (funct3 == 0 && funct7 == 0x20) { //sub
				alu_control = 6;
				slt = 0;
			}
			else if (funct3 == 7 && funct7 == 0) {   //and
				alu_control = 0;
				slt = 0;
			}
			else if (funct3 == 6) {   //or
				alu_control = 1;
				slt = 0;
			}
			else if (funct3 == 4) {   //xor
				alu_control = 3;
				slt = 0;
			}
			else if (funct3 == 1 && funct7 == 0) {   //shift left
				alu_control = 7;
				slt = 0;
			}
			else if (funct3 == 5 && funct7 == 0) {   //shift right
				alu_control = 8;
				slt = 0;
			}
			else if (funct3 == 5 && funct7 == 0x20) { //shift right arithmetic
				alu_control = 9;
				slt = 0;
			}
			else if (funct3 == 2 || funct3 == 3) { //set less than
				alu_control = 6;
				slt = 1;
			}
		}

		uint32_t  imm32 = 0;
		uint32_t  imm32_branch = 0;  // imm32 left shifted by 1
		uint16_t  imm12 = 0;  // 12-bit immediate value extracted from inst
		uint32_t  imm20 = 0;  // 20-bit immediate value --> for unconditional branch, upper immediate
		uint8_t   imm_flag = 0;

		switch (opcode)
		{
		case 3:   //ld
			imm12 = (inst >> 20) & 0xffff;
			imm_flag = 1;
			break;
		case 0x23:   //sd
			imm12 = 0;
			imm12 = ((inst >> 25) & 0x7f) << 5;
			imm12 = imm12 | (inst >> 7) & 0x1f;//[11:7];
			imm_flag = 1;
			break;
		case 0x13:   //i-type
			imm12 = (inst >> 20) & 0xfff;//[31:20];
			if (alu_control == 7 || alu_control == 8 || alu_control == 9) {    //slli, srli, srai
				imm12 = imm12 & 0x1f;//[4:0]};
			}
			imm_flag = 1;
			break;
		case 0x63:   //conditional branch
			imm12 = 0;
			imm12 = ((inst >> 31) & 0x1) << 11;
			imm12 = imm12 | (((inst >> 25) & 0x3f) << 4);
			imm12 = imm12 | ((inst >> 8) & 0xf);
			imm12 = imm12 | (((inst >> 7) & 0x1) << 10);
			/*
			imm12[11] = inst[31];
			imm12[9:4] = inst[30:25];
			imm12[3:0] = inst[11:8];
			imm12[10] = inst[7];
			*/
			imm_flag = 1;
			break;
		case 0x6f: //unconditional branch - jal
			imm20 = 0;
			imm20 = ((inst >> 31) & 0x1) << 19;
			imm20 = imm20 | (inst >> 21) & 0x3ff;
			imm20 = imm20 | (((inst >> 20) & 0x1) << 10);
			imm20 = imm20 | (((inst >> 12) & 0xff) << 11);
			/*
			imm20[19] = inst[31];
			imm20[9:0] = inst[30:21];
			imm20[10] = inst[20];
			imm20[18:11] = inst[19:12];
			*/
			imm_flag = 0;
			break;
		case 0x67:   //unconditional branch - jalr
			imm12 = (inst >> 20) & 0xffff;//[31:20];
			imm_flag = 1;
			break;
		case 0x17:   //auipc
			imm20 = (inst >> 12) & 0xfffff;//[31:12];
			imm_flag = 0;
			break;
		case 0x37:   //lui
			imm20 = (inst >> 12) & 0xfffff;//[31:12];
			imm_flag = 0;
			break;
		default:
			break;
		}

		if (imm_flag) {
			if ((opcode == 0x13 && funct3 == 3) && (opcode == 0x63 && (funct3 == 6 || funct3 == 7))) {
				imm32 = imm12 & 0xfff;         //bit extension (unsigned)
			}
			else {
				uint8_t sign_bit = (imm12 >> 11) & 0x1;
				if (sign_bit) imm32 = 0xfffff000;
				else imm32 = 0;
				imm32 = imm32 | (imm12 & 0xfff);//{{20{imm12[11]}},imm12};    //sign extension
			}
		}
		else {
			uint8_t sign_bit = (imm12 >> 11) & 0x1;
			if (sign_bit) imm32 = 0xfffff000;
			else imm32 = 0;
			imm32 = imm32 | (imm20 & 0xfffff);
			//imm32 = {{12{imm20[19]}},imm20};    //sign extension
		}

		regfile_in.rs1 = (inst >> 15) & 0x1f;//[19:15];
		regfile_in.rs2 = (inst >> 20) & 0x1f;//[24:20];
		regfile_in.rd = (inst >> 7) & 0x1f;//[11:7];
		regfile_in.reg_write = 0;	//not now (bc it is just decode step!)
		regfile_out = regfile(regfile_in, reg_data);

		// execution
		alu_in.alu_control = alu_control;
		alu_in.in1 = ((branch[6] && opcode == 0x6f) || opcode == 0x17) ? pc_curr : regfile_out.rs1_dout;
		alu_in.in2 = alu_src ? imm32 : regfile_out.rs2_dout;
		alu_out = alu(alu_in);

		uint8_t pc_next_sel;    // selection signal for pc_next
		uint32_t pc_next_plus4, pc_next_branch;
		pc_next_plus4 = pc_curr + 4;

		if (branch[0] == 1) { //beq
			pc_next_sel = alu_out.zero;
		}
		else if (branch[1] == 1) {    //bne
			pc_next_sel = !alu_out.zero;
		}
		else if (branch[2] == 1) {    //blt
			pc_next_sel = alu_out.sign;
		}
		else if (branch[3] == 1) {    //bge
			pc_next_sel = (!alu_out.sign || alu_out.zero);
		}
		else if (branch[4] == 1) {    //bltu
			pc_next_sel = alu_out.sign;
		}
		else if (branch[5] == 1) {    //bgeu
			pc_next_sel = (!alu_out.sign || alu_out.zero);
		}
		else if (branch[6] == 1) {    //unconditional branch (jal, jalr)
			pc_next_sel = 1;
		}
		else {
			pc_next_sel = 0;
		}

		if (opcode == 0x67) {  //jalr
			pc_next_branch = alu_out.result;
		}
		else {
			imm32_branch = imm32 << 1;
			pc_next_branch = pc_curr + imm32_branch;
		}
		pc_next = (pc_next_sel) ? pc_next_branch : pc_next_plus4; // if branch is taken, pc_next_sel=1'b1
		pc_curr = pc_next;

		// memory
		dmem_in.addr = alu_out.result >> 2; //32bit-dmem
		if (funct3 == 0) {  //sb
			dmem_in.din = regfile_out.rs2_dout & 0xff;//[7:0];
		}
		else if (funct3 == 1) { //sh
			dmem_in.din = regfile_out.rs2_dout & 0xffff;//[15:0];
		}
		else {  //sw
			dmem_in.din = regfile_out.rs2_dout;
		}
		dmem_in.mem_read = mem_read;
		dmem_in.mem_write = mem_write;
		dmem_out = dmem(dmem_in, dmem_data);

		// write-back
		regfile_in.reg_write = reg_write;
		if (branch[6]) {
			regfile_in.rd_din = pc_next_plus4;
		}
		else if (mem_to_reg) {
			if (funct3 == 0) {    //lb
				uint8_t sign_bit = (dmem_out.dout >> 7) & 0x1;
				if (sign_bit) regfile_in.rd_din = 0xffffff00;
				else regfile_in.rd_din = 0;
				regfile_in.rd_din = regfile_in.rd_din | (dmem_out.dout & 0xff);   //sign-extension
			}
			else if (funct3 == 1) { //lh
				uint8_t sign_bit = (dmem_out.dout >> 15) & 0x1;
				if (sign_bit) regfile_in.rd_din = 0xffff0000;
				else regfile_in.rd_din = 0;
				regfile_in.rd_din = regfile_in.rd_din | (dmem_out.dout & 0xffff);   //sign-extension
				//regfile_in.rd_din = {{16{dmem_dout[15]}},dmem_dout[15:0]};   //sign-extension
			}
			else if (funct3 == 4) { //lbu
				regfile_in.rd_din = dmem_out.dout & 0xff;//[7:0];
			}
			else if (funct3 == 5) { //lhu
				regfile_in.rd_din = dmem_out.dout & 0xffff;//[15:0];
			}
			else {  //lw
				regfile_in.rd_din = dmem_out.dout;
			}
		}
		else if (slt) {
			if (opcode == 0x33 && funct3 == 3 && funct7 == 0) {    //sltu
				regfile_in.rd_din = alu_out.carry;
			}
			else {
				regfile_in.rd_din = alu_out.sign;
			}
		}
		else if (opcode == 0x37) { //lui
			regfile_in.rd_din = imm32 << 12;
		}
		else {
			regfile_in.rd_din = alu_out.result;
		}
		regfile_out = regfile(regfile_in, reg_data);
		cc++;
	}

	show_state(reg_data, dmem_data);

	free(reg_data);
	free(imem_data);
	free(dmem_data);

	return 0;
}