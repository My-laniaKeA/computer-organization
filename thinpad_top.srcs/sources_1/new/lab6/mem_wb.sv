module mem_wb(
    input wire clk_i,
    input wire rst_i,
    input wire [5:0] stall,
    input wire flush,

	input wire [`ADDRBUS] mem_pc,
    input wire [`DATABUS] mem_wdata,
    input wire mem_we,
    input wire [4:0] mem_waddr,
    input wire                 mem_csr_we,
    input wire[31:0]           mem_csr_waddr,
    input wire[31:0]           mem_csr_wdata,

    output reg [`ADDRBUS] wb_pc,
	output reg [`DATABUS] wb_wdata,
    output reg wb_we,
    output reg [4:0] wb_waddr,
    output reg                 wb_csr_we,
    output reg[31:0]           wb_csr_waddr,
    output reg[31:0]           wb_csr_wdata
);

always_ff @(posedge clk_i) begin
    if (rst_i) begin
		wb_pc <= 32'h8000_0000;
        wb_wdata <= 32'b0;
        wb_we <= 1'b0;
        wb_waddr <= 5'b0;
        wb_csr_we <= `Disable;
        wb_csr_waddr <= `ZeroWord;
        wb_csr_wdata <= `ZeroWord;
    end else if(flush || (stall[4] && !stall[5])) begin
		wb_pc <= 32'h8000_0000;
        wb_wdata <= 32'b0;
        wb_we <= 1'b0;
        wb_waddr <= 5'b0;
        wb_csr_we <= `Disable;
        wb_csr_waddr <= `ZeroWord;
        wb_csr_wdata <= `ZeroWord;
    end else if(!stall[4]) begin

		// if (mem_waddr == 5'b0) begin // for cpu test
		// 	wb_pc <= 32'h8000_0000;
		// end else begin
		// 	wb_pc <= mem_pc;
		// end
		
        wb_pc <= mem_pc;
		wb_wdata <= mem_wdata;
        wb_we <= mem_we;
        wb_waddr <= mem_waddr;
        wb_csr_we <= mem_csr_we;
        wb_csr_waddr <= mem_csr_waddr;
        wb_csr_wdata <= mem_csr_wdata;
    end
end


endmodule