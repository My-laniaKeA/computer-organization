`include "define.sv"

module pc_reg(
    input wire clk_i,
    input wire rst_i,
    output reg [`ADDRBUS] pc,
    output reg ce,

    input wire branch_flag_i,
    input wire [`ADDRBUS] branch_addr_i,
    // output reg branch_flag_o,

    input wire [5:0] stall,
    input wire flush,
    input wire [`ADDRBUS] new_pc,

	// bpu
	input wire needs_correction_i,
	input wire [`ADDRBUS] corrected_pc_i,
	input wire [`ADDRBUS] next_pc_i // prediction from bpu
);

    always_ff @ (posedge clk_i) begin
        if(rst_i) begin
            ce <= `Disable;
        end else begin
            ce <= `Enable;
        end
    end

    always_ff @ (posedge clk_i) begin
        if (ce == `Disable) begin
            pc <= 32'h8000_0000; 
            // branch_flag_o <= 1'b0;
        end else begin
            // branch_flag_o <= 1'b0;
            if(flush) begin
                pc <= new_pc;
            end else if(stall[0] == `NoStop) begin

				if (needs_correction_i) begin
					pc <= corrected_pc_i;
				end else begin
					pc <= next_pc_i;
				end

                // if(branch_flag_i) begin
                //     branch_flag_o <= branch_flag_i;
                //     pc <= branch_addr_i;
                // end else begin
                //     pc <= pc + 4'h4;
                // end
            end
        end
    end
    
endmodule