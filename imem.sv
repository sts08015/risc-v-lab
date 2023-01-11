`timescale 1ns/1ps

module imem
#(  parameter IMEM_DEPTH = 1024,    // imem depth (default: 1024 entries = 4 KB)
              IMEM_ADDR_WIDTH = 10 )
(
    input   [IMEM_ADDR_WIDTH-1:0]   addr,
    output  [31:0]  dout
);

    logic   [31:0]  data[0:IMEM_DEPTH-1];

    assign dout = data[addr];

// synthesis translate_off
    initial begin
        for (int i = 0; i < IMEM_DEPTH; i++)
            data[i] = 'b0;
        $readmemb("imem.mem", data);
    end
// synthesis translate_on

endmodule
