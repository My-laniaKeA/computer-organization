`include "define.sv"

module if_id(
    input wire clk_i,
    input wire rst_i,
    
    input wire [`ADDRBUS] if_pc,
    input wire [`DATABUS] if_inst,
	input wire        if_next_taken,
    input wire [5:0]  stall,
    input wire        flush,
	input wire        needs_correction,

    output reg [`ADDRBUS] id_pc,
    output reg [`DATABUS] id_inst,
	output reg        id_next_taken
    // input wire branch_flag
);

always_ff @(posedge clk_i) begin
    if (rst_i) begin
        id_pc <= 32'h8000_0000;
        id_inst <= 32'h0000_0013;
		id_next_taken <= `NotTaken;
    // end else if(branch_flag || flush || (stall[1] == `Stop && stall[2] == `NoStop)) begin
	end else if(flush || (stall[1] == `Stop && stall[2] == `NoStop)) begin
        id_pc <= 32'h8000_0000;
        id_inst <= 32'h0000_0013;
		id_next_taken <= `NotTaken;
    end else if(stall[1] == `NoStop) begin
        // id_pc <= if_pc;
        // id_inst <= if_inst;
		// id_next_taken <= if_next_taken;
		if (needs_correction) begin	// wrong branch prediction, add bubble
			id_pc <= 32'h8000_0000;
			id_inst <= 32'h0000_0013;
			id_next_taken <= `NotTaken;
		end else begin
			id_pc <= if_pc;
        	id_inst <= if_inst;
			id_next_taken <= if_next_taken;
		end

    end
end

endmodule