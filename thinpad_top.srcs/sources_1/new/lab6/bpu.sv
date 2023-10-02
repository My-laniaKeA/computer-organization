`include "define.sv"

module bpu (
input wire clk_i,
input wire rst_i,

// pc
input wire [`ADDRBUS]	pc_i,				// current pc
output reg [`ADDRBUS]	next_pc_o,			// next pc
output reg				next_taken_o,		// branch taken prediction while generating next pc


// id
input wire				id_branch_taken_i,	// whether branch taken actually
input wire				id_is_branch_i,		// whether B-type inst at ID needs to update BTB
input wire				id_is_jal_i,		// whether J-type inst at ID needs to update BTB
input wire [`ADDRBUS]	id_pc_i,			// source pc from ID
input wire [`ADDRBUS]	id_target_adr_i		// target pc from ID
);


/* ------------------------------ BTB Entry ------------------------------ */
/*
Entry Index: src_addr[6:2]
+-------+---------+---------------------------------+----------------------+
| Valid | Counter | Target Address (tgt_addr[31:2]) | TAG (src_addr[31:7]) |
+-------+---------+---------------------------------|----------------------+
|  57   | 56   55 | 54                           25 | 24                 0 |
+-------+---------+---------------------------------+----------------------+
*/

logic [`BTBE_WIDTH-1:0] btb [0:`BTBE_NUM-1];

// look up BTB for next pc
always_comb begin
	if (rst_i) begin
		next_pc_o	 = `ZeroWord;
		next_taken_o = `NotTaken;

	end else begin
		if ((btb[pc_i[6:2]][57] == `BTBE_VALID) && 
			(btb[pc_i[6:2]][24:0] == pc_i[31:7])) begin

			next_taken_o = btb[pc_i[6:2]][56];
			if (next_taken_o) begin
				next_pc_o = { btb[pc_i[6:2]][54:25], 2'b00 };
			end else begin
				next_pc_o = pc_i + 4'h4;
			end

		end else begin
			next_pc_o	 = pc_i + 4'h4;
			next_taken_o = `NotTaken;
		end
	end
end

reg old_is_branch = `Disable;
reg old_is_jal = `Disable;
reg old_id_taken = `NotTaken;
reg [`ADDRBUS] old_id_pc = `ZeroWord;
reg [`ADDRBUS] old_id_target_adr = `ZeroWord;


// update BTB with B-type inst from ID
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		for (int i = 0; i < `BTBE_NUM; i++) // initialize empty btb
			btb[i] <= 58'b0; 
	end else begin
		old_is_branch <= id_is_branch_i;
		old_is_jal <= id_is_jal_i;
		old_id_taken <= id_branch_taken_i;
		old_id_pc <= id_pc_i;
		old_id_target_adr <= id_target_adr_i;

		if (old_is_branch && (old_id_pc != id_pc_i)) begin 

			// update old btbe
			if (btb[old_id_pc[6:2]][57] == `BTBE_VALID &&
				btb[old_id_pc[6:2]][24:0] == old_id_pc[31:7]) begin
					
					case(btb[old_id_pc[6:2]][56:55])
					
						2'b00: begin	// strongly not taken
							if (old_id_taken) begin
								btb[old_id_pc[6:2]][56:55] <= 2'b01;
							end else begin
								btb[old_id_pc[6:2]][56:55] <= 2'b00;
							end
						end

						2'b01: begin	// weakly not taken
							if (old_id_taken) begin
								btb[old_id_pc[6:2]][56:55] <= 2'b11;
							end else begin
								btb[old_id_pc[6:2]][56:55] <= 2'b00;
							end
						end

						2'b10: begin	// weakly taken
							if (old_id_taken) begin
								btb[old_id_pc[6:2]][56:55] <= 2'b11;
							end else begin
								btb[old_id_pc[6:2]][56:55] <= 2'b00;
							end
						end

						2'b11: begin	// strongly taken
							if (old_id_taken) begin
								btb[old_id_pc[6:2]][56:55] <= 2'b11;
							end else begin
								btb[old_id_pc[6:2]][56:55] <= 2'b10;
							end
						end

						default: begin
							btb[old_id_pc[6:2]][56:55] <= 2'b00;
						end

					endcase
			end

			// add new btbe
			else begin
				btb[old_id_pc[6:2]][57] 	<= `BTBE_VALID;
				btb[old_id_pc[6:2]][24:0]	<= old_id_pc[31:7];

				btb[old_id_pc[6:2]][54:25] 	<= old_id_target_adr[31:2];

				if (old_id_taken) begin
					btb[old_id_pc[6:2]][56:55] <= 2'b01;
				end else begin
					btb[old_id_pc[6:2]][56:55] <= 2'b00;
				end 
			end
	
		end // old_is_branch

		else if (old_is_jal && (old_id_pc != id_pc_i)) begin 

			// update old btbe
			if (btb[old_id_pc[6:2]][57] == `BTBE_VALID &&
				btb[old_id_pc[6:2]][24:0] == old_id_pc[31:7]) begin
					
					case(btb[old_id_pc[6:2]][56:55])
					
						2'b00: begin	// strongly not taken
							if (old_id_taken) begin
								btb[old_id_pc[6:2]][56:55] <= 2'b11;
							end else begin	// will never happen
								btb[old_id_pc[6:2]][56:55] <= 2'b00;
							end
						end

						2'b11: begin	// strongly taken
							if (old_id_taken) begin
								btb[old_id_pc[6:2]][56:55] <= 2'b11;
							end else begin	// will never happen
								btb[old_id_pc[6:2]][56:55] <= 2'b00;
							end
						end

						default: begin
							btb[old_id_pc[6:2]][56:55] <= 2'b00;
						end

					endcase
			end

			// add new btbe
			else begin
				btb[old_id_pc[6:2]][57] 	<= `BTBE_VALID;
				btb[old_id_pc[6:2]][24:0]	<= old_id_pc[31:7];

				btb[old_id_pc[6:2]][54:25] 	<= old_id_target_adr[31:2];

				if (old_id_taken) begin
					btb[old_id_pc[6:2]][56:55] <= 2'b11;
				end else begin	// will never happen
					btb[old_id_pc[6:2]][56:55] <= 2'b00;
				end 
			end
	
		end // old_is_jal

	end

end

endmodule
