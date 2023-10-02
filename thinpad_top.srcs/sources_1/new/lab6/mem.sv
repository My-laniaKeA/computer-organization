`include "define.sv"

module mem(
    input wire clk_i,
    input wire rst_i,
    input wire [`ADDRBUS] pc_i,
    input wire [`DATABUS] inst_i,
    input wire [`DATABUS] exception_i,
    
    input wire we_i,
    input wire [`RegBUS] waddr_i,
    input wire [`DATABUS] wdata_i,
    input wire [`OpcodeBUS] op_i,
    input wire mem_en_i,
    input wire [3:0] mem_sel_i,
    input wire [`DATABUS] reg2_i,
    input wire in_delayslot_i,
    input wire mem_wbs3_choosen,

    input wire                    csr_we_i,
    input wire[`ADDRBUS]          csr_waddr_i,
    input wire[`DATABUS]          csr_wdata_i,

    output reg                    csr_we_o,
    output reg[`ADDRBUS]          csr_waddr_o,
    output reg[`DATABUS]          csr_wdata_o,

    output reg we_o,
    output reg [`RegBUS] waddr_o,
    output reg [`DATABUS] wdata_o,

    output reg [`ADDRBUS] mem_addr_o,
    output reg mem_we_o,
    output reg [3:0] mem_sel_o, 
    output reg [`DATABUS] mem_data_o,
    input wire [`DATABUS] mem_data_i,
    output reg mem_ce_o,

    output reg[`ADDRBUS]  pc_o,
    output reg[`DATABUS]  inst_o,
    output reg[`DATABUS]  exception_o,
    output reg in_delayslot_o,

    output reg [`OpcodeBUS] op_o 
);

    reg [`DATABUS] wdata_o_reg;
	reg mem_wbs3_choosen_reg;

	always_ff @(posedge clk_i) begin
		mem_wbs3_choosen_reg <= mem_wbs3_choosen;
	end

    always_comb begin
        if(rst_i) begin
            mem_we_o = `Disable;
            in_delayslot_o = `Disable;
            pc_o = `ZeroWord;
            op_o = `ZeroWord;
            inst_o = `ZeroWord;
        end else begin
            mem_we_o = !we_i && mem_en_i; // TODO 发生异常需要取消读写？
            in_delayslot_o = in_delayslot_i;
            pc_o = pc_i;
            op_o = op_i;
            inst_o = inst_i;
        end
    end

    always_comb begin
        if(rst_i) begin
            wdata_o = `ZeroWord;
        end else if(op_i == `OpJAL || op_i == `OpJALR) begin
            wdata_o = pc_i + 4;
        end else if(op_i == `OpLoad) begin
            // if (inst_i[14:12] == `funct3Lb) begin
            //     wdata_o_reg = mem_data_i >> ((wdata_i & 32'h00000003) << 8'h3);
            //     wdata_o = { { 24{wdata_o_reg[7]}}, wdata_o_reg[7:0]};
            // end else begin
            //     wdata_o = mem_data_i;
            // end

            if (inst_i[14:12] == `funct3Lb) begin
                case (mem_sel_i)
                4'b0001: begin
                    wdata_o[7:0] = mem_data_i[7:0];
                end
                4'b0010: begin
                    wdata_o[7:0] = mem_data_i[15:8];
                end
                4'b0100: begin
                    wdata_o[7:0] = mem_data_i[23:16];
                end
                4'b1000: begin
                    wdata_o[7:0] = mem_data_i[31:24];
                end
                default: wdata_o = `ZeroWord;
                endcase
                wdata_o = { { 24{wdata_o[7]}}, wdata_o[7:0]};
            end else begin
                wdata_o = mem_data_i;
            end

            
        end else if(we_i) begin
            wdata_o = wdata_i;
        end else begin
            wdata_o = `ZeroWord;
        end
    end

    always_comb begin 
        if(rst_i) begin
            mem_ce_o = `Disable;
        end else if(op_i == `OpLoad || op_i == `OpStore) begin
            mem_ce_o = `Enable;
        end else begin
            mem_ce_o = `Disable;
        end
    end

    always_comb begin
        if(rst_i) begin
            we_o = `Disable;
            waddr_o = 5'b0;
            mem_addr_o = `ZeroWord;
            mem_sel_o = 4'b0;
            mem_data_o = `ZeroWord;
        end else begin
            we_o = we_i;
            waddr_o = waddr_i;
            mem_addr_o = wdata_i;
            mem_sel_o = mem_sel_i;
            mem_data_o = reg2_i;
        end
    end

    logic addr_align_word,load_addr_align_exception,store_addr_align_exception;

    assign addr_align_word = (mem_sel_i == 4'b1111 && wdata_i[1:0] == 2'b00) ? 1'b1 : 1'b0;
    assign load_addr_align_exception = mem_sel_i == 4'b1111 & (~ addr_align_word) & (op_i == `OpLoad);
    assign store_addr_align_exception = mem_sel_i == 4'b1111 & (~ addr_align_word) & (op_i == `OpStore);
    //FIXME 确认非对称 exception 定义

    //exception ={ misaligned_load, misaligned_store, illegal_inst, misaligned_inst, ebreak, ecall, mret}
    assign exception_o = {25'b0, load_addr_align_exception, store_addr_align_exception, exception_i[4:0]};
    // assign exception_o = {27'b0, exception_i[4:0]}; //FIXME

    always_comb begin
        if(rst_i) begin
            csr_we_o = `Disable;
            csr_waddr_o = `ZeroWord;
            csr_wdata_o = `ZeroWord;
        end else begin
            csr_we_o = csr_we_i;
            csr_waddr_o = csr_waddr_i;
            csr_wdata_o = csr_wdata_i;
        end
    end

endmodule