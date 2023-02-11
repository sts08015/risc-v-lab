/* **************************************
 * Module: top design of rv32i single-cycle processor
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
#define CLK_NUM 45

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
	uint32_t result;	//ALU output
	uint8_t zero;		//Zero detection
	uint8_t sign;		//Sign bit
	uint8_t carry;		//carry flag
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

struct imem_output_t imem(struct imem_input_t imem_in);
struct rf_output_t regfile(struct rf_input_t regfile_in);
struct alu_output_t alu(struct alu_input_t alu_in);
struct dmem_output_t dmem(struct dmem_input_t dmem_in);

void show_state(uint32_t *reg_data, uint32_t *dmem_data);

#endif