/* ********************************************
 *	COSE222 Lab #4
 *
 *	Module: pipelined_cpu.sv
 *  - Top design of the 5-stage pipelined RISC-V processor
 *
 *  Author: Dongkyun Lim (sts08015@korea.ac.kr)
 *
 * ********************************************
 */

`timescale 1ns/1ps

// Packed structures for pipeline registers
// Pipe reg: IF/ID
typedef struct packed {
    logic   [31:0]  pc;
    logic   [31:0]  inst;
} pipe_if_id;

// Pipe reg: ID/EX
typedef struct packed {
    logic   [31:0]  pc;
    logic   [31:0]  rs1_dout;
    logic   [31:0]  rs2_dout;
    logic   [31:0]  imm32;
    logic   [6:0]   opcode;
    logic   [2:0]   funct3;
    logic   [6:0]   funct7;
    logic   [6:0]   branch;
    logic           alu_src;
    logic   [1:0]   alu_op;
    logic           mem_read;
    logic           mem_write;
    logic   [4:0]   rs1;
    logic   [4:0]   rs2;
    logic   [4:0]   rd;         // rd for regfile
    logic           reg_write;
    logic           mem_to_reg;
} pipe_id_ex;

// Pipe reg: EX/MEM
typedef struct packed {
    logic   [31:0]  alu_result; // for address
    logic   [31:0]  rs2_dout;   // for store
    logic           mem_read;
    logic           mem_write;
    logic   [4:0]   rd;
    logic           reg_write;
    logic           mem_to_reg;
    logic   [2:0]   funct3;
    logic   [6:0]   opcode;
    logic           slt;
} pipe_ex_mem;

// Pipe reg: MEM/WB
typedef struct packed {
    logic   [31:0]  alu_result;
    logic   [31:0]  dmem_dout;
    logic   [4:0]   rd;
    logic           reg_write;
    logic           mem_to_reg;
    logic   [2:0]   funct3;
    logic   [6:0]   opcode;
    logic           slt;
} pipe_mem_wb;

/* verilator lint_off UNUSED */
module pipeline_cpu
#(  parameter IMEM_DEPTH = 1024,    // imem depth (default: 1024 entries = 4 KB)
              IMEM_ADDR_WIDTH = 10,
              REG_WIDTH = 32,
              DMEM_DEPTH = 1024,    // dmem depth (default: 1024 entries = 8 KB)
              DMEM_ADDR_WIDTH = 10 )
(
    input           clk,            // System clock
    input           reset_b         // Asychronous negative reset
);

    // -------------------------------------------------------------------
    /* Instruction fetch stage:
     * - Accessing the instruction memory with PC
     * - Control PC udpates for pipeline stalls
     */

    // Program counter
    logic           pc_write;   // enable PC updates
    logic   [31:0]  pc_curr, pc_next;
    logic   [31:0]  pc_next_plus4, pc_next_branch;
    logic           pc_next_sel;
    logic           branch_taken;
    //logic           regfile_zero;   // zero detection from regfile, REMOVED

    assign pc_next_plus4 = pc_curr + 4;
    assign pc_next_sel = branch_taken; 
    assign pc_next = pc_next_sel ? pc_next_branch : pc_next_plus4;

    always_ff @ (posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            pc_curr <= 'b0;
        end else begin
             if (pc_write) begin
                pc_curr <= pc_next;
             end
        end
    end

    // imem
    logic   [IMEM_ADDR_WIDTH-1:0]   imem_addr;
    logic   [31:0]  inst;
    
    assign imem_addr = pc_curr[IMEM_ADDR_WIDTH+1:2];    //bc pc is multiple of 4

    // instantiation: instruction memory
    imem #(
        .IMEM_DEPTH         (IMEM_DEPTH),
        .IMEM_ADDR_WIDTH    (IMEM_ADDR_WIDTH)
    ) u_imem_0 (
        .addr               (imem_addr),
        .dout               (inst)
    );
    // -------------------------------------------------------------------

    // -------------------------------------------------------------------
    /* IF/ID pipeline register
     * - Supporting pipeline stalls and flush
     */
    pipe_if_id      id;
    pipe_id_ex      ex;
    pipe_ex_mem     mem;
    pipe_mem_wb     wb;

    logic           if_flush, if_stall;

    always_ff @ (posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            id <= 'b0;
        end else begin
            if (if_flush) begin
                id <= 'b0;
            end else if (~if_stall) begin
                id.pc <=  pc_curr; 
                id.inst <=  inst; 
            end //if stall, do nothing, just remain same
        end
    end
    // -------------------------------------------------------------------

    // ------------------------------------------------------------------
    /* Instruction decoder stage:
     * - Generating control signals
     * - Register file
     * - Immediate generator
     * - Hazard detection unit
     */
    
    // -------------------------------------------------------------------
    /* Main control unit:
     * Main control unit generates control signals for datapath elements
     * The control signals are determined by decoding instructions
     * Generating control signals using opcode = inst[6:0]
     */
    logic   [6:0]   opcode;
    logic   [6:0]   branch;
    logic           alu_src, mem_to_reg;
    logic   [1:0]   alu_op;
    logic           mem_read, mem_write, reg_write; // declared above
    logic   [6:0]   funct7;
    logic   [2:0]   funct3;

    // COMPLETE THE MAIN CONTROL UNIT HERE
    assign opcode = id.inst[6:0];
    assign funct3 = id.inst[14:12];
    assign funct7 = id.inst[31:25];

    always_comb begin
        if(opcode == 7'b1100011) begin  //conditional branch
            branch[0] = (funct3 == 3'b000);    //beq
            branch[1] = (funct3 == 3'b001);    //bne
            branch[2] = (funct3 == 3'b100);    //blt
            branch[3] = (funct3 == 3'b101);    //bge
            branch[4] = (funct3 == 3'b110);    //bltu
            branch[5] = (funct3 == 3'b111);    //bgeu
        end
        else if(opcode == 7'b1101111 || opcode == 7'b1100111) begin    //unconditional branch (jal, jalr)
            branch[6] = 1'b1;
        end
        else begin
            branch = 7'b0;
        end
    end

    assign mem_read = (opcode == 7'b0000011);    // ld
    assign mem_write = (opcode == 7'b0100011);   // sd
    assign mem_to_reg = mem_read;
    assign reg_write = (opcode == 7'b0000011||opcode == 7'b0110011||opcode == 7'b0010011||opcode == 7'b1100111||opcode == 7'b1101111||opcode == 7'b0110111||opcode == 7'b0010111);
    assign alu_src = (opcode == 7'b0000011||opcode == 7'b0100011||opcode == 7'b0010011||opcode == 7'b1100111||opcode == 7'b1101111||opcode == 7'b0010111);

    always_comb begin
        case(opcode)
            7'b0000011: begin    //loads
                alu_op = 2'b00;
            end
            7'b0100011: begin    //stores
                alu_op = 2'b00;
            end
            7'b1100011: begin    //conditinal branches
                alu_op = 2'b01;
            end
            7'b0110011: begin    //rtype
                alu_op = 2'b10;
            end
            7'b0010011: begin   //itype
                alu_op = 2'b11;
            end
            7'b1101111: begin   //jal
                alu_op = 2'b00;
            end
            7'b1100111: begin   //jalr
                alu_op = 2'b00;
            end
            7'b0010111: begin   //auipc
                alu_op = 2'b00;
            end
            default: begin
                alu_op = 2'b00;
            end
        endcase
    end
    // --------------------------------------------------------------------

    // ---------------------------------------------------------------------
    /* Immediate generator:
     * Generating immediate value from inst[31:0]
     */
    logic   [31:0]  imm32;
    logic   [31:0]  imm32_branch;  // imm64 left shifted by 1

    // COMPLETE IMMEDIATE GENERATOR HERE
    logic   [11:0]  imm12;
    logic   [19:0]  imm20;  // 20-bit immediate value --> for unconditional branch, upper immediate
    logic   imm_flag;

    always_comb begin
        case(opcode)
            7'b0000011: begin   //ld
                imm12 = id.inst[31:20];
                imm_flag = 1'b1;
            end
            7'b0100011: begin   //sd
                imm12[11:5] = id.inst[31:25];
                imm12[4:0] = id.inst[11:7];
                imm_flag = 1'b1;
            end
            7'b0010011: begin   //i-type
                imm12 = id.inst[31:20];
                if(funct3 == 3'b101) begin    //slli, srli, srai
                    imm12 = {7'd0,imm12[4:0]};
                end
                imm_flag = 1'b1;
            end
            7'b1100011: begin   //conditional branch
                imm12[11] = id.inst[31];
                imm12[9:4] = id.inst[30:25];
                imm12[3:0] = id.inst[11:8];
                imm12[10] = id.inst[7];
                imm_flag = 1'b1;
            end
            7'b1101111: begin //unconditional branch - jal
                imm20[19] = id.inst[31];
                imm20[9:0] = id.inst[30:21];
                imm20[10] = id.inst[20];
                imm20[18:11] = id.inst[19:12];
                imm_flag = 1'b0;
            end
            7'b1100111: begin   //unconditional branch - jalr
                imm12 = id.inst[31:20];
                imm_flag = 1'b1;
            end
            7'b0010111: begin   //auipc
                imm20 = id.inst[31:12];
                imm_flag = 1'b0;
            end
            7'b0110111: begin   //lui
                imm20 = id.inst[31:12];
                imm_flag = 1'b0;
            end
            default: begin
            end
        endcase
    end

    always_comb begin
        if(imm_flag) begin
            if((opcode == 7'b0010011 && funct3 == 3'b011) && (opcode == 7'b1100011 && (funct3 == 3'b110 || funct3 == 3'b111))) begin
                imm32 = {20'd0,imm12};         //bit extension (unsigned)
            end
            else begin
                imm32 = {{20{imm12[11]}},imm12};    //sign extension
            end
        end
        else begin
            imm32 = {{12{imm20[19]}},imm20};    //sign extension
        end
    end

    // Computing branch target
    always_comb begin
            if(mem.opcode == 7'b1100111) begin  //jalr  TODO: improve performance when jalr
                pc_next_branch = mem.alu_result;
            end
            else begin
                imm32_branch =  {imm32[30:0],1'b0}; //imm32 << 1;
                pc_next_branch = id.pc + imm32_branch;
            end
    end

    // ----------------------------------------------------------------------

    // ----------------------------------------------------------------------
    /* Hazard detection unit
     * - Detecting data hazards from load instrcutions
     * - Detecting control hazards from taken branches
     */
    logic   [4:0]   rs1, rs2;

    logic           stall_by_load_use;
    logic           flush_by_branch;
    
    logic           id_stall, id_flush;


    assign stall_by_load_use =  ex.mem_read & ((ex.rd == rs1) | (ex.rd == rs2));
    assign flush_by_branch =  branch_taken;
    
    assign id_flush =  flush_by_branch & (pc_curr != pc_next_branch);     //branch_taken and the branch target isn't current pc
    assign id_stall =  stall_by_load_use;
	
    assign if_flush =  flush_by_branch & (pc_next_plus4 != pc_next_branch);          //branch_taken and the branch target isn't fetched pc
    assign if_stall =  stall_by_load_use;
    assign pc_write =  ~(if_flush | if_stall);  //enable pc write only when fetch stage isn't flushed or stalled

    // ----------------------------------------------------------------------


    // regfile/
    logic   [4:0]   rd;    // register numbers
    logic   [REG_WIDTH-1:0] rd_din;
    logic   [REG_WIDTH-1:0] rs1_dout, rs2_dout;
    
    assign rs1 =  id.inst[19:15];     // our processor does NOT support U and UJ types
    assign rs2 =  id.inst[24:20];     // consider ld and i-type
    assign rd =  id.inst[11:7];
    // rd, rd_din, and reg_write will be determined in WB stage
    
    // instantiation of register file
    regfile #(
        .REG_WIDTH          (REG_WIDTH)
    ) u_regfile_0 (
        .clk                (clk),
        .rs1                (rs1),
        .rs2                (rs2),
        .rd                 (wb.rd),
        .rd_din             (rd_din),
        .reg_write          (wb.reg_write),
        .rs1_dout           (rs1_dout), //output
        .rs2_dout           (rs2_dout)  //output
    );
    // ------------------------------------------------------------------

    // -------------------------------------------------------------------
    /* ID/EX pipeline register
     * - Supporting pipeline stalls
     */
    //pipe_id_ex      ex;         // THINK WHY THIS IS EX...

    always_ff @ (posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            ex <= 'b0;
        end else begin
            if (id_flush) begin
                ex <= 'b0;
            end else if(~id_stall) begin
                ex.pc <= id.pc; //current inst's pc
                ex.rs1_dout <= rs1_dout;
                ex.rs2_dout <= rs2_dout;
                ex.imm32 <= imm32;
                ex.opcode <= opcode;
                ex.funct3 <= funct3;
                ex.funct7 <= funct7;
                ex.branch <= branch;
                ex.alu_src <= alu_src;
                ex.alu_op <= alu_op;
                ex.mem_read <= mem_read;
                ex.mem_write <= mem_write;
                ex.rs1 <= rs1;
                ex.rs2 <= rs2;
                ex.rd <= rd;
                ex.reg_write <= reg_write;
                ex.mem_to_reg <= mem_to_reg;
            end else begin  //if stall, only update signals
                //don't update branch bc then it may flush inst before ex stage
                //ex.pc <= id.pc;
                //ex.rs1_dout <= rs1_dout;
                //ex.rs2_dout <= rs2_dout;
                //ex.imm32 <= imm32;
                //ex.opcode <= opcode;
                //ex.funct3 <= funct3;
                //ex.funct7 <= funct7;
                //ex.branch <= branch;
                //ex.alu_src <= alu_src;
                //ex.alu_op <= alu_op;
                ex.mem_read <= mem_read;    //should update mem_read to escape stalled stage
                ex.mem_write <= mem_write;
                //ex.rs1 <= rs1;
                //ex.rs2 <= rs2;
                //ex.rd <= rd;
                ex.reg_write <= reg_write;
                ex.mem_to_reg <= mem_to_reg;
            end
        end
    end
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    /* Execution stage:
     * - ALU & ALU control
     * - Data forwarding unit
     */

    // --------------------------------------------------------------------
    /* ALU control unit:
     * ALU control unit generate alu_control signal which selects ALU operations
     * Generating control signals using alu_op, funct7, and funct3 fileds
     */

    logic   [3:0]   alu_control;    // ALU control signal

    // COMPLETE ALU CONTROL UNIT
	logic slt;
    always_comb begin
        if(ex.alu_op == 2'b00) begin
            alu_control = 4'b0010;  //add
            slt = 1'b0;
        end
        else if(ex.alu_op == 2'b01) begin  //conditional branches
            alu_control = 4'b0110;      //sub --> to compare
            slt = 1'b0;
        end
        else begin
            if(ex.funct3 == 3'd0 && ((ex.alu_op == 2'b10 && ex.funct7 == 7'd0) || (ex.alu_op == 2'b11))) begin  //add
                alu_control = 4'b0010;
                slt = 1'b0;
            end
            else if(ex.funct3 == 3'd0 && ex.funct7 == 7'b0100000) begin //sub
                alu_control = 4'b0110;
                slt = 1'b0;
            end
            else if(ex.funct3 == 3'b111 && ex.funct7 == 7'd0) begin   //and
                alu_control = 4'b0000;
                slt = 1'b0;
            end
            else if(ex.funct3 == 3'b110) begin   //or
                alu_control = 4'b0001;
                slt = 1'b0;
            end
            else if(ex.funct3 == 3'b100) begin   //xor
                alu_control = 4'b0011;
                slt = 1'b0;
            end
            else if(ex.funct3 == 3'b001 && ex.funct7 == 7'd0) begin   //shift left
                alu_control = 4'b0111;
                slt = 1'b0;
            end
            else if(ex.funct3 == 3'b101 && ex.funct7 == 7'd0) begin   //shift right
                alu_control = 4'b1000;
                slt = 1'b0;
            end
            else if(ex.funct3 == 3'b101 && ex.funct7 == 7'b0100000) begin //shift right arithmetic
                alu_control = 4'b1001;
                slt = 1'b0;
            end
            else if(ex.funct3 == 3'b010 || ex.funct3 == 3'b011) begin //set less than
                alu_control = 4'b0110;
                slt = 1'b1;
            end
        end
    end
    // ---------------------------------------------------------------------

    // ----------------------------------------------------------------------
    /* Forwarding unit:
     * - Forwarding from EX/MEM and MEM/WB
     */
    logic   [1:0]   forward_a, forward_b;   //forward_a : foward data to rs1
    logic   [REG_WIDTH-1:0]  alu_fwd_in1, alu_fwd_in2;   // outputs of forward MUXes

	/* verilator lint_off CASEX */
   always_comb begin
        case (forward_a)
           2'b00 : alu_fwd_in1 = ex.rs1_dout;
           2'b10 : alu_fwd_in1 = mem.alu_result;    //EX-MEM -> ID-EX
           2'b01 : alu_fwd_in1 = rd_din;            //MEM-WB -> ID-EX
           default: begin
           end
        endcase
    end

    always_comb begin
        case (forward_b)
           2'b00 : alu_fwd_in2 = ex.rs2_dout;
           2'b10 : alu_fwd_in2 = mem.alu_result;
           2'b01 : alu_fwd_in2 = rd_din;
           default: begin
           end
        endcase
    end

	/* verilator lint_on CASEX */
    // Need to prioritize forwarding conditions
    /*
        Below is the example of when the prioritazation of forwarding condition is needed.
        Data forwarding condition met at end of EX stage should be prioritized.
        add x1 x2 x3
        add x1 x1 x2
        add x5 x2 x1
    */

    always_comb begin
        if(mem.reg_write & (mem.rd == ex.rs1) & (mem.rd != 0)) begin
            assign forward_a = 2'b10;   //EX-MEM -> ID-EX
        end else if (wb.reg_write & (wb.rd == ex.rs1)) begin    //& (wb.rd != 0)
            assign forward_a = 2'b01;   //MEM-WB -> ID-EX
        end else begin
            assign forward_a = 2'b00;
        end
    end

    always_comb begin
        if(mem.reg_write & (mem.rd == ex.rs2)) begin    //& (mem.rd != 0)
            assign forward_b = 2'b10;   //EX-MEM -> ID-EX
        end else if (wb.reg_write & (wb.rd == ex.rs2)) begin    //& (wb.rd != 0)
            assign forward_b = 2'b01;   //MEM-WB -> ID-EX
        end else begin
            assign forward_b = 2'b00;
        end
    end
    // -----------------------------------------------------------------------

    // ALU
    logic   [REG_WIDTH-1:0] alu_in1, alu_in2;
    logic   [REG_WIDTH-1:0] alu_result;
    //logic           alu_zero;   // will not be used

    //unconditional branch or (LUI or AUIPC)
    assign alu_in1 = (ex.branch[6] || ex.opcode == 7'b0010111) ? ex.pc : alu_fwd_in1;
    assign alu_in2 =  ex.alu_src ? ex.imm32 : alu_fwd_in2;

    // instantiation: ALU
    alu #(
        .REG_WIDTH          (REG_WIDTH)
    ) u_alu_0 (
        .in1                (alu_in1),
        .in2                (alu_in2),
        .alu_control        (alu_control),
        .result             (alu_result)
        //.zero               (alu_zero),	// REMOVED
		//.sign				(alu_sign)		// REMOVED
    );

    // branch unit (BU)
    //logic   [REG_WIDTH-1:0] sub_for_branch;
    logic           bu_zero, bu_sign;
    //logic           branch_taken;

    //assign sub_for_branch =  /* FILL THIS */ 
    assign bu_zero =  ~(|alu_result); 
    assign bu_sign =  alu_result[REG_WIDTH-1];

    always_comb begin
        if(ex.branch[0] == 1'b1) begin //beq
            branch_taken = bu_zero;
        end
        else if(ex.branch[1] == 1'b1) begin    //bne
            branch_taken = ~bu_zero;
        end
        else if(ex.branch[2] == 1'b1) begin    //blt
            branch_taken = bu_sign;
        end
        else if(ex.branch[3] == 1'b1) begin    //bge
            branch_taken = (~bu_sign | bu_zero);
        end
        else if(ex.branch[4] == 1'b1) begin    //bltu
            branch_taken = bu_sign;
        end
        else if(ex.branch[5] == 1'b1) begin    //bgeu
            branch_taken = (~bu_sign | bu_zero);
        end
        else if(ex.branch[6] == 1'b1) begin    //unconditional branch (jal, jalr)
            branch_taken = 1'b1;
        end else begin
            branch_taken = 1'b0;
        end
    end
    // -------------------------------------------------------------------------
    /* Ex/MEM pipeline register
     */
    //pipe_ex_mem     mem;

    always_ff @ (posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            mem <= 'b0;
        end else begin
            mem.alu_result <= alu_result;
            mem.rs2_dout <= alu_fwd_in2;    //for store op, inputs for alu and mem are different. imm, reg, respectively.
            mem.mem_read <= ex.mem_read;
            mem.mem_write <= ex.mem_write;
            mem.rd <= ex.rd;
            mem.reg_write <= ex.reg_write;
            mem.mem_to_reg <= ex.mem_to_reg;
            mem.funct3 <= ex.funct3;
            mem.opcode <= ex.opcode;
            mem.slt <= slt;
        end
    end

    // --------------------------------------------------------------------------
    /* Memory srage
     * - Data memory accesses
     */

    // dmem
    logic   [DMEM_ADDR_WIDTH-1:0]    dmem_addr;
    logic   [31:0]  dmem_din, dmem_dout;

    assign dmem_addr = mem.alu_result[DMEM_ADDR_WIDTH+1:2]; //alu_result >> 2; //32bit-dmem
    always_comb begin
        if(mem.funct3 == 3'b000) begin  //sb
            dmem_din = {24'd0, mem.rs2_dout[7:0]};
        end
        else if(mem.funct3 == 3'b001) begin //sh
            dmem_din = {16'd0, mem.rs2_dout[15:0]};
        end
        else begin  //sw
            dmem_din = mem.rs2_dout;
        end
    end
    
    // instantiation: data memory
    dmem #(
        .DMEM_DEPTH         (DMEM_DEPTH),
        .DMEM_ADDR_WIDTH    (DMEM_ADDR_WIDTH)
    ) u_dmem_0 (
        .clk                (clk),
        .addr               (dmem_addr),
        .din                (dmem_din),
        .mem_read           (mem.mem_read),
        .mem_write          (mem.mem_write),
        .dout               (dmem_dout)
    );

    // -----------------------------------------------------------------------
    /* MEM/WB pipeline register
     */

    //pipe_mem_wb         wb;

    always_ff @ (posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            wb <= 'b0;
        end else begin
            wb.alu_result <= mem.alu_result;
            wb.dmem_dout <= dmem_dout;
            wb.rd <= mem.rd;
            wb.reg_write <= mem.reg_write;
            wb.mem_to_reg <= mem.mem_to_reg;
            wb.funct3 <= mem.funct3;
            wb.opcode <= mem.opcode;
            wb.slt <= mem.slt;
        end
    end

    // ----------------------------------------------------------------------
    /* Writeback stage
     * - Write results to regsiter file
     */
    
    //assign rd_din =  wb.mem_to_reg ? wb.dmem_dout : wb.alu_result;  //TODO

    
    always_comb begin
        if(branch[6]) begin //unconditional branch (jal, jalr)
            rd_din = pc_next_plus4;
        end
        else if(wb.mem_to_reg) begin
            if(wb.funct3 == 3'd0) begin    //lb
                rd_din = {{24{wb.dmem_dout[7]}},wb.dmem_dout[7:0]};   //sign-extension
            end
            else if(wb.funct3 == 3'b001) begin //lh
                rd_din = {{16{wb.dmem_dout[15]}},wb.dmem_dout[15:0]};   //sign-extension
            end
            else if(wb.funct3 == 3'b100) begin //lbu
                rd_din = {24'd0,wb.dmem_dout[7:0]};
            end
            else if(funct3 == 3'b101) begin //lhu
                rd_din = {16'd0,wb.dmem_dout[15:0]};
            end
            else begin  //lw
                rd_din = wb.dmem_dout;
            end
        end
        else if(wb.slt) begin
            if(wb.opcode == 7'b0110011 && wb.funct3 == 3'b011) begin    //sltu
                rd_din = {31'd0,alu_carry};
            end
            else begin
                rd_din = {31'd0,alu_sign};
            end
        end
        else if(wb.opcode == 7'b0110111) begin //lui
            rd_din = imm32 << 12;
        end
        else begin
            rd_din = wb.alu_result;
        end
    end
endmodule
