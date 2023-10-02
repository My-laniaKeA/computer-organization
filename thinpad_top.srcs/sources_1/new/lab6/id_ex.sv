`include "define.sv"

module id_ex(
    input wire clk_i,
    input wire rst_i,
    input wire [5:0] stall,
    input wire flush,
    
    input wire  [`AluOpBUS]  id_aluop,
    input wire  [`DATABUS] id_reg1,
    input wire  [`DATABUS] id_reg2,
    input wire  [`RegBUS]  id_waddr,
    input wire  id_we,
    input wire  [2:0] id_imm_type,
	input wire	[`DATABUS] id_imm,
    input wire  id_use_reg1,
    input wire  id_use_reg2,
    input wire  id_mem_en,
    input wire  [3:0] id_mem_sel,
    input wire  [31:0] id_inst,
    input wire  [31:0] id_pc,
    input wire  id_in_delayslot,
    input wire  next_in_delayslot_i,
	input wire	id_reset_dcache_i,
    input wire             id_csr_we,
    input wire[`DATABUS]   id_csr_addr,
    input wire[`DATABUS]   id_exception,

    output reg  [`AluOpBUS]  ex_aluop,
    output reg  [`DATABUS] ex_reg1,
    output reg  [`DATABUS] ex_reg2,
    output reg  [`RegBUS]  ex_waddr,
    output reg  ex_we,
    output reg  [2:0] ex_imm_type,
	output reg	[`DATABUS] ex_imm,
    output reg  ex_use_reg1,
    output reg  ex_use_reg2,
    output reg  ex_mem_en,
    output reg  [3:0] ex_mem_sel,
    output reg  [31:0] ex_inst,
    output reg  [31:0] ex_pc,
    output reg  ex_in_delayslot,
    output reg  in_delayslot_o,
	output reg	ex_reset_dcache_o,
    output reg                    ex_csr_we,
    output reg[`DATABUS]          ex_csr_addr,
    output reg[`DATABUS]          ex_exception
);

always_ff @(posedge clk_i) begin
    if (rst_i) begin
        ex_aluop <= 4'b0;
        ex_reg1 <= 32'b0;
        ex_reg2 <= 32'b0;
        ex_waddr <= 5'b0;
        ex_we <= 1'b0;
        ex_imm_type <= `immR;
		ex_imm <= `ZeroWord;
        ex_use_reg1 <= 1'b1;
        ex_use_reg2 <= 1'b1;
        ex_mem_en <= 1'b0;
        ex_mem_sel <= 4'b0;
        ex_inst <= 32'b0;
        ex_pc <= 32'h8000_0000;
        in_delayslot_o <= `NotInDelaySlot;
        ex_in_delayslot <= `NotInDelaySlot;
		ex_reset_dcache_o <= `Disable;
        ex_csr_we <= `Disable;
        ex_csr_addr <= `ZeroWord;
        ex_exception <= `ZeroWord;
    end else if(flush) begin
        ex_aluop <= `AluNOP;
        ex_reg1 <= 32'b0;
        ex_reg2 <= 32'b0;
        ex_waddr <= 5'b0;
        ex_we <= 1'b0;
        ex_imm_type <= `immI;
		ex_imm <= `ZeroWord;
        ex_use_reg1 <= 1'b1;
        ex_use_reg2 <= 1'b0;
        ex_mem_en <= 1'b0;
        ex_mem_sel <= 4'b0000;
        ex_inst <= 32'h0000_0013;
        ex_pc <= 32'h8000_0000;
        in_delayslot_o <= `NotInDelaySlot;
        ex_in_delayslot <= `NotInDelaySlot;
		ex_reset_dcache_o <= `Disable;
        ex_csr_we <= `Disable;
        ex_csr_addr <= `ZeroWord;
        ex_exception <= `ZeroWord;
    end else if((stall[2] == `Stop && stall[3] == `NoStop)) begin//load
        ex_aluop <= `AluNOP;
        ex_reg1 <= 32'b0;
        ex_reg2 <= 32'b0;
        ex_waddr <= 5'b0;
        ex_we <= 1'b0;
        ex_imm_type <= `immI;
		ex_imm <= `ZeroWord;
        ex_use_reg1 <= 1'b1;
        ex_use_reg2 <= 1'b1;
        ex_mem_en <= 1'b0;
        ex_mem_sel <= 4'b0000;
        ex_inst <= 32'h0000_0013;
        ex_pc <= 32'h8000_0000;
        ex_in_delayslot <= `NotInDelaySlot;
		ex_reset_dcache_o <= `Disable;
        ex_csr_we <= `Disable;
        ex_csr_addr <= `ZeroWord;
        ex_exception <= `ZeroWord;
    end else if(!stall[2]) begin
        ex_aluop <= id_aluop;
        ex_reg1 <= id_reg1;
        ex_reg2 <= id_reg2;
        ex_waddr <= id_waddr;
        ex_we <= id_we;
        ex_imm_type <= id_imm_type;
		ex_imm <= id_imm;
        ex_use_reg1 <= id_use_reg1;
        ex_use_reg2 <= id_use_reg2;
        ex_mem_en <= id_mem_en;
        ex_mem_sel <= id_mem_sel;
        ex_inst <= id_inst;
        ex_pc <= id_pc;
        ex_in_delayslot <= id_in_delayslot;
        in_delayslot_o <= next_in_delayslot_i;
		ex_reset_dcache_o <= id_reset_dcache_i;
        ex_csr_we <= id_csr_we;
        ex_csr_addr <= id_csr_addr;
        ex_exception <= id_exception;
    end
end

endmodule