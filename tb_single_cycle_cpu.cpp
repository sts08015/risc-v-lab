#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsingle_cycle_cpu.h"

#define CLK_T 10
#define CLK_NUM 45
#define RST_OFF 2	// reset if released after this clock counts

int main(int argc, char** argv, char** env) {
	Vsingle_cycle_cpu *dut = new Vsingle_cycle_cpu;

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
			//printf("CC:%04d alu_control: %04x\n", cc, dut->single_cycle_cpu__DOT__alu_control);
			cc++;
		}
		dut->eval();
		m_trace->dump(tick*CLK_T/2);
		tick++;
	}

	dut->eval();
	m_trace->dump(tick);

	for (int i = 0; i < 32; i++) {
		fprintf(fp, "RF[%02d]: %016lx\n", i, dut->single_cycle_cpu__DOT__u_regfile_0__DOT__rf_data[i]);
	}
	for (int i = 0; i < 12; i++) {
		fprintf(fp, "DMEM[%02d]: %016lx\n", i, dut->single_cycle_cpu__DOT__u_dmem_0__DOT__data[i]);
	}

	fclose(fp);
	m_trace->close();
	delete dut;
	exit(EXIT_SUCCESS);
}
