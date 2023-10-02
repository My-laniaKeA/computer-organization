`include "define.sv"
module forward (
input wire rst_i,

// id
input wire [`RegBUS]	radr1_i,
input wire [`RegBUS]	radr2_i,
output reg [`DATABUS]	rdat1_o,  	// Reg[rs1] after forwarding
output reg [`DATABUS]	rdat2_o,	// Reg[rs2] after forwarding

// rf
input wire [`DATABUS]	rf_rdat1_i,
input wire [`DATABUS]	rf_rdat2_i,

// csr
input wire [`DATABUS]   csr_rdata_i,

// ex
input wire				ex_we_i,
input wire [`RegBUS]	ex_wadr_i,
input wire [`DATABUS]	ex_wdat_i,

input wire [`ADDRBUS]   csr_raddr_i,
output reg [`DATABUS]   csr_rdata_o,

// mem
input wire				mem_we_i,
input wire [`RegBUS]	mem_wadr_i,
input wire [`DATABUS]	mem_wdat_i,

input wire              mem_csr_we_i,
input wire [`ADDRBUS]   mem_csr_waddr_i,
input wire [`DATABUS]   mem_csr_wdata_i,

// wb
input wire				wb_we_i,
input wire [`RegBUS]	wb_wadr_i,
input wire [`DATABUS]	wb_wdat_i,

input wire              wb_csr_we_i,
input wire [`ADDRBUS]   wb_csr_waddr_i,
input wire [`DATABUS]   wb_csr_wdata_i
);

always_comb begin
	if (rst_i) begin
		rdat1_o = `ZeroWord;
		rdat2_o = `ZeroWord;
		csr_rdata_o = `ZeroWord;
	end else begin
		
		if (radr1_i == 5'b0) begin
			rdat1_o = `ZeroWord;
		end else if (ex_wadr_i == radr1_i && ex_we_i) begin
			rdat1_o = ex_wdat_i;
		end else if (mem_wadr_i == radr1_i && mem_we_i) begin
			rdat1_o = mem_wdat_i;
		end else if (wb_wadr_i == radr1_i && wb_we_i) begin	
			rdat1_o = wb_wdat_i;
		end else begin 
			rdat1_o = rf_rdat1_i;
		end
		
		if (radr2_i == 5'b0) begin
			rdat2_o = `ZeroWord;
		end else if (ex_wadr_i == radr2_i && ex_we_i) begin
			rdat2_o = ex_wdat_i;
		end else if (mem_wadr_i == radr2_i && mem_we_i) begin
			rdat2_o = mem_wdat_i;
		end else if (wb_wadr_i == radr2_i && wb_we_i) begin	
			rdat2_o = wb_wdat_i;
		end else begin 
			rdat2_o = rf_rdat2_i;
		end

		if (mem_csr_waddr_i == csr_raddr_i && mem_csr_we_i) begin
			csr_rdata_o = mem_csr_wdata_i;
		end else if (wb_csr_waddr_i == csr_raddr_i && wb_csr_we_i) begin
			csr_rdata_o = wb_csr_wdata_i;
		end else begin
			csr_rdata_o = csr_rdata_i;
		end
	end
end

endmodule
