`include "define.sv"

module ex_mem(
    input wire clk_i,
    input wire rst_i,
    input wire [5:0] stall,
    input wire flush,

    input wire [31:0] ex_wdata,
    input wire ex_we,
    input wire [4:0] ex_waddr,
    input wire [6:0] ex_op,
    input wire ex_mem_en,
    input wire [3:0] ex_mem_sel,
    input wire [31:0] ex_pc,
    input wire [31:0] ex_inst,
    input wire [31:0] ex_reg2,
    input wire ex_in_delayslot,
	input wire ex_reset_dcache_i,
    input wire                    ex_csr_we,
    input wire[`ADDRBUS]           ex_csr_waddr,
    input wire[`DATABUS]           ex_csr_wdata,
    input wire[`DATABUS]           ex_exception,

    input wire [`OpcodeBUS] pre_op_i, //detect mem is load
    input wire [`RegBUS] pre_rd_adr_i,
    input wire [`DATABUS] mem_data_i,

    output reg [31:0] mem_wdata,
    output reg mem_we,
    output reg [4:0] mem_waddr,
    output reg [6:0] mem_op,
    output reg mem_en,
    output reg [3:0] mem_sel,
    output reg [31:0] mem_pc,
    output reg [31:0] mem_inst,
    output reg [31:0] mem_reg2,
    output reg mem_in_delayslot,
	output reg mem_reset_dcache_o,
    output reg                    mem_csr_we,
    output reg[`ADDRBUS]           mem_csr_waddr,
    output reg[`DATABUS]           mem_csr_wdata,
    output reg[`DATABUS]           mem_exception
);
logic [3:0] mem_sel_comb;
wire pre_inst_is_load;
reg rs2_loadrelate;

assign pre_inst_is_load = (pre_op_i == `OpLoad) ? 1'b1 : 1'b0;

always_comb begin
  if (pre_inst_is_load && (pre_rd_adr_i == ex_inst[24:20])) begin
    rs2_loadrelate = 1'b1;
  end else begin
    rs2_loadrelate = 1'b0;
  end
end

always_comb begin //renew mem_sel based on mem_addr
    mem_sel_comb = ex_mem_sel;
    if ((ex_op == `OpLoad) && (ex_inst[14:12] == `funct3Lb)) begin
        mem_sel_comb = ex_mem_sel << (ex_wdata & 32'h00000003);
    end else if ((ex_op == `OpStore) && (ex_inst[14:12] == `funct3Sb)) begin
        mem_sel_comb = ex_mem_sel << (ex_wdata & 32'h00000003);
    end
end

always_ff @(posedge clk_i) begin
    if (rst_i) begin
        mem_wdata <= `ZeroWord;
        mem_we <= 1'b0;
        mem_waddr <= 5'b0;
        mem_op <= 7'b0;
        mem_en <= 1'b0;
        mem_sel <= 4'b0;
        mem_pc <= 32'h8000_0000;
        mem_inst <= `ZeroWord;
        mem_in_delayslot <= `NotInDelaySlot;
        mem_reg2 <= `ZeroWord;
		mem_reset_dcache_o <= `Disable;
        mem_csr_we <= `Disable;
        mem_csr_waddr <= `ZeroWord;
        mem_csr_wdata <= `ZeroWord;
        mem_exception <= `ZeroWord;
    end else if(flush) begin
        mem_wdata <= `ZeroWord;
        mem_we <= 1'b0;
        mem_waddr <= 5'b0;
        mem_op <= 7'b0;
        mem_en <= 1'b0;
        mem_sel <= 4'b0;
        mem_pc <= 32'h8000_0000;
        mem_inst <= 32'h0000_0013;
        mem_reg2 <= `ZeroWord;
        mem_in_delayslot <= `NotInDelaySlot;
		mem_reset_dcache_o <= `Disable;
        mem_csr_we <= `Disable;
        mem_csr_waddr <= `ZeroWord;
        mem_csr_wdata <= `ZeroWord;
        mem_exception <= `ZeroWord;
    end else if(stall[3] && !stall[4]) begin
        mem_wdata <= `ZeroWord;
        mem_we <= 1'b0;
        mem_waddr <= 5'b0;
        mem_op <= 7'b0;
        mem_en <= 1'b0;
        mem_sel <= 4'b0;
        mem_pc <= 32'h8000_0000;
        mem_inst <= 32'h0000_0013;
        mem_reg2 <= `ZeroWord;
        mem_in_delayslot <= `NotInDelaySlot;
		mem_reset_dcache_o <= `Disable;
        mem_csr_we <= `Disable;
        mem_csr_waddr <= `ZeroWord;
        mem_csr_wdata <= `ZeroWord;
        mem_exception <= `ZeroWord;
    end else if(!stall[3]) begin
        if (rs2_loadrelate) begin //load before write
          mem_reg2 <= mem_data_i;
        end else begin
          mem_reg2 <= ex_reg2; // mem write data
        end
        mem_we <= ex_we;
        mem_waddr <= ex_waddr;
        mem_op <= ex_op;
        mem_en <= ex_mem_en;
        mem_sel <= mem_sel_comb;
        mem_pc <= ex_pc;
        mem_inst <= ex_inst;
		mem_wdata  <= ex_wdata; // mem address
        mem_in_delayslot <= ex_in_delayslot;
		mem_reset_dcache_o <= ex_reset_dcache_i;
        mem_csr_we <= ex_csr_we;
        mem_csr_waddr <= ex_csr_waddr;
        mem_csr_wdata <= ex_csr_wdata;
        mem_exception <= ex_exception;
    end
end


endmodule