`include "define.sv"

module id(

    input wire rst_i,

    input wire [`ADDRBUS] pc_i,
    input wire [`DATABUS] inst_i,
    input wire [`OpcodeBUS] ex_op_i,
    
	// if
	input wire				pred_taken_i,
	output reg 				needs_correction_o,
	output reg [`ADDRBUS] 	corrected_pc_o,

	// bpu
	output reg 				is_branch_o,
	output reg				is_jal_o,
	output reg 				branch_taken_o,

    // regfile
    // input  wire [`DATABUS] rdata_a_i,
    // input  wire [`DATABUS] rdata_b_i,
    output reg  [`RegBUS]  raddr_a_o,
    output reg  [`RegBUS]  raddr_b_o,

	// forward
	input wire 	[`DATABUS] fw_rs1_dat_i,
	input wire	[`DATABUS] fw_rs2_dat_i,

    // // exe back
    // input wire  ex_we_i,
    input wire  [`RegBUS] ex_waddr_i,
    // input wire  [`DATABUS] ex_wdata_i,

    // //mem back
    // input wire  mem_we_i,
    // input wire  [`RegBUS] mem_waddr_i,
    // input wire  [`DATABUS] mem_wdata_i,

    //exe
    output reg  [`AluOpBUS] aluop_o,
    output reg  [`DATABUS] reg1_o,
    output reg  [`DATABUS] reg2_o,
	output reg 	[`DATABUS] imm_o,
    output reg  [`RegBUS]  waddr_o,
    output reg  we_o,
    output reg  [2:0] imm_type_o,
    output reg  use_reg1, 
    output reg  use_reg2,
    output reg  mem_en_o,
    output reg  [3:0] mem_sel_o,
    output reg  [`ADDRBUS] pc_o,
    output reg  [`DATABUS] inst_o,

    input wire in_delayslot_i,
    output reg next_in_delayslot_o,
    output reg branch_flag_o,
    output reg [`ADDRBUS] branch_addr_o,
    // .link_addr_o(),
    output reg in_delayslot_o,
    // .current_inst_addr_o(),

	output reg reset_icache_o,
	output reg reset_dcache_o,
	output reg reset_tlb_o,

    input wire  mem_stallreq,
    output reg  stallreq,

    output reg                    csr_we_o,
    output reg[`ADDRBUS]          csr_addr_o,
    output reg [31:0]             exception_o
);

    logic [`DATABUS] inst;
    logic [`RegBUS] rd, rs1, rs2;
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    logic stallreq_reg1,stallreq_reg2,ex_load;
    logic  csr_we;
    logic[`ADDRBUS]  csr_addr;

    logic         excepttype_mret;
    logic         excepttype_ecall;
    logic         excepttype_ebreak;
    logic         excepttype_illegal_inst;

    always_comb begin
        inst = (in_delayslot_i) ? 32'h0000_0013 : inst_i;
        rd = inst[11:7];
        rs1 = inst[19:15];
        rs2 = inst[24:20];
        opcode = inst[6:0];
        funct3 = inst[14:12];
        funct7 = inst[31:25];
        raddr_a_o = rs1;
        raddr_b_o = rs2;
        waddr_o = rd;
        stallreq = stallreq_reg1 | stallreq_reg2;
    end

    // exception
    always_comb begin
        csr_we_o = csr_we;
        csr_addr_o = csr_addr;
        //exception ={ misaligned_load, misaligned_store, illegal_inst, misaligned_inst,  ebreak, ecall,  mret}
        // TODO 后续exception可以继续添加
        exception_o = {27'b0, excepttype_illegal_inst, 1'b0, excepttype_ebreak, excepttype_ecall, excepttype_mret};
    end 

  always_comb begin
 if(rst_i) begin
        ex_load =1'b0;
    end else begin
        ex_load = ((ex_op_i == `OpLoad) || mem_stallreq) ? 1'b1 : 1'b0;
    end
  end

  always_comb begin
    if (rst_i) begin
        aluop_o = `AluNOP;
        we_o = 1'b0;
        use_reg1 = 1'b1;
        use_reg2 = 1'b1;
        imm_type_o = `immR;
        pc_o = 32'h8000_0000;
        inst_o = 32'h0000_0013;
        mem_sel_o = 4'b0;
        mem_en_o = 1'b0;
        branch_addr_o = `ZeroWord;
        branch_flag_o = `NotBranch;
        next_in_delayslot_o = `NotInDelaySlot;

		needs_correction_o = 1'b0;
		corrected_pc_o		= `ZeroWord;
		is_branch_o			= `Disable;
		is_jal_o			= `Disable;
		branch_taken_o		= `NotTaken;

        imm_o = `ZeroWord;
        csr_we = `Disable;
        csr_addr = `ZeroWord;
        excepttype_ecall = 1'b0;
        excepttype_mret = 1'b0;
        excepttype_ebreak = 1'b0;
        excepttype_illegal_inst = 1'b0;
		reset_icache_o = `Disable;
		reset_dcache_o = `Disable;
		reset_tlb_o	= `Disable;
    end else begin
        pc_o = pc_i;
        inst_o = inst;
        we_o = 1'b0;
        aluop_o = `AluNOP;
        imm_type_o = `immR;
        use_reg1 = 1'b1;
        use_reg2 = 1'b1;
        mem_en_o = 1'b0;
        mem_sel_o = 4'b0;
        branch_addr_o = `ZeroWord;
        branch_flag_o = `NotBranch;
        next_in_delayslot_o = `NotInDelaySlot;
		imm_o = `ZeroWord;
		
		needs_correction_o = 1'b0;
		corrected_pc_o		= `ZeroWord;
		is_branch_o			= `Disable;
		is_jal_o			= `Enable;
		branch_taken_o		= `NotTaken;

		reset_icache_o = `Disable;
		reset_dcache_o = `Disable;
		reset_tlb_o	= `Disable;
        csr_we = `Disable;
        csr_addr = `ZeroWord;
        excepttype_ecall = 1'b0;
        excepttype_mret = 1'b0;
        excepttype_ebreak = 1'b0;
        excepttype_illegal_inst = 1'b0; // FIXME 是否需要在default中置一
        case(opcode)
            `OpRtype: begin
                imm_type_o = `immR;
				imm_o = `ZeroWord;
                use_reg1 = 1'b1;
                use_reg2 = 1'b1;
                mem_en_o = 1'b0;
                we_o = 1'b1;
                case(funct3)
                    `funct3Add: begin
                        if(funct7 == `funct7Sub) begin
                            aluop_o = `AluSUB;
                        end else begin
                            aluop_o = `AluADD;
                        end
                    end
                    `funct3And: begin
                        aluop_o = `AluAND;
                    end
                    `funct3Or: begin
                        if(funct7 == `funct7Minu) begin
                            aluop_o = `AluMINU;
                        end else begin
                            aluop_o = `AluOR;
                        end
                    end
                    `funct3Xor: begin
                        aluop_o = `AluXOR;
                    end
                    `funct3Sbclr: begin
                        aluop_o = `AluSBCLR;
                    end
                    `funct3Sltu: begin
                        aluop_o = `AluSTLU;
                    end
                    default: ;
                endcase
            end 
            `OpItype: begin
                imm_type_o = `immI;
				imm_o = {{20{inst[31]}}, inst[31:20]};
                use_reg1 = 1'b1;
                use_reg2 = 1'b0;
                mem_en_o = 1'b0;
                we_o= 1'b1;
                case(funct3)
                    `funct3Add: begin
                        aluop_o = `AluADD;
                    end
                    `funct3And: begin
                        aluop_o = `AluAND;
                    end
                    `funct3Or: begin
                        aluop_o = `AluOR;
                    end
                    `funct3Sll: begin
                        if(funct7 == `funct7Pcnt) begin
                            aluop_o = `AluPCNT;
                        end else begin
                            aluop_o = `AluSLL;
                        end
                    end
                    `funct3Srl: begin
                        aluop_o = `AluSRL;
                    end
                    default: ;
                endcase
            end 
            `OpLoad: begin
                imm_type_o = `immI;
				imm_o = {{20{inst[31]}}, inst[31:20]};
                aluop_o = `AluADD;
                use_reg1 = 1'b1;
                use_reg2 = 1'b0;
                mem_en_o = 1'b1;
                we_o= 1'b1;
                case(funct3)
                    `funct3Lb: begin
                        mem_sel_o = 4'b0001;
                    end
                    `funct3Lw: begin
                        mem_sel_o = 4'b1111;
                    end
                    default: ;
                endcase
            end 
            `OpStore: begin
                imm_type_o = `immS;
				imm_o = {{20{inst[31]}}, inst[31:25], inst[11:7]};
                aluop_o = `AluADD;
                use_reg1 = 1'b1;
                use_reg2 = 1'b0;
                mem_en_o = 1'b1;
                we_o= 1'b0;
                case(funct3)
                    `funct3Sb: begin
                        mem_sel_o = 4'b0001;
                    end
                    `funct3Sw: begin
                        mem_sel_o = 4'b1111;
                    end
                    default: ;
                endcase
            end 
            `OpBranch: begin
                imm_type_o = `immB;
				imm_o = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8],1'b0};
				branch_addr_o = pc_i + imm_o;
                aluop_o = `AluNOP;
                use_reg1 = 1'b1;
                use_reg2 = 1'b1; 
                mem_en_o = 1'b0;
                we_o = 1'b0;

				is_branch_o = `Enable;

                case(funct3)
                    `funct3Beq: begin //beq
                        if(fw_rs1_dat_i == fw_rs2_dat_i) begin
                            // branch_addr_o = pc_i + imm_o;
                            // branch_flag_o = `Branch;
                            // next_in_delayslot_o = `InDelaySlot;
							branch_taken_o = `Taken;
                        end
                    end
                    `funct3Bne: begin
                        if(fw_rs1_dat_i != fw_rs2_dat_i) begin
                            // branch_addr_o = pc_i + imm_o;
                            // branch_flag_o = `Branch;
                            // next_in_delayslot_o = `InDelaySlot;
							branch_taken_o = `Taken;
                        end
                    end
                    default: ;
                endcase

				if (branch_taken_o != pred_taken_i) begin
					needs_correction_o = `Enable;
					branch_flag_o = `Branch;
					next_in_delayslot_o = `InDelaySlot;
					if (branch_taken_o)
						corrected_pc_o = pc_i + imm_o;
					else
						corrected_pc_o = pc_i + 4'h4;
			end

            end 
            `OpJAL: begin
                imm_type_o = `immJ;
                imm_o =  { { 11{inst[31]} }, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0 };
                use_reg1 = 1'b0;
                use_reg2 = 1'b1;
                aluop_o = `AluPC;
                mem_en_o = 1'b0;
                we_o = 1'b1;
                branch_addr_o = pc_i + imm_o;
				
				is_jal_o =`Enable;
				if (imm_o != 32'h4) begin
					branch_taken_o = `Taken;
				end
				
				if (branch_taken_o != pred_taken_i) begin
					needs_correction_o = `Enable;
					corrected_pc_o = pc_i + imm_o;
					branch_flag_o = `Branch;
                	next_in_delayslot_o = `InDelaySlot;
				end

            end
            `OpJALR: begin
                imm_type_o = `immI;
                imm_o = { { 20{inst[31]} }, inst[31:21], 1'b0 };
                use_reg1 = 1'b0;
                use_reg2 = 1'b1;
                aluop_o = `AluPC;
                mem_en_o = 1'b0;
                we_o = 1'b1;
                branch_addr_o = fw_rs1_dat_i + imm_o;
				needs_correction_o = `Enable;
				corrected_pc_o = fw_rs1_dat_i + imm_o;
                branch_flag_o = `Branch;
                next_in_delayslot_o = `InDelaySlot;
            end
            `OpLUI: begin
                imm_type_o = `immU;
				imm_o = {inst[31:12], 12'h000};
                use_reg1 = 1'b1;
                use_reg2 = 1'b0;
                aluop_o = `AluSETB;
                mem_en_o = 1'b0;
                we_o= 1'b1;
            end
            `OpAUIPC: begin
                imm_type_o = `immU;
				imm_o = {inst[31:12], 12'h000};
                use_reg1 = 1'b0;
                use_reg2 = 1'b0;
                aluop_o = `AluADD;
                mem_en_o = 1'b0;
                we_o= 1'b1;
            end
            `OpCSR: begin
				if (funct7 == `funct7Sfence) begin
					reset_tlb_o = `Enable;
				end else begin
					csr_addr = {20'h0, inst_i[31:20]};
					imm_o = {27'b0, inst_i[19:15]};
					mem_en_o = 1'b0;
					use_reg1 = 1'b1;
					use_reg2 = 1'b0;
					we_o = `Enable;
					csr_we = `Enable;
					case(funct3)
						`funct3CSRRW: begin
							aluop_o = `AluCSRRW;
						end
						`funct3CSRRS: begin
							aluop_o = `AluCSRRS;
						end
						`funct3CSRRC: begin
							aluop_o = `AluCSRRC;
						end
						`funct3Environ: begin
							if(funct7 == 7'b0 && rs2 == 5'b0) begin //ecall
								csr_we = `Disable;
								aluop_o = `AluNOP;
								if(in_delayslot_i == 1'b0) begin
									excepttype_ecall = 1'b1;
									next_in_delayslot_o = `InDelaySlot;
								end
							end else if(funct7 == 7'b0 && rs2 == 5'b1) begin //ebreak
								csr_we = `Disable;
								aluop_o = `AluNOP;
								if(in_delayslot_i == 1'b0) begin
									excepttype_ebreak = 1'b1;
									next_in_delayslot_o = `InDelaySlot;
								end
							end else if(funct7 == 7'b0011000 && rs2 == 5'b00010) begin //mret
								csr_we = `Disable;
								aluop_o = `AluNOP;
								if(in_delayslot_i == 1'b0) begin
									excepttype_mret = 1'b1;
									next_in_delayslot_o = `InDelaySlot;
								end
							end
						end
						default: ;
					endcase
				end
            end
			`OpFence: begin
				if (funct3 == 3'b001) begin
					reset_icache_o = `Enable;
					reset_dcache_o = `Enable;
				end
				else if (funct3 == 3'b000)	reset_dcache_o = `Enable;
			end
			default: begin
			end
        endcase
    end
  end

    always_comb begin
        stallreq_reg1 = `NoStop;
        reg1_o = `ZeroWord;
        if(rst_i || opcode == `OpLUI) begin
            reg1_o = `ZeroWord;
        end else if(ex_waddr_i == rs1 && ex_load && use_reg1) begin
            stallreq_reg1 = `Stop;
        end else begin
            reg1_o = fw_rs1_dat_i;
        // end else begin
        //     reg1_o = `ZeroWord;
        end
    end

    always_comb begin
        stallreq_reg2 = `NoStop;
        reg2_o = `ZeroWord;
        if(rst_i) begin
            reg2_o = `ZeroWord;
        end else if(ex_waddr_i == rs2 && ex_load && use_reg2) begin
            stallreq_reg2 = `Stop;
        end else begin
            reg2_o = fw_rs2_dat_i;
        end
        // else if(use_reg2) begin
        //     reg2_o = rdata_b_i;
        // end else begin
        //     reg2_o = `ZeroWord;
        // end
    end

    always_comb begin
        if(rst_i) begin
            in_delayslot_o = `NotInDelaySlot;
        end else begin
            in_delayslot_o = in_delayslot_i;
        end
    end

endmodule