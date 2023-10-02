`include "define.sv"

module dcache(
	input wire 				rst_i,
	input wire 				clk_i,

	// mem_master
	output reg 				wb_ce_o,
	output reg 				wb_we_o,
    output reg [`ADDRBUS] 	wb_adr_o,
	output reg [`ADDRBUS] 	wb_prev_adr_o,
	output reg [`DATABUS] 	wb_dat_o,
    output reg [3:0] 		wb_sel_o,
	output reg [3:0]		wb_dirty_o,
    input wire [`DATABUS] 	wb_dat_i,
	input wire 				wb_ack_i,
	output reg				reset_cache_o,

	// mem
	input wire 				mem_ce_i,
	input wire [`ADDRBUS] 	mem_adr_i,	
	input wire [`DATABUS]	mem_dat_i,
	input wire				mem_we_i,
	input wire [3:0]		mem_sel_i,
	output reg [`DATABUS]	mem_dat_o,
	output reg				mem_ack_o,

	// ctrl
	// output reg				stallreq_o,

	// id
	input wire				reset_cache_i
);

// Use 2-way set associate cache

/* ---------------------- Cache Table Entry ---------------------- */
/*
Entry Index: mem_adr_i[5:2]
+-------+-------------+-------+-----------------------+------+
| Valid | Recent Used | Dirty | TAG (mem_adr_i[31:6]) | Data |
+-------+-------------+-------+-----------------------+------+
|  63   |     62      | 61 58 | 57                 32 | 31 0 |
+-------+-------------+-------+-----------------------+------+
*/

logic [`DCTE_WIDTH-1:0] cache_tab_0 [0:`CTE_NUM-1];
logic [`DCTE_WIDTH-1:0] cache_tab_1 [0:`CTE_NUM-1];

typedef enum logic [1:0] {
    STATE_IDLE = 0,
    STATE_DONE = 1,
    STATE_WAIT = 2
} state_t;

state_t state;
logic [5:0] fence_state;		// [5] cache tab num, [4:1]: cache tab index, [0]: done 
logic [1:0] cache_hit_flag;
reg [`DATABUS] rdata_reg;

always_ff @ (posedge clk_i) begin

	if (rst_i) begin
		state <= STATE_IDLE;
		fence_state <= 6'b0;
		cache_hit_flag <= 2'd2;
		rdata_reg <= `ZeroWord;

		for (int i = 0; i < `CTE_NUM; i++) begin // initialize empty btb
			cache_tab_0[i] <= `DCTE_WIDTH'b0; 
			cache_tab_1[i] <= `DCTE_WIDTH'b0; 
		end

	end

	else begin

		if (reset_cache_i) begin

			if (fence_state[0]) begin // disable cache table entry after writing back to memory
				if (!fence_state[5]) 	cache_tab_0[ fence_state[4:1] ] <= `Invalid;
				else					cache_tab_1[ fence_state[4:1] ] <= `Invalid;
			end


			if (fence_state[0]) begin // done, go to next cache table entry
				fence_state <= fence_state + 1;
			end 

			else if (!fence_state[0] && !fence_state[5] && // action, hit at way 0
			(!cache_tab_0[ fence_state[4:1] ][`DCTE_VALID] || cache_tab_0[ fence_state[4:1] ][`DCTE_DIRTY] == 4'b0000) )begin // don't need to write back
				fence_state <= fence_state + 1;
			end

			else if (!fence_state[0] && fence_state[5] && // action, hit at way 1
			(!cache_tab_1[ fence_state[4:1] ][`DCTE_VALID] || cache_tab_1[ fence_state[4:1] ][`DCTE_DIRTY] == 4'b0000) )begin // don't need to write back
				fence_state <= fence_state + 1;
			end

			else if (!fence_state[0] && wb_ack_i) begin // write back finish, go to done
				fence_state <= fence_state + 1;
			end

			
		end // reset cache 
		
		else begin
			case(state)

				STATE_IDLE: begin

					if (mem_ce_i) begin

						if (mem_adr_i[31] == 1'b1) begin //cacheable

							if ((cache_tab_0[ mem_adr_i[5:2] ][`DCTE_VALID] == `Valid) && 
								(cache_tab_0[ mem_adr_i[5:2] ][`DCTE_TAG] == mem_adr_i[31:6])) begin	// hit at way 0
								cache_hit_flag <= `HIT_0;
								state <= STATE_DONE;
							end

							else if ((cache_tab_1[ mem_adr_i[5:2] ][`DCTE_VALID] == `Valid) && 
								(cache_tab_1[ mem_adr_i[5:2] ][`DCTE_TAG] == mem_adr_i[31:6])) begin	// hit at way 1
								cache_hit_flag <= `HIT_1;
								state <= STATE_DONE;
							end

							else if ((cache_tab_0[ mem_adr_i[5:2] ][`DCTE_VALID] == `Invalid) && mem_we_i) begin
								cache_hit_flag <= `HIT_0;
								state <= STATE_DONE;
							end

							else if ((cache_tab_1[ mem_adr_i[5:2] ][`DCTE_VALID] == `Invalid) && mem_we_i) begin
								cache_hit_flag <= `HIT_1;
								state <= STATE_DONE;
							end

							else begin // miss
								cache_hit_flag <= `MISS;
								state <= STATE_WAIT;
							end

						end // cacheable

						else begin // not cacheable
							cache_hit_flag <= `MISS;
							state <= STATE_WAIT;
						end // not cacheable
							
					end

				end

				STATE_DONE: begin
					state <= STATE_IDLE;

					if (mem_adr_i[31] == 1) begin // update cacheable entry

						if (!mem_we_i && (cache_hit_flag == `MISS)) begin // read & miss
							// load into cache, mark as not dirty

							if (!cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED]) begin
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_VALID] <= `Valid;
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b1;
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b0;
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_DIRTY] <= 4'b0000;
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_TAG] <= mem_adr_i[31:6];	
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_DATA] <= rdata_reg;
							end
							else begin
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_VALID] <= `Valid;
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b1;
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b0;
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_DIRTY] <= 4'b0000;
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_TAG] <= mem_adr_i[31:6];
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_DATA] <= rdata_reg;
							end

						end // read & miss

						else if (mem_we_i) begin // write
							// write new data into cache, mark as dirty

							if (cache_hit_flag == `HIT_0) begin
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_VALID] <= `Valid;
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b1;
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b0;
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_DIRTY] <= mem_sel_i;
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_TAG] <= mem_adr_i[31:6];
								if (mem_sel_i[0] == 1'b1)
									cache_tab_0[ mem_adr_i[5:2] ][7:0] <= mem_dat_i[7:0];
								if (mem_sel_i[1] == 1'b1)
									cache_tab_0[ mem_adr_i[5:2] ][15:8] <= mem_dat_i[15:8];
								if (mem_sel_i[2] == 1'b1)
									cache_tab_0[ mem_adr_i[5:2] ][23:16] <= mem_dat_i[23:16];
								if (mem_sel_i[3] == 1'b1)
									cache_tab_0[ mem_adr_i[5:2] ][31:24] <= mem_dat_i[31:24];
							end

							else if (cache_hit_flag == `HIT_1) begin
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_VALID] <= `Valid;
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b1;
								cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b0;
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_DIRTY] <= mem_sel_i;
								cache_tab_1[ mem_adr_i[5:2] ][`DCTE_TAG] <= mem_adr_i[31:6];
								if (mem_sel_i[0] == 1'b1)
									cache_tab_1[ mem_adr_i[5:2] ][7:0] <= mem_dat_i[7:0];
								if (mem_sel_i[1] == 1'b1)
									cache_tab_1[ mem_adr_i[5:2] ][15:8] <= mem_dat_i[15:8];
								if (mem_sel_i[2] == 1'b1)
									cache_tab_1[ mem_adr_i[5:2] ][23:16] <= mem_dat_i[23:16];
								if (mem_sel_i[3] == 1'b1)
									cache_tab_1[ mem_adr_i[5:2] ][31:24] <= mem_dat_i[31:24];
							end

							else if (cache_hit_flag == `MISS) begin
								if (!cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED]) begin
									cache_tab_0[ mem_adr_i[5:2] ][`DCTE_VALID] <= `Valid;
									cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b1;
									cache_tab_1[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b0;
									cache_tab_0[ mem_adr_i[5:2] ][`DCTE_DIRTY] <= mem_sel_i;
									cache_tab_0[ mem_adr_i[5:2] ][`DCTE_TAG] <= mem_adr_i[31:6];
									if (mem_sel_i[0] == 1'b1)
										cache_tab_0[ mem_adr_i[5:2] ][7:0] <= mem_dat_i[7:0];
									if (mem_sel_i[1] == 1'b1)
										cache_tab_0[ mem_adr_i[5:2] ][15:8] <= mem_dat_i[15:8];
									if (mem_sel_i[2] == 1'b1)
										cache_tab_0[ mem_adr_i[5:2] ][23:16] <= mem_dat_i[23:16];
									if (mem_sel_i[3] == 1'b1)
										cache_tab_0[ mem_adr_i[5:2] ][31:24] <= mem_dat_i[31:24];
								end
								else begin
									cache_tab_1[ mem_adr_i[5:2] ][`DCTE_VALID] <= `Valid;
									cache_tab_1[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b1;
									cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED] <= 1'b0;
									cache_tab_1[ mem_adr_i[5:2] ][`DCTE_DIRTY] <= mem_sel_i;
									cache_tab_1[ mem_adr_i[5:2] ][`DCTE_TAG] <= mem_adr_i[31:6];
									if (mem_sel_i[0] == 1'b1)
										cache_tab_1[ mem_adr_i[5:2] ][7:0] <= mem_dat_i[7:0];
									if (mem_sel_i[1] == 1'b1)
										cache_tab_1[ mem_adr_i[5:2] ][15:8] <= mem_dat_i[15:8];
									if (mem_sel_i[2] == 1'b1)
										cache_tab_1[ mem_adr_i[5:2] ][23:16] <= mem_dat_i[23:16];
									if (mem_sel_i[3] == 1'b1)
										cache_tab_1[ mem_adr_i[5:2] ][31:24] <= mem_dat_i[31:24];
								end
							end
						end // write
					
					end
				end

				STATE_WAIT: begin
					if (wb_ack_i) begin
						rdata_reg <= wb_dat_i;
						state <= STATE_DONE;
					end
				end

				default: begin
					state <= STATE_IDLE;
				end

			endcase
		end // not reset cache
	end
end

always_comb begin
	if (rst_i) 	begin
		reset_cache_o = `Disable;
	end else begin		
		reset_cache_o = reset_cache_i;
	end
end


always_comb begin
	if (rst_i) begin
		// stallreq_o = `NoStop;
		mem_ack_o = `Disable;
		mem_dat_o = `ZeroWord;
		wb_ce_o = `Disable;
		wb_we_o = `Disable;
    	wb_adr_o = `ZeroWord;
		wb_prev_adr_o = `ZeroWord;
		wb_dat_o = `ZeroWord;
    	wb_sel_o = 4'b0000;
		wb_dirty_o = 4'b0000;
	end // reset

	else begin
		// default: do not visit memory
		wb_ce_o = `Disable;
		wb_we_o = mem_we_i;
		wb_adr_o = `ZeroWord;
		wb_prev_adr_o = `ZeroWord;
		wb_dat_o = `ZeroWord;
		wb_sel_o = 4'b0000;
		wb_dirty_o = 4'b0000;

		if (!reset_cache_i) begin

			mem_dat_o = rdata_reg;

			case(state)
				
				STATE_IDLE: begin

					if(mem_ce_i) begin

						// stallreq_o = `Stop;
						mem_ack_o = `Disable;
					
						if (mem_adr_i[31] == 1'b1) begin
							if ((cache_tab_0[ mem_adr_i[5:2] ][`DCTE_VALID] == `Valid) && 
								(cache_tab_0[ mem_adr_i[5:2] ][`DCTE_TAG] == mem_adr_i[31:6])) begin	// hit at way 0
								wb_ce_o = `Disable;
							end	else if ((cache_tab_1[ mem_adr_i[5:2] ][`DCTE_VALID] == `Valid) && 
								(cache_tab_1[ mem_adr_i[5:2] ][`DCTE_TAG] == mem_adr_i[31:6])) begin	// hit at way 1
								wb_ce_o = `Disable;
							end	else if ((cache_tab_0[ mem_adr_i[5:2] ][`DCTE_VALID] == `Invalid) && mem_we_i) begin
								wb_ce_o = `Disable;
							end else if ((cache_tab_1[ mem_adr_i[5:2] ][`DCTE_VALID] == `Invalid) && mem_we_i) begin
								wb_ce_o = `Disable;
							end 
						end

					end else begin 
						// stallreq_o = `NoStop;
						mem_ack_o = `Disable;
						wb_ce_o = `Disable;
					end
					
					mem_dat_o = `ZeroWord;
				end

				STATE_DONE: begin
					// stallreq_o = `NoStop;
					mem_ack_o = `Enable;
					
					if (!mem_we_i) begin // read
						if (cache_hit_flag == `HIT_0) begin // hit at way 0
							mem_dat_o = cache_tab_0[mem_adr_i[5:2]][`DCTE_DATA];
						end
						else if (cache_hit_flag == `HIT_1) begin // hit at way 1
							mem_dat_o = cache_tab_1[mem_adr_i[5:2]][`DCTE_DATA];
						end
						else begin // miss
							mem_dat_o = rdata_reg;
						end
					end
					
					else begin // write
						mem_dat_o = `ZeroWord;
					end
				end

				STATE_WAIT: begin
					// stallreq_o = `Stop;
					mem_ack_o = `Disable;
					wb_ce_o = `Enable;
					wb_adr_o = mem_adr_i;
					wb_sel_o = mem_sel_i;
					if (wb_ack_i)  begin
						mem_dat_o = wb_dat_i;
						// mem_ack_o = `Enable;
					end
					
					if (mem_adr_i[31] == 1'b1) begin // write old data in cache back to memory for cacheables
						if (!cache_tab_0[ mem_adr_i[5:2] ][`DCTE_RECENT_USED]) begin 
							wb_prev_adr_o = { cache_tab_0[ mem_adr_i[5:2] ][`DCTE_TAG], mem_adr_i[5:2], 2'b0};
							wb_dat_o = cache_tab_0[ mem_adr_i[5:2] ][`DCTE_DATA];
							wb_dirty_o = cache_tab_0[ mem_adr_i[5:2] ][`DCTE_DIRTY];
						end else begin
							wb_prev_adr_o = { cache_tab_1[ mem_adr_i[5:2] ][`DCTE_TAG], mem_adr_i[5:2], 2'b0};
							wb_dat_o = cache_tab_1[ mem_adr_i[5:2] ][`DCTE_DATA];
							wb_dirty_o = cache_tab_1[ mem_adr_i[5:2] ][`DCTE_DIRTY];
						end
					end
					else begin
						wb_dat_o = mem_dat_i;
					end
		
				end

				default: begin
					// stallreq_o = `NoStop;
					mem_ack_o = `Disable;
					mem_dat_o = `ZeroWord;
				end

			endcase

		end // not reset cache
		
		else begin // reset cache

			mem_dat_o = `ZeroWord;

			if (!fence_state[0] && !fence_state[5] && cache_tab_0[ fence_state[4:1] ][`DCTE_VALID] && 
				 cache_tab_0[ fence_state[4:1] ][`DCTE_DIRTY] != 4'b0000 ) begin // action

				// stallreq_o = `Stop;
				mem_ack_o = `Disable;
				wb_ce_o = `Enable;
				wb_we_o = `Enable;

				wb_adr_o = {cache_tab_0[ fence_state[4:1] ][`DCTE_TAG], fence_state[4:1], 2'b0};
				wb_dat_o = cache_tab_0[ fence_state[4:1] ][`DCTE_DATA];
				wb_sel_o = cache_tab_0[ fence_state[4:1] ][`DCTE_DIRTY];
			end
			
			else if (!fence_state[0] && fence_state[5] && cache_tab_1[ fence_state[4:1] ][`DCTE_VALID] && 
				 cache_tab_1[ fence_state[4:1] ][`DCTE_DIRTY] != 4'b0000 ) begin // action

				// stallreq_o = `Stop;
				mem_ack_o = `Disable;
				wb_ce_o = `Enable;
				wb_we_o = `Enable;

				wb_adr_o = {cache_tab_1[ fence_state[4:1] ][`DCTE_TAG], fence_state[4:1], 2'b0};
				wb_dat_o = cache_tab_1[ fence_state[4:1] ][`DCTE_DATA];
				wb_sel_o = cache_tab_1[ fence_state[4:1] ][`DCTE_DIRTY];
			end
			

			else begin // done

				// stallreq_o = (fence_state == 6'b111111) ? `NoStop : `Stop;
				mem_ack_o = (fence_state == 6'b111111) ? `Enable : `Disable;
				wb_ce_o = `Disable;
				wb_we_o = `Disable;

			end
		end
	end
end

endmodule