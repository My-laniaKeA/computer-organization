`include "define.sv"

module ex(
    input wire rst_i,

    input wire [`AluOpBUS] aluop_i,
    input wire [`DATABUS] reg1_i,
    input wire [`DATABUS] reg2_i,
    input wire [4:0] waddr_i,
    input wire we_i,
    input wire [2:0] imm_type_i,
	input wire [`DATABUS] imm_i,
    input wire use_reg1,
    input wire use_reg2,
    input wire mem_en_i,
    input wire [3:0] mem_sel_i,
    input wire [31:0] inst_i,
    input wire [31:0] pc_i,
    input wire in_delayslot_i,
	input wire reset_dcache_i,
    input wire           csr_we_i,       // write csr or not
    input wire[`ADDRBUS] csr_addr_i,     // the csr address, could be read or write
    // to csr
    output reg[`ADDRBUS] csr_raddr_o,
    input wire[`DATABUS] fw_csr_data_i,

    input wire[31:0] exception_i,

    input wire [`OpcodeBUS] pre_op_i, //detect mem is load
    output reg [`OpcodeBUS] pre_op_o,
    input wire [`RegBUS] pre_waddr_i,
    output reg [`RegBUS] pre_waddr_o,

    output reg [`DATABUS] wdata_o,
    output reg we_o,
    output reg [4:0] waddr_o,
    output reg mem_en_o,
    output reg [3:0] mem_sel_o,
    output reg [31:0] inst_o,
    output reg [31:0] pc_o,
    output reg [31:0] reg2_o,
    output reg stallreq,
    output reg in_delayslot_o,
    output reg [`OpcodeBUS] op_o,
	output reg reset_dcache_o,
    output reg            csr_we_o,
    output reg[`ADDRBUS]  csr_waddr_o,
    output reg[`DATABUS]  csr_wdata_o,
    output reg[31:0]      exception_o
);

    logic [31:0] y_reg, a_reg, b_reg;
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic breq,brlt;
    integer i;
    logic [31:0] shamt;

    always_comb begin
		if (rst_i) begin
			reg2_o = `ZeroWord;
			opcode = 7'b0;
			op_o = 7'b0;
			funct3 = 3'b0;
			in_delayslot_o = `NotInDelaySlot;
			reset_dcache_o = `Disable;
		end else begin
			reg2_o = reg2_i;
			opcode = inst_i[6:0];
			op_o = opcode;
			funct3 = inst_i[14:12];
			in_delayslot_o = in_delayslot_i;
			reset_dcache_o = reset_dcache_i;
		end
    end

    always_comb begin 
        if(use_reg1) begin
            a_reg = reg1_i;
        end else begin
            a_reg = pc_i;
        end
    end

    always_comb begin 
        if(use_reg2) begin
            b_reg = reg2_i;
        end else begin
            b_reg = imm_i;
        end
    end

    wire read_csr_enable;
    assign read_csr_enable = (aluop_i == `AluCSRRW) || (aluop_i == `AluCSRRS)|| (aluop_i == `AluCSRRC);

    always_comb begin
        if(rst_i) begin
            y_reg = 32'b0;
            we_o = 1'b0;
            waddr_o = 5'b0;
            mem_en_o = 1'b0;
            mem_sel_o = 4'b0;
            inst_o = 32'b0;
            pc_o = 32'h8000_0000;
            stallreq = 1'b0;

            pre_op_o = 7'b0;
            pre_waddr_o = 5'b0;
			
        end else begin
            stallreq = 1'b0;
            we_o = we_i;
            waddr_o = waddr_i;
            mem_en_o = mem_en_i;
            mem_sel_o = mem_sel_i;
            inst_o = inst_i;
            pc_o = pc_i;

            pre_op_o = pre_op_i;
            pre_waddr_o = pre_waddr_i;
            case(aluop_i)
                `AluADD: begin
                    y_reg = a_reg + b_reg;
                end
                `AluAND: begin
                    y_reg = a_reg & b_reg;
                end
                `AluSUB: begin
                    y_reg = a_reg - b_reg;
                end
                `AluSTLU: begin
                    y_reg = (a_reg < b_reg)? 32'b1:32'b0;
                end
                `AluXOR: begin
                    y_reg = a_reg ^ b_reg;
                end
                `AluOR: begin
                    y_reg = a_reg | b_reg;
                end
                `AluNOT: begin
                    y_reg = ~a_reg;
                end
                `AluSLL: begin
                    y_reg = a_reg << (b_reg & 8'h1f);
                end
                `AluSRL: begin
                    y_reg = a_reg >> (b_reg & 8'h1f);
                end
                `AluSETB: begin
                    y_reg = b_reg;
                end
                `AluPC: begin
                    y_reg = a_reg + 8'h4;
                end
                `AluPCNT: begin
                    y_reg = `ZeroWord;
                    for (i=0; i<32; i=i+1)
                        y_reg = y_reg + ((a_reg >> i) & 1'b1);
                end
                `AluMINU: begin
                    y_reg = a_reg < b_reg ? a_reg : b_reg;
                end
                default: y_reg = 32'b0; 
                `AluSBCLR: begin
                    shamt = b_reg & 32'h0000001f;
                    y_reg = a_reg & ~(32'h1 << shamt);
                end
            endcase
            if(read_csr_enable) begin
                y_reg = fw_csr_data_i;
            end
        end
    end

    assign wdata_o = y_reg;

    always_comb begin
        if(rst_i) begin
            csr_raddr_o = `ZeroWord;
            csr_we_o =  `Disable;
            csr_waddr_o = `ZeroWord;
            csr_wdata_o = `ZeroWord;
            exception_o = `ZeroWord;
        end else begin
            if (read_csr_enable) begin
                csr_raddr_o = csr_addr_i;
            end else begin
                csr_raddr_o = `ZeroWord;
            end
            csr_we_o = csr_we_i;
            csr_waddr_o = csr_addr_i;
            csr_wdata_o = `ZeroWord;
            exception_o = exception_i;
            case(aluop_i)
                `AluCSRRW: begin
                    csr_wdata_o = reg1_i;
                end
                `AluCSRRS: begin
                    csr_wdata_o = reg1_i | fw_csr_data_i;
                end
                `AluCSRRC: begin
                    csr_wdata_o = (~reg1_i) & fw_csr_data_i;
                end
                default: ;
            endcase
        end
    end

endmodule