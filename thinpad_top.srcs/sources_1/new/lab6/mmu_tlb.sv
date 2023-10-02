`include "define.sv"

module mmu_tlb(
	input wire 				rst_i,
	input wire 				clk_i,

	input wire				is_if_tlb_i,

	// ctrl
	input wire				flush_i,
	output reg				stallreq_o,

	// csr
	input wire [1:0]		mode_i,			// user mode or kenel mode
	input wire [`ADDRBUS]	pt_base_adr_i,	// base (physical) address for page table
	output reg				exception_o,

	// cpu
	input wire 				cpu_ce_i,
	input wire [`ADDRBUS] 	cpu_adr_i,	
	input wire [`DATABUS]	cpu_dat_i,
	input wire				cpu_we_i,
	input wire [3:0]		cpu_sel_i,
	input wire				cpu_rst_cache_i,
	output reg [`DATABUS]	cpu_dat_o,

	// memory master
	output reg 				wb_ce_o,
	output reg 				wb_we_o,
    output reg [`ADDRBUS] 	wb_adr_o,
	output reg [`DATABUS] 	wb_dat_o,
    output reg [3:0] 		wb_sel_o,
    input wire [`DATABUS] 	wb_dat_i,
	input wire 				wb_ack_i,

	// cache
	output reg 				cache_ce_o,
	output reg [`ADDRBUS] 	cache_adr_o,	// physical address after translation	
	output reg [`DATABUS]	cache_dat_o,
	output reg				cache_we_o,
	output reg [3:0]		cache_sel_o,
	output reg				cache_rst_cache_o,
	input wire [`DATABUS]	cache_dat_i,
	input wire				cache_ack_i,

	// id
	input wire				reset_tlb_i
);

// Use direct-mapping tlb

/* ---------------------- TLB Entry ---------------------- */
/*
Entry Index: vadr[16:12]
+-------+----+----+----+-----------------------+--------------------+--------------------+
| Valid | X  | W  | R  | VPN_TAG (vadr[31:17]) | PPN1 (padr[31:22]) | PPN0 (padr[21:12]) |
+-------+----+----+----+-----------------------+--------------------+--------------------+
|  38   | 37 | 36 | 35 | 34                 20 | 19              10 | 9                0 |
+-------+----+----+----+-----------------------+--------------------+--------------------+
*/

logic [`TLBE_WIDTH-1:0] tlb [0:`TLBE_NUM-1];

typedef enum logic [2:0] {
    STATE_IDLE = 0,
    STATE_PAGETABLE_ACTION = 1,
	STATE_PAGETABLE_PAUSE = 2,
	STATE_CACHE = 3,
    STATE_DONE = 4,
	STATE_FLUSH = 5
} state_t;

state_t state;

logic rst_cache_reg;
logic [`ADDRBUS] pt_base_reg;
logic [`ADDRBUS] pte_reg;
logic pt_level_reg;

always_ff @ (posedge clk_i) begin

	if (rst_i) begin
		cache_adr_o <= `ZeroWord;
		state		<= STATE_IDLE;
		exception_o <= `Disable;
		cpu_dat_o	<= `ZeroWord;
		pt_base_reg	<= `ZeroWord;
		pte_reg		<= `ZeroWord;
		pt_level_reg <= 1'b1;

		for (int i = 0; i < `TLBE_NUM; i++) begin // initialize empty tlb
			tlb[i] <= `TLBE_WIDTH'b0; 
		end

	end

	else begin

		if (reset_tlb_i) begin
			for (int i = 0; i < `TLBE_NUM; i++) begin // initialize empty tlb
				tlb[i] <= `TLBE_WIDTH'b0; 
			end	
		end // reset tlb
		
		case(state)

			STATE_IDLE: begin

				exception_o <= `Disable;

				if (!flush_i) begin

					if (cpu_ce_i) begin

						rst_cache_reg <= `Disable;
						if (cpu_adr_i[29:28] == 2'b01 || cpu_adr_i[29:28] == 2'b10 || 	// uart, blockram, flash
							mode_i == `KERNEL_MODE ) begin								// disable page table
							cache_adr_o <= cpu_adr_i;
							state 		<= STATE_CACHE;
						end

						else if ((tlb[ cpu_adr_i[16:12] ][`TLBE_VALID] == `Valid) &&
								(tlb[ cpu_adr_i[16:12] ][`TLBE_VPN_TAG] ==  cpu_adr_i[31:17]))	begin	// TLB hit
							cache_adr_o <= {tlb[ cpu_adr_i[16:12] ][`TLBE_PPN1], tlb[ cpu_adr_i[16:12] ][`TLBE_PPN0], cpu_adr_i[`PAGE_OFFSET]};
							state 		<= STATE_CACHE;
						end

						// unmapped address
						else if ((cpu_adr_i >= 32'h0030_0000 && cpu_adr_i < 32'h7fc1_0000) ||
							(cpu_adr_i >= 32'h8000_2000 && cpu_adr_i < 32'h8010_0000) ||
							(cpu_adr_i >= 32'h8010_1000)) begin
							exception_o <= `Enable;
							state 		<= STATE_IDLE;
						end
						
						else begin	// TLB miss
							state 		<= STATE_PAGETABLE_ACTION;
							pt_base_reg	<= pt_base_adr_i;
							pt_level_reg <= 1'b1;
						end
						
					end // cpu_ce_i

					else if (cpu_rst_cache_i) begin	// reset cache
						cache_adr_o <= `ZeroWord;
						state 		<= STATE_CACHE;
						rst_cache_reg <= cpu_rst_cache_i;
					end

				end // not flush_i
			end

			STATE_PAGETABLE_ACTION: begin

				if (flush_i) begin
					state <= STATE_FLUSH;
				end

				else begin // not flush

					if (wb_ack_i) begin

						pte_reg <= wb_dat_i;
						state 	<= STATE_PAGETABLE_PAUSE;	

					end // wb_ack_i

				end // not flush
					
			end

			STATE_PAGETABLE_PAUSE: begin

				// invalid PTE: page fault
				if ( !(pte_reg[`PTE_V]) || (pte_reg[`PTE_W] && !pte_reg[`PTE_R]) ) begin
					exception_o <= `Enable;
					state 		<= STATE_IDLE;
				end

				else begin // valid PTE

					// update TLB
					if (pt_level_reg == 1'b0) begin
						tlb[ cpu_adr_i[16:12] ][`TLBE_VALID] 	<= `Valid;
						tlb[ cpu_adr_i[16:12] ][`TLBE_PPN1]  	<= pte_reg[`PTE_PPN1];
						tlb[ cpu_adr_i[16:12] ][`TLBE_PPN0]  	<= pte_reg[`PTE_PPN0];
						tlb[ cpu_adr_i[16:12] ][`TLBE_AUTH]	 	<= pte_reg[`PTE_AUTH];
						tlb[ cpu_adr_i[16:12] ][`TLBE_VPN_TAG] 	<= cpu_adr_i[31:17];

					end
										

					if (pte_reg[`PTE_R] || pte_reg[`PTE_X]) begin // leaf PTE
						cache_adr_o <= { pte_reg[`PTE_PPN1], pte_reg[`PTE_PPN0], cpu_adr_i[`PAGE_OFFSET] };			
						state 		<= STATE_CACHE;
					end

					else begin // not leaf PTE

						if (pt_level_reg == 1'b0) begin // level depletes, still not leaf
							exception_o <= `Enable;
							state 		<= STATE_IDLE;
						end

						else begin
							pt_level_reg <= pt_level_reg - 1;
							state 		 <= STATE_PAGETABLE_ACTION;
							pt_base_reg <= { pte_reg[`PTE_PPN1], pte_reg[`PTE_PPN0], 12'b0 };
						end		

					end // not leaf PTE
					
				end // valid PTE

			end

			STATE_CACHE: begin
				if (flush_i) begin
					state <= STATE_FLUSH;
				end else begin

					// write protection or execute protection
					if (tlb[ cpu_adr_i[16:12] ][`TLBE_VALID]) begin
						if ((!is_if_tlb_i && cpu_we_i && !tlb[ cpu_adr_i[16:12] ][`TLBE_W]) || 
							(is_if_tlb_i && !tlb[ cpu_adr_i[16:12] ][`TLBE_X])) begin
							exception_o <= `Enable;
							state 		<= STATE_IDLE;
						end
					end
					
					if (cache_ack_i) begin
						state 		<= STATE_DONE;
						cpu_dat_o	<= cache_dat_i;
						rst_cache_reg <= `Disable;
					end // cache_ack_i
				end // not flush_i
			end

			STATE_DONE: begin
				state <= STATE_IDLE;
			end

			STATE_FLUSH: begin
				if (wb_ack_i || cache_ack_i) begin
					state <= STATE_IDLE;
				end
			end

			default: begin // unreachable
				cache_adr_o <= `ZeroWord;
				state		<= STATE_IDLE;
				exception_o <= `Disable;
			end

		endcase
		
	end
end


always_comb begin
	if (rst_i) begin
		stallreq_o = `NoStop;

		// wb default signals
		wb_ce_o = `Disable;
		wb_adr_o = `ZeroWord;
		wb_we_o = `Disable;
		wb_dat_o = `ZeroWord;
		wb_sel_o = 4'b0000;
		
		// cache default signals
		cache_ce_o = `Disable;
		cache_we_o = `Disable;
		cache_dat_o = `ZeroWord;
		cache_sel_o = 4'b0000;
		cache_rst_cache_o = `Disable;
	end // reset

	else begin
		// wb default signals
		wb_ce_o = `Disable;
		wb_adr_o = `ZeroWord;
		wb_we_o = `Disable;
		wb_dat_o = `ZeroWord;
		wb_sel_o = 4'b0000;
		
		// cache default signals
		cache_ce_o = `Disable;
		cache_we_o = `Disable;
		cache_dat_o = `ZeroWord;
		cache_sel_o = 4'b0000;
		cache_rst_cache_o = `Disable;

		case(state)
			STATE_IDLE: begin
				stallreq_o = (cpu_ce_i && !flush_i) ? `Stop : `NoStop;
			end

			STATE_PAGETABLE_ACTION: begin
				stallreq_o = `Stop;
				wb_ce_o = `Enable;				
				if (pt_level_reg == 1'b1)
					wb_adr_o = pt_base_reg + { 20'b0, cpu_adr_i[`VPN_1], 2'b00 };
				else
					wb_adr_o = pt_base_reg + { 20'b0, cpu_adr_i[`VPN_0], 2'b00 };
				wb_sel_o = 4'b1111;
			end

			STATE_PAGETABLE_PAUSE: begin
				stallreq_o = `Stop;
			end

			STATE_CACHE: begin
				stallreq_o = `Stop;
				cache_ce_o = `Enable;
				cache_dat_o = cpu_dat_i;
				cache_we_o = cpu_we_i;
				cache_sel_o = cpu_sel_i;
				cache_rst_cache_o = rst_cache_reg;
			end

			STATE_DONE: begin
				stallreq_o = `NoStop;
			end

			STATE_FLUSH: begin
				stallreq_o = `Stop;
			end

			default: begin
				stallreq_o = `NoStop;
			end
		endcase
	end
end

endmodule