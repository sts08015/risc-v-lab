#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vpipeline_cpu.h"

#define CLK_T 10
#define CLK_NUM 60
#define RST_OFF 2	// reset if released after this clock counts

int main(int argc, char** argv, char** env) {
	Vpipeline_cpu *dut = new Vpipeline_cpu;

	// initializing waveform file
	Verilated::traceEverOn(true);
	VerilatedVcdC *m_trace = new VerilatedVcdC;
	dut->trace(m_trace, 5);
	m_trace->open("wave.vcd");

	FILE *fp = fopen("report.txt", "w");

	// test vector
	unsigned int cc = 0;	// clock count
	unsigned int tick = 0;	// half clock
	dut->clk = 1;
	dut->reset_b = 0;
	while (cc < CLK_NUM) {
		dut->clk ^= 1;
		if (cc==RST_OFF) dut->reset_b = 1;
		if (dut->clk==0) {
			cc++;
		}
		dut->eval();
		if ((dut->clk==0) && (cc==CLK_NUM/2)) {
			/*
			for (int i = 0; i < 32; i++) {
				fprintf(fp, "RF[%02d]: %016lx\n", i, dut->pipeline_cpu__DOT__u_regfile_0__DOT__rf_data[i]);
			}
			for (int i = 0; i < 9; i++) {
				fprintf(fp, "DMEM[%02d]: %016lx\n", i, dut->pipeline_cpu__DOT__u_dmem_0__DOT__data[i]);
			}
			*/
		}
		m_trace->dump(tick*CLK_T/2);
		tick++;
	}

	dut->eval();
	m_trace->dump(tick);

	for (int i = 0; i < 32; i++) {
		fprintf(fp, "RF[%02d]: %016lx\n", i, dut->pipeline_cpu__DOT__u_regfile_0__DOT__rf_data[i]);
	}
	for (int i = 0; i < 12; i++) {
		fprintf(fp, "DMEM[%02d]: %016lx\n", i, dut->pipeline_cpu__DOT__u_dmem_0__DOT__data[i]);
	}

	fclose(fp);
	m_trace->close();
	delete dut;
	exit(EXIT_SUCCESS);
}
