`include "define.sv"

module mem_master_arbiter (
    input wire             	rst_i,

    // cache
    input wire             	cache_ce_i,
	input wire [`ADDRBUS]  	cache_adr_i,
	input wire [3:0]       	cache_sel_i,
	input wire             	cache_we_i,
    input wire [`DATABUS]  	cache_dat_i,
	input wire[`ADDRBUS]  	cache_prev_adr_i,	// only for dm_master
	input wire[3:0]       	cache_dirty_i,		// only for dm_master
	input wire				cache_reset_cache_i,// only for dm_master
    
    output reg [`DATABUS]  	cache_dat_o,
	output reg			   	cache_ack_o,

	// tlb
	input wire             	tlb_ce_i,
	input wire [`ADDRBUS]  	tlb_adr_i,
	input wire [3:0]       	tlb_sel_i,
	input wire             	tlb_we_i,
    input wire [`DATABUS]  	tlb_dat_i,
    
    output reg [`DATABUS]  	tlb_dat_o,
	output reg			   	tlb_ack_o,

    // mem_master
    output reg				mm_ce_o,
    output reg[`ADDRBUS]  	mm_adr_o,
	output reg[3:0]       	mm_sel_o,
	output reg            	mm_we_o,
    output reg[`DATABUS]  	mm_dat_o,
	output reg[`ADDRBUS]  	mm_prev_adr_o,		// only for dm_master
	output reg[3:0]       	mm_dirty_o,			// only for dm_master
	output reg				mm_reset_cache_o,	// only for dm_master
    
   	input wire [`DATABUS] 	mm_dat_i,
	input wire			  	mm_ack_i
);

always_comb begin
	if (rst_i) begin
		cache_dat_o = `ZeroWord;
		cache_ack_o = `Disable;
		tlb_dat_o	= `ZeroWord;
		tlb_ack_o	= `Disable;

		mm_ce_o		= `Disable;
    	mm_adr_o	= `ZeroWord;
		mm_sel_o	= 4'b0000;
		mm_we_o		= `Disable;
    	mm_dat_o	= `ZeroWord;
		mm_prev_adr_o = `ZeroWord;
		mm_dirty_o	= 4'b0000;
		mm_reset_cache_o = `Disable;
	end

	else begin
		if (tlb_ce_i) begin
			cache_dat_o = `ZeroWord;
			cache_ack_o = `Disable;
			tlb_dat_o	= mm_dat_i;
			tlb_ack_o	= mm_ack_i;

			mm_ce_o		= tlb_ce_i;
			mm_adr_o	= tlb_adr_i;
			mm_sel_o	= tlb_sel_i;
			mm_we_o		= tlb_we_i;
			mm_dat_o	= tlb_dat_i;
			
			mm_prev_adr_o = `ZeroWord;
			mm_dirty_o	= 4'b0000;
			mm_reset_cache_o = `Disable;
		end

		else if (cache_ce_i) begin
			cache_dat_o = mm_dat_i;
			cache_ack_o = mm_ack_i;
			tlb_dat_o	= `ZeroWord;
			tlb_ack_o	= `Disable;

			mm_ce_o		= cache_ce_i;
			mm_adr_o	= cache_adr_i;
			mm_sel_o	= cache_sel_i;
			mm_we_o		= cache_we_i;
			mm_dat_o	= cache_dat_i;

			mm_prev_adr_o = cache_prev_adr_i;
			mm_dirty_o	= cache_dirty_i;
			mm_reset_cache_o = cache_reset_cache_i;
		end

		else begin
			cache_dat_o = `ZeroWord;
			cache_ack_o = `Disable;
			tlb_dat_o	= `ZeroWord;
			tlb_ack_o	= `Disable;

			mm_ce_o		= `Disable;	
			mm_adr_o	= `ZeroWord;
			mm_sel_o	= 4'b0000;
			mm_we_o		= `Disable;
			mm_dat_o	= `ZeroWord;

			mm_prev_adr_o = `ZeroWord;
			mm_dirty_o	= 4'b0000;
			mm_reset_cache_o = `Disable;
		end
		
	end
end
endmodule