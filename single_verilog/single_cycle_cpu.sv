/* ********************************************
 *	Extended Version of COSE222 Lab #3
 *
 *	Module: top design of the single-cycle CPU (single_cycle_cpu.sv)
 *  - Top design of the single-cycle CPU
 *
 *  Author: DongKyun Lim (sts08015@korea.ac.kr)
 *
 * ********************************************
 */

`timescale 1ns/1ps

module single_cycle_cpu
#(  parameter IMEM_DEPTH = 1024,    // imem depth (default: 1024 entries = 4 KB)
              IMEM_ADDR_WIDTH = 10,
              REG_WIDTH = 32,
              DMEM_DEPTH = 1024,    // dmem depth (default: 1024 entries = 8 KB)
              DMEM_ADDR_WIDTH = 10 )
(
    input           clk,            // System clock
    input           reset_b         // Asychronous negative reset
);

    // Wires for datapath elements
    logic   [IMEM_ADDR_WIDTH-1:0]   imem_addr;
    logic   [31:0]  inst;   // instructions = an output of ????

    logic   [4:0]   rs1, rs2, rd;    // register numbers
    logic   [REG_WIDTH-1:0] rd_din;
    logic           reg_write;
    logic   [REG_WIDTH-1:0] rs1_dout, rs2_dout;

    logic   [REG_WIDTH-1:0] alu_in1, alu_in2;
    logic   [3:0]   alu_control;    // ALU control signal
    logic   [REG_WIDTH-1:0] alu_result;
    logic           alu_zero;
    logic           alu_sign;
    logic           alu_carry;

    logic   [DMEM_ADDR_WIDTH-1:0]    dmem_addr;
    logic   [31:0]  dmem_din, dmem_dout;
    logic           mem_read, mem_write;

    // -------------------------------------------------------------------
    /* Main control unit:
     * Main control unit generates control signals for datapath elements
     * The control signals are determined by decoding instructions
     */
    logic   [6:0]   opcode;
    logic   [6:0]   branch;
    logic           alu_src, mem_to_reg;
    logic   [1:0]   alu_op;
    logic   [2:0]   funct3;
    
    assign opcode = inst[6:0];
    assign funct3 = inst[14:12];

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
    assign mem_to_reg = (opcode == 7'b0000011);   //ld
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

    /* ALU control unit:
     * ALU control unit generate alu_control signal which selects ALU operations
     * Generating control signals using alu_op, funct7, and funct3 fields
     */
    logic   [6:0]   funct7;

    assign funct7 = inst[REG_WIDTH-1:25];
    logic slt;
    always_comb begin
        if(alu_op == 2'b00) begin
            alu_control = 4'b0010;  //add
            slt = 1'b0;
        end
        else if(alu_op == 2'b01) begin  //conditional branches
            alu_control = 4'b0110;      //sub --> to compare
            slt = 1'b0;
        end
        else begin
            if(funct3 == 3'd0 && ((alu_op == 2'b10 && funct7 == 7'd0) || (alu_op == 2'b11))) begin  //add
                alu_control = 4'b0010;
                slt = 1'b0;
            end
            else if(funct3 == 3'd0 && funct7 == 7'b0100000) begin //sub
                alu_control = 4'b0110;
                slt = 1'b0;
            end
            else if(funct3 == 3'b111 && funct7 == 7'd0) begin   //and
                alu_control = 4'b0000;
                slt = 1'b0;
            end
            else if(funct3 == 3'b110) begin   //or
                alu_control = 4'b0001;
                slt = 1'b0;
            end
            else if(funct3 == 3'b100) begin   //xor
                alu_control = 4'b0011;
                slt = 1'b0;
            end
            else if(funct3 == 3'b001 && funct7 == 7'd0) begin   //shift left
                alu_control = 4'b0111;
                slt = 1'b0;
            end
            else if(funct3 == 3'b101 && funct7 == 7'd0) begin   //shift right
                alu_control = 4'b1000;
                slt = 1'b0;
            end
            else if(funct3 == 3'b101 && funct7 == 7'b0100000) begin //shift right arithmetic
                alu_control = 4'b1001;
                slt = 1'b0;
            end
            else if(funct3 == 3'b010 || funct3 == 3'b011) begin //set less than
                alu_control = 4'b0110;
                slt = 1'b1;
            end
        end
    end

    /* Immediate generator:
     * Generating immediate value from inst[31:0]
     */
    logic   [REG_WIDTH-1:0]  imm32;
    logic   [REG_WIDTH-1:0]  imm32_branch;  // imm32 left shifted by 1
    logic   [11:0]  imm12;  // 12-bit immediate value extracted from inst
    logic   [19:0]  imm20;  // 20-bit immediate value --> for unconditional branch, upper immediate
    logic   imm_flag;

    always_comb begin
        case(opcode)
            7'b0000011: begin   //ld
                imm12 = inst[31:20];
                imm_flag = 1'b1;
            end
            7'b0100011: begin   //sd
                imm12[11:5] = inst[31:25];
                imm12[4:0] = inst[11:7];
                imm_flag = 1'b1;
            end
            7'b0010011: begin   //i-type
                imm12 = inst[31:20];
                if(funct3 == 3'b101) begin    //slli, srli, srai
                    imm12 = {7'd0,imm12[4:0]};
                end
                imm_flag = 1'b1;
            end
            7'b1100011: begin   //conditional branch
                imm12[11] = inst[31];
                imm12[9:4] = inst[30:25];
                imm12[3:0] = inst[11:8];
                imm12[10] = inst[7];
                imm_flag = 1'b1;
            end
            7'b1101111: begin //unconditional branch - jal
                imm20[19] = inst[31];
                imm20[9:0] = inst[30:21];
                imm20[10] = inst[20];
                imm20[18:11] = inst[19:12];
                imm_flag = 1'b0;
            end
            7'b1100111: begin   //unconditional branch - jalr
                imm12 = inst[31:20];
                imm_flag = 1'b1;
            end
            7'b0010111: begin   //auipc
                imm20 = inst[31:12];
                imm_flag = 1'b0;
            end
            7'b0110111: begin   //lui
                imm20 = inst[31:12];
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
        end else begin
            imm32 = {{12{imm20[19]}},imm20};    //sign extension
        end
    end
    
    // Program counter
    logic   [31:0]  pc_curr, pc_next;
    logic           pc_next_sel;    // selection signal for pc_next
    logic   [31:0]  pc_next_plus4, pc_next_branch;

    assign pc_next_plus4 = pc_curr + 4;

    always_ff @ (posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            pc_curr <= 'b0;
        end else begin
            pc_curr <= pc_next;
        end
    end

    // PC_NEXT

    always_comb begin
        if(branch[0] == 1'b1) begin //beq
            pc_next_sel = alu_zero;
        end
        else if(branch[1] == 1'b1) begin    //bne
            pc_next_sel = ~alu_zero;
        end
        else if(branch[2] == 1'b1) begin    //blt
            pc_next_sel = alu_sign;
        end
        else if(branch[3] == 1'b1) begin    //bge
            pc_next_sel = (~alu_sign || alu_zero);
        end
        else if(branch[4] == 1'b1) begin    //bltu
            pc_next_sel = alu_carry;
        end
        else if(branch[5] == 1'b1) begin    //bgeu
            pc_next_sel = (~alu_carry || alu_zero);
        end
        else if(branch[6] == 1'b1) begin    //unconditional branch (jal, jalr)
            pc_next_sel = 1'b1;
        end
        else begin
            pc_next_sel = 1'b0;
        end
    end

    always_comb begin
            if(opcode == 7'b1100111) begin  //jalr
                pc_next_branch = alu_result;
            end
            else begin
                imm32_branch = imm32 << 1;
                pc_next_branch = pc_curr + imm32_branch;
            end
    end
    assign pc_next = (pc_next_sel) ? pc_next_branch : pc_next_plus4; // if branch is taken, pc_next_sel=1'b1

    // ALU inputs
    assign alu_in1 = ((branch[6] && opcode == 7'b1101111) || opcode == 7'b0010111) ? pc_curr : rs1_dout;
    assign alu_in2 = alu_src ? imm32 : rs2_dout;

    // RF din
    always_comb begin
        if(branch[6]) begin
            rd_din = pc_next_plus4;
        end
        else if(mem_to_reg) begin
            if(funct3 == 3'd0) begin    //lb
                rd_din = {{24{dmem_dout[7]}},dmem_dout[7:0]};   //sign-extension
            end
            else if(funct3 == 3'b001) begin //lh
                rd_din = {{16{dmem_dout[15]}},dmem_dout[15:0]};   //sign-extension
            end
            else if(funct3 == 3'b100) begin //lbu
                rd_din = {24'd0,dmem_dout[7:0]};
            end
            else if(funct3 == 3'b101) begin //lhu
                rd_din = {16'd0,dmem_dout[15:0]};
            end
            else begin  //lw
                rd_din = dmem_dout;
            end
        end
        else if(slt) begin
            if(opcode == 7'b0110011 && funct3 == 3'b011 && funct7 == 7'd0) begin    //sltu
                rd_din = {31'd0,alu_carry};
            end
            else begin
                rd_din = {31'd0,alu_sign};
            end
        end
        else if(opcode == 7'b0110111) begin //lui
            rd_din = imm32 << 12;
        end
        else begin
            rd_din = alu_result;
        end
    end

    // imem
    assign imem_addr = pc_curr[IMEM_ADDR_WIDTH+1:2];    //32bit-imem
    
    // regfile
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd = inst[11:7];

    // dmem
    assign dmem_addr = alu_result[DMEM_ADDR_WIDTH+1:2]; //32bit-dmem
    always_comb begin
        if(funct3 == 3'b000) begin  //sb
            dmem_din = {24'd0,rs2_dout[7:0]};
        end
        else if(funct3 == 3'b001) begin //sh
            dmem_din = {16'd0,rs2_dout[15:0]};
        end
        else begin  //sw
            dmem_din = rs2_dout;
        end
    end
 
    /* Instantiation of datapath elements*/
    
    // IMEM
    imem #(
        .IMEM_DEPTH         (IMEM_DEPTH),
        .IMEM_ADDR_WIDTH    (IMEM_ADDR_WIDTH)
    ) u_imem_0 (
        .addr               (imem_addr),
        .dout               (inst)
    );

    // REGFILE
    regfile #( 
        .REG_WIDTH      (REG_WIDTH)
    ) u_regfile_0 (
        .clk            (clk), 
        .rs1            (rs1), 
        .rs2            (rs2), 
        .rd             (rd), 
        .rd_din         (rd_din), 
        .reg_write      (reg_write), 
        .rs1_dout       (rs1_dout), 
        .rs2_dout       (rs2_dout)
    );
    // ALU
    alu #(
        .REG_WIDTH          (REG_WIDTH)
    ) u_alu_0 (
        .in1                (alu_in1),            
        .in2                (alu_in2),            
        .alu_control        (alu_control),        
        .result             (alu_result),         
        .zero               (alu_zero),
        .sign               (alu_sign),
        .carry              (alu_carry)          
    );

    // DMEM
    dmem #(
        .DMEM_DEPTH         (DMEM_DEPTH),
        .DMEM_ADDR_WIDTH    (DMEM_ADDR_WIDTH)
    ) u_dmem_0 (
        .clk            (clk),
        .addr           (dmem_addr),
        .din            (dmem_din),
        .mem_read       (mem_read),
        .mem_write      (mem_write),
        .dout           (dmem_dout)
    );

endmodule