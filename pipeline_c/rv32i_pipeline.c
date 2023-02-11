/* **************************************
 * Module: top design of rv32i pipelined processor
 *
 * Author: Dongkyun Lim (sts08015@korea.ac.kr)
 *
 * **************************************
 */

#include "rv32i.h"
#include <string.h>

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
	uint32_t pc_curr = 0, pc_next = 0;	// program counter

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
	uint32_t inst = 0;
	uint8_t opcode = 0;
	uint8_t funct3 = 0;
	uint8_t branch[7] = { 0 };
	uint8_t branch_taken = 0;
	uint8_t mem_read = 0;
	uint8_t mem_write = 0;
	uint8_t mem_to_reg = 0;
	uint8_t reg_write = 0;
	uint8_t alu_src = 0;
	uint8_t alu_op = 0;
	uint8_t funct7 = 0;
	uint8_t alu_control = 0;
	uint8_t slt = 0;
	uint32_t  imm32 = 0;
	uint32_t  imm32_branch = 0;
	uint16_t  imm12 = 0; 
	uint32_t  imm20 = 0;
	uint8_t   imm_flag = 0;
	uint8_t sign_bit = 0;
	uint8_t pc_next_sel = 0;
	uint32_t pc_next_plus4 = 0;
	uint32_t pc_next_branch = 0;
	uint32_t alu_fwd_in1 = 0;
	uint32_t alu_fwd_in2 = 0;
	uint8_t bu_zero = 0;
	uint8_t bu_sign = 0;
	uint8_t bu_carry = 0;
	uint32_t dmem_addr = 0;
	uint32_t dmem_din = 0;
	uint32_t dmem_dout = 0;
	uint8_t if_flush = 0;
	uint8_t if_stall = 0;
	uint8_t id_flush = 0;
	uint8_t id_stall = 0;
	uint8_t rs1 = 0;
	uint8_t rs2 = 0;
	uint8_t rd = 0;
	//uint32_t rs1_dout = 0;
    //uint32_t rs2_dout = 0;
	uint8_t forward_a = 0;
	uint8_t forward_b = 0;
	uint32_t alu_in1 = 0;
	uint32_t alu_in2 = 0;
	uint8_t stall_by_load_use = 0;
	uint8_t flush_by_branch = 0;
	uint8_t pc_write = 0;
	//uint32_t rd_din = 0;
	uint32_t imem_addr = 0;
	

	pipe_if_id id = {0};
	pipe_id_ex ex = {0};
	pipe_ex_mem mem = {0};
	pipe_mem_wb wb = {0};

	while (cc < CLK_NUM) {
		//MEM - WB pipeline register
		wb.alu_result = mem.alu_result;
        wb.dmem_dout = dmem_out.dout;
        wb.rd = mem.rd;
        wb.reg_write = mem.reg_write;
        wb.mem_to_reg = mem.mem_to_reg;
        wb.funct3 = mem.funct3;
        wb.opcode = mem.opcode;
        wb.slt = mem.slt;
        wb.imm32 = mem.imm32;
        wb.pc = mem.pc;
        wb.sign = mem.sign;
        wb.carry = mem.carry;
        wb.ub = mem.ub;

		//WriteBack
		if(wb.ub) regfile_in.rd_din = wb.pc + 4;
		else if(wb.mem_to_reg)
		{
			if (wb.funct3 == 0) {    //lb
				sign_bit = (dmem_out.dout >> 7) & 0x1;
				if (sign_bit) regfile_in.rd_din = 0xffffff00;
				else regfile_in.rd_din = 0;
				regfile_in.rd_din = regfile_in.rd_din | (dmem_out.dout & 0xff);   //sign-extension
			}
			else if (wb.funct3 == 1) { //lh
				sign_bit = (dmem_out.dout >> 15) & 0x1;
				if (sign_bit) regfile_in.rd_din = 0xffff0000;
				else regfile_in.rd_din = 0;
				regfile_in.rd_din = regfile_in.rd_din | (dmem_out.dout & 0xffff);   //sign-extension
			}
			else if (wb.funct3 == 4) { //lbu
				regfile_in.rd_din = dmem_out.dout & 0xff;
			}
			else if (wb.funct3 == 5) { //lhu
				regfile_in.rd_din = dmem_out.dout & 0xffff;
			}
			else {  //lw
				regfile_in.rd_din = dmem_out.dout;
			}
		}
		else if(wb.slt)
		{
			if (wb.opcode == 0x33 && wb.funct3 == 3) {    //sltu
				regfile_in.rd_din = wb.carry;
			}
			else {
				regfile_in.rd_din = wb.sign;
			}
		}
		else if (wb.opcode == 0x37) { //lui
			regfile_in.rd_din = wb.imm32 << 12;
		}
		else {
			regfile_in.rd_din = wb.alu_result;
		}

		regfile_in.reg_write = wb.reg_write;
		regfile_in.rd = wb.rd;
		regfile(regfile_in);
		
		//EX - MEM pipeline register
		mem.alu_result = alu_out.result; //alu_result[REG_WIDTH-1:0];
        mem.rs2_dout = alu_fwd_in2;    //for store op, inputs for alu and mem are different. imm, reg, respectively.
        mem.mem_read = ex.mem_read;
        mem.mem_write = ex.mem_write;
        mem.rd = ex.rd;
        mem.reg_write = ex.reg_write;
        mem.mem_to_reg = ex.mem_to_reg;
        mem.funct3 = ex.funct3;
        mem.opcode = ex.opcode;
        mem.slt = slt;
        mem.imm32 = ex.imm32;
        mem.pc = ex.pc;
        mem.sign = bu_sign;
        mem.carry = bu_carry;
        mem.ub = ex.branch[6];

		//Memory
		dmem_addr = mem.alu_result >> 2; //32bit-dmem
		if (mem.funct3 == 0) {  //sb
			dmem_din = mem.rs2_dout & 0xff;//[7:0];
		}
		else if (mem.funct3 == 1) { //sh
			dmem_din = mem.rs2_dout & 0xffff;//[15:0];
		}
		else {  //sw
			dmem_din = mem.rs2_dout;
		}

		dmem_in.addr = dmem_addr;
		dmem_in.din = dmem_din;
		dmem_in.mem_read = mem.mem_read;
		dmem_in.mem_write = mem.mem_write;

		dmem_out = dmem(dmem_in);
		printf("DMEM address : %x\n",dmem_in.addr);
		printf("DMEM READ : %d\n", dmem_in.mem_read);
		printf("DMEM output : %x\n", dmem_out.dout);

		// ID-EX pipeline register
		
		if (id_flush)
		{
			memset(&ex, 0, sizeof(ex));
		}
    	else if(!id_stall)
		{
                ex.pc = id.pc; //current inst's pc
                ex.rs1_dout = regfile_out.rs1_dout;
                ex.rs2_dout = regfile_out.rs2_dout;
                ex.imm32 = imm32;
                ex.opcode = opcode;
                ex.funct3 = funct3;
                ex.funct7 = funct7;
				memcpy(ex.branch, branch, sizeof(branch));
                ex.alu_src = alu_src;
                ex.alu_op = alu_op;
                ex.mem_read = mem_read;
                ex.mem_write = mem_write;
                ex.rs1 = rs1;
                ex.rs2 = rs2;
                ex.rd = rd;
                ex.reg_write = reg_write;
                ex.mem_to_reg = mem_to_reg;
		}
		else 
		{  //if stall, only update signals
            ex.mem_read = mem_read;    //should update mem_read to escape stalled stage
            ex.rd = rd;
            ex.reg_write = reg_write;
		}

		//Execute
		if(ex.alu_op == 0)
		{
            alu_control = 2;  //add
            slt = 0;
		}
        else if(ex.alu_op == 1)
		{  //conditional branches
            alu_control = 6;
            slt = 0;
		}
        else 
		{
            if(ex.funct3 == 0 && ((ex.alu_op == 2 && ex.funct7 == 0) || (ex.alu_op == 3)))
			{  //add
                alu_control = 2;
                slt = 0;
			}
            else if(ex.funct3 == 0 && ex.funct7 == 0x20)
			{ //sub
                alu_control = 6;
                slt = 0;
			}
            else if(ex.funct3 == 7 && ex.funct7 == 0)
			{   //and
                alu_control = 0;
                slt = 0;
			}
            else if(ex.funct3 == 6)
			{   //or
                alu_control = 1;
                slt = 0;
			}
            else if(ex.funct3 == 4)
			{   //xor
                alu_control = 3;
                slt = 0;
			}
            else if(ex.funct3 == 1 && ex.funct7 == 0)
			{   //shift left
                alu_control = 7;
                slt = 0;
			}
            else if(ex.funct3 == 5 && ex.funct7 == 0)
			{   //shift right
                alu_control = 8;
                slt = 0;
			}
            else if(ex.funct3 == 5 && ex.funct7 == 0x20)
			{ //shift right arithmetic
                alu_control = 9;
                slt = 0;
			}
            else if(ex.funct3 == 2 || ex.funct3 == 3)
			{ //set less than
                alu_control = 6;
                slt = 1;
			}
		}

		if(mem.opcode == 0x37 && mem.rd == ex.rs1 && mem.rd != 0) forward_a = 3;
		else if(mem.reg_write && mem.rd == ex.rs1 && mem.rd != 0) forward_a = 2; 
		else if (wb.reg_write && wb.rd == ex.rs1 && wb.rd != 0) forward_a = 1;
        else forward_a = 0;

		if(mem.opcode == 0x37 && mem.rd == ex.rs2 && mem.rd != 0) forward_b = 3;
        else if(mem.reg_write && mem.rd == ex.rs2 && mem.rd != 0) forward_b = 2;
    	else if (wb.reg_write && wb.rd == ex.rs2 && wb.rd != 0) forward_b = 1;
        else forward_b = 0;
		
		//Forwarding unit
		switch (forward_a)
		{
		case 0:
			alu_fwd_in1 = ex.rs1_dout;
			break;
		case 2:
			alu_fwd_in1 = mem.alu_result;
			break;
		case 1:
			alu_fwd_in1 = regfile_in.rd_din;
			break;
		case 3:
			alu_fwd_in1 = mem.imm32;
			break;
		default:
			break;
		}

		switch (forward_b)
		{
		case 0:
			alu_fwd_in2 = ex.rs2_dout;
			break;
		case 2:
			alu_fwd_in2 = mem.alu_result;
			break;
		case 1:
			alu_fwd_in2 = regfile_in.rd_din;
			break;
		case 3:
			alu_fwd_in2 = mem.imm32;
			break;
		default:
			break;
		}

		alu_in1 = (ex.branch[6] || ex.opcode == 0x17) ? ex.pc : alu_fwd_in1;
    	alu_in2 =  ex.alu_src ? ex.imm32 : alu_fwd_in2;

		alu_in.in1 = alu_in1;
		alu_in.in2 = alu_in2;
		alu_in.alu_control = alu_control; 

		alu_out = alu(alu_in);

		bu_zero =  (alu_out.result == 0);
		bu_sign = (alu_out.result >> 31) & 0x1;
    	bu_carry = (alu_out.result >> 32) & 0x1;

        if(ex.branch[0] == 1) branch_taken = bu_zero;
        else if(ex.branch[1]) branch_taken = !bu_zero;
        else if(ex.branch[2]) branch_taken = bu_sign;
        else if(ex.branch[3]) branch_taken = (!bu_sign || bu_zero);
        else if(ex.branch[4]) branch_taken = bu_carry;
        else if(ex.branch[5]) branch_taken = (!bu_carry || bu_zero);
        else if(ex.branch[6]) branch_taken = 1;
		else branch_taken = 0;
		
		//IF-ID pipeline register
        if (if_flush) memset(&id, 0, sizeof(id));
        else if (!if_stall)
		{
			id.pc =  pc_curr; 
            id.inst =  inst; 
		}

		//Instruction Decode
		opcode = id.inst & 0x7f;
    	funct3 = (id.inst>>12) & 0x7;//[14:12];
    	funct7 = (id.inst>>25) & 0x7f;//[31:25];

        if(opcode == 0x63)
		{
            branch[0] = (funct3 == 0);    //beq
            branch[1] = (funct3 == 1);    //bne
            branch[2] = (funct3 == 4);    //blt
            branch[3] = (funct3 == 5);    //bge
            branch[4] = (funct3 == 6);    //bltu
            branch[5] = (funct3 == 7);    //bgeu
		}
        else if(opcode == 0x6f || opcode == 0x67) branch[6] = 1;
        else memset(branch, 0, sizeof(branch));

		mem_read = (opcode == 3);    // ld
		mem_write = (opcode == 0x23);   // sd
		mem_to_reg = (opcode == 3);   //ld
		reg_write = (opcode == 3 || opcode == 0x33 || opcode == 0x13 || opcode == 0x67 || opcode == 0x6f || opcode == 0x37 || opcode == 0x17);
		alu_src = (opcode == 3 || opcode == 0x23 || opcode == 0x13 || opcode == 0x67 || opcode == 0x6f || opcode == 0x17);

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
			imm_flag = 1;
			break;
		case 0x6f: //unconditional branch - jal
			imm20 = 0;
			imm20 = ((inst >> 31) & 0x1) << 19;
			imm20 = imm20 | ((inst >> 21) & 0x3ff);
			imm20 = imm20 | (((inst >> 20) & 0x1) << 10);
			imm20 = imm20 | (((inst >> 12) & 0xff) << 11);
			imm_flag = 0;
			break;
		case 0x67:   //unconditional branch - jalr
			imm12 = (inst >> 20) & 0xffff;//[31:20];
			imm_flag = 1;
			break;
		case 0x17:   //auipc
			imm20 = (inst >> 12) & 0xfffff;
			imm_flag = 0;
			break;
		case 0x37:   //lui
			imm20 = (inst >> 12) & 0xfffff;
			imm_flag = 0;
			break;
		default:
			break;
		}

		if (imm_flag)
		{
			if ((opcode == 0x13 && funct3 == 3) && (opcode == 0x63 && (funct3 == 6 || funct3 == 7)))
			{
				imm32 = imm12 & 0xfff;         //bit extension (unsigned)
			}
			else 
			{
				sign_bit = (imm12 >> 11) & 0x1;
				if (sign_bit) imm32 = 0xfffff000;
				else imm32 = 0;
				imm32 = imm32 | (imm12 & 0xfff);//{{20{imm12[11]}},imm12};    //sign extension
			}
		}
		else
		{
			sign_bit = (imm12 >> 11) & 0x1;
			if (sign_bit) imm32 = 0xfffff000;
			else imm32 = 0;
			imm32 = imm32 | (imm20 & 0xfffff);
		}

    	if(mem.opcode == 0x67)
		{  //jalr
            pc_next_branch = (alu_out.result & 0xffffffff == pc_curr) ? alu_out.result & 0xffffffff : mem.alu_result;  //performance improvement
            // if branch target is same as what processer fetched, forward alu_result
            // otherwise, don't forward
		}
        else if(branch[0] || branch[1] || branch[2] || branch[3] || branch[4] || branch[5] || branch[6])
		{
            imm32_branch =  imm32 << 1;
            pc_next_branch = id.pc + imm32_branch;
		}
		
		rs1 = (opcode != 0x37 && opcode != 0x17 && opcode != 0x6f) ? (id.inst >> 15) & 0x1f : 0;     //lui, auipc, jal don't use rs1
		rs2 = (opcode != 0x37 && opcode != 0x17 && opcode != 0x6f && opcode != 0x67 && opcode != 0x3 && opcode != 0x13) ? (id.inst >> 20) & 0x1f : 0;     // ld, itype, lui, auipc, jal, jalr don't use rs2
		rd = (id.inst >> 7) & 0x1f;

		//Hazard detection unit
		stall_by_load_use =  ex.mem_read & ((ex.rd == rs1) | (ex.rd == rs2));
    	flush_by_branch =  branch_taken;
    
    	id_flush =  flush_by_branch & (id.pc != pc_next_branch);     //branch_taken and the branch target isn't current pc
    	id_stall =  stall_by_load_use;
	
    	if_flush =  flush_by_branch & (id.pc + 4 != pc_next_branch);          //branch_taken and the branch target isn't fetched pc
    	if_stall =  stall_by_load_use;
    	pc_write =  !(if_flush || if_stall);  //enable pc write only when fetch stage isn't flushed or stalled
		
		regfile_in.rd = wb.rd;
		regfile_in.reg_write = wb.reg_write;
		regfile_in.rs1 = rs1;
		regfile_in.rs2 = rs2;
		regfile_out = regfile(regfile_in);

		//Fetch
		pc_next_plus4 = pc_curr + 4;
    	pc_next_sel = branch_taken; 
    	pc_next = pc_next_sel ? (pc_next_branch != pc_curr) ? pc_next_branch : pc_next_plus4 : pc_next_plus4;
        if (pc_write && cc > 2) pc_curr = pc_next;

		imem_addr = pc_curr >> 2;

		imem_in.addr = imem_addr;
		imem_out = imem(imem_in);
		inst = imem_out.dout;

		cc++;
	}

	show_state(reg_data, dmem_data);

	free(reg_data);
	free(imem_data);
	free(dmem_data);

	return 0;
}