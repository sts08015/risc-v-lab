/* **************************************
 * Module: top design of rv32i pipelined processor
 *
 * Author: Dongkyun Lim (sts08015@korea.ac.kr)
 *
 * **************************************
 */

// headers
#ifndef _RV32I_H_
#define _RV32I_H_

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>


// defines
#define REG_WIDTH 32
#define IMEM_DEPTH 1024
#define DMEM_DEPTH 1024

// configs
#define CLK_NUM 50

// structures
struct imem_input_t {
	uint32_t addr;
	uint32_t *imem_data;
};

struct imem_output_t {
	uint32_t dout;
};

struct rf_input_t {
	uint8_t rs1;	//source register 1
	uint8_t rs2;	//source register 2
	uint8_t rd;		//destination register
	uint32_t rd_din;	//input data for rd
	uint8_t reg_write;	//regwrite signal
	uint32_t* rf_data;
};

struct rf_output_t {
	uint32_t rs1_dout;
	uint32_t rs2_dout;
};

struct alu_input_t {
	uint32_t in1;	//Operand 1
	uint32_t in2;	//Operand 2
	uint8_t alu_control;	//ALU control signal
};

struct alu_output_t {
	uint64_t result;	//ALU output
};

struct dmem_input_t {
	uint32_t addr;
	uint32_t din;
	uint8_t mem_read;
	uint8_t mem_write;
	uint32_t *dmem_data;
};

struct dmem_output_t {
	uint32_t dout;
};

// Pipe reg: IF/ID
typedef struct{
    uint32_t pc;
    uint32_t inst;
} pipe_if_id;

// Pipe reg: ID/EX
typedef struct{
    uint32_t pc;
    uint32_t rs1_dout;
    uint32_t rs2_dout;
    uint32_t imm32;
    uint8_t opcode;
    uint8_t funct3;
    uint8_t funct7;
    uint8_t branch[7];
    uint8_t alu_src;
    uint8_t alu_op;
    uint8_t mem_read;
    uint8_t mem_write;
    uint8_t rs1;
    uint8_t rs2;
    uint8_t rd;         // rd for regfile
    uint8_t reg_write;
    uint8_t mem_to_reg;
} pipe_id_ex;

// Pipe reg: EX/MEM
typedef struct{
    uint32_t alu_result; // for address
    uint32_t rs2_dout;   // for store
    uint8_t mem_read;
    uint8_t mem_write;
    uint8_t rd;
    uint8_t reg_write;
	uint8_t mem_to_reg;
    uint8_t funct3;
    uint8_t opcode;
    uint8_t slt;
    uint32_t imm32;
    uint32_t pc;
    uint8_t sign;
    uint8_t carry;
    uint8_t ub;
} pipe_ex_mem;

// Pipe reg: MEM/WB
typedef struct {
    uint32_t alu_result;
    uint32_t dmem_dout;
    uint8_t rd;
	uint8_t reg_write;
    uint8_t mem_to_reg;
    uint8_t funct3;
    uint8_t opcode;
	uint8_t slt;
    uint32_t imm32;
    uint32_t pc;
    uint8_t sign;
    uint8_t carry;
    uint8_t ub;
} pipe_mem_wb;

struct imem_output_t imem(struct imem_input_t imem_in);
struct rf_output_t regfile(struct rf_input_t regfile_in);
struct alu_output_t alu(struct alu_input_t alu_in);
struct dmem_output_t dmem(struct dmem_input_t dmem_in);

void show_state(uint32_t *reg_data, uint32_t *dmem_data);

#endif