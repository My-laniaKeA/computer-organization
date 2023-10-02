`include "define.sv"

module icache(
	input wire 				rst_i,
	input wire 				clk_i,

	// mem_master
	output reg 				wb_ce_o,
    output reg [`ADDRBUS] 	wb_adr_o,
	output reg [`DATABUS] 	wb_dat_o,
    output reg 				wb_we_o,
    output reg [3:0] 		wb_sel_o,
    input wire [`DATABUS] 	wb_dat_i,
	input wire 				wb_ack_i,

	// if
	input wire [`ADDRBUS] 	if_adr_i,	// pc
	input wire 				if_ce_i,

	// itlb
	output reg [`DATABUS] 	id_dat_o, 	// inst
	output reg				tlb_ack_o,

	// id
	input wire				reset_cache_i
);

// Use 2-way set associate cache

/* ---------------------- Cache Table Entry ---------------------- */
/*
Entry Index: if_adr_i[5:2]
+-------+-------------+----------------------+------+
| Valid | Recent Used | TAG (if_adr_i[31:6]) | Data |
+-------+-------------+----------------------+------+
|  59   |     58      | 57                32 | 31 0 |
+-------+-------------+----------------------+------+
*/

logic [`ICTE_WIDTH-1:0] cache_tab_0 [0:`CTE_NUM-1];
logic [`ICTE_WIDTH-1:0] cache_tab_1 [0:`CTE_NUM-1];
logic [`ADDRBUS] old_if_adr;
logic [1:0] cache_hit_flag;

// look up Cache Table for next pc
always_comb begin
	if (rst_i) begin
		wb_ce_o = `Disable;
    	wb_adr_o = `ZeroWord;
		id_dat_o = `ZeroWord;
		cache_hit_flag = `MISS;

	end else begin
		if ((cache_tab_0[ if_adr_i[5:2] ][`ICTE_VALID] == `Valid) && 
			(cache_tab_0[ if_adr_i[5:2] ][`ICTE_TAG] == if_adr_i[31:6])) begin	// hit at way 0
			id_dat_o = cache_tab_0[if_adr_i[5:2]][`ICTE_DATA];
			wb_ce_o	 = `Disable;
			wb_adr_o = `ZeroWord;
			cache_hit_flag = `HIT_0;

		end else if ((cache_tab_1[if_adr_i[5:2]][`ICTE_VALID] == `Valid) && 
			(cache_tab_1[if_adr_i[5:2]][`ICTE_TAG] == if_adr_i[31:6])) begin		// hit at way 1
			id_dat_o = cache_tab_1[ if_adr_i[5:2] ][`ICTE_DATA];
			wb_ce_o	 = `Disable;
			wb_adr_o = `ZeroWord;
			cache_hit_flag = `HIT_1;

		end else begin 	// miss
			wb_ce_o	 = `Enable;
			wb_adr_o = if_adr_i;
			id_dat_o = wb_dat_i;
			cache_hit_flag = `MISS;
		end
	end
end


// update Cache Table
always_ff @(posedge clk_i) begin
	if (rst_i || reset_cache_i) begin

		for (int i = 0; i < `CTE_NUM; i++) begin // initialize empty btb
			cache_tab_0[i] <= `ICTE_WIDTH'b0; 
			cache_tab_1[i] <= `ICTE_WIDTH'b0; 
		end
		old_if_adr <= `ZeroWord;

	end else begin
		old_if_adr <= if_adr_i;

		if ((old_if_adr != if_adr_i) && !wb_ce_o) begin	// cache hit
			cache_tab_0[ if_adr_i[5:2] ][`ICTE_RECENT_USED] <= !cache_hit_flag;
			cache_tab_1[ if_adr_i[5:2] ][`ICTE_RECENT_USED] <= cache_hit_flag;
		end

		else if (wb_ack_i) begin	// cache miss & fetch from mem

			if (!cache_tab_0[ if_adr_i[5:2] ][`ICTE_RECENT_USED]) begin
				cache_tab_0[ if_adr_i[5:2] ][`ICTE_VALID] <= `Valid;
				cache_tab_0[ if_adr_i[5:2] ][`ICTE_TAG] <= if_adr_i[31:6];
				cache_tab_0[ if_adr_i[5:2] ][`ICTE_DATA] <= wb_dat_i;
				cache_tab_0[ if_adr_i[5:2] ][`ICTE_RECENT_USED] <= 1'b1;
				cache_tab_1[ if_adr_i[5:2] ][`ICTE_RECENT_USED] <= 1'b0;
				
			end else begin
				cache_tab_1[ if_adr_i[5:2] ][`ICTE_VALID] <= `Valid;
				cache_tab_1[ if_adr_i[5:2] ][`ICTE_TAG] <= if_adr_i[31:6];
				cache_tab_1[ if_adr_i[5:2] ][`ICTE_DATA] <= wb_dat_i;
				cache_tab_0[ if_adr_i[5:2] ][`ICTE_RECENT_USED] <= 1'b0;
				cache_tab_1[ if_adr_i[5:2] ][`ICTE_RECENT_USED] <= 1'b1;
			end
	
		end // wb_ack_i

		
	end

end

// icache only reads memory
assign wb_dat_o = `ZeroWord;
assign wb_sel_o = 4'b1111;
assign wb_we_o = `Disable;

// pass ack
assign tlb_ack_o = (cache_hit_flag == `MISS) ? wb_ack_i : `Enable;

endmodule


