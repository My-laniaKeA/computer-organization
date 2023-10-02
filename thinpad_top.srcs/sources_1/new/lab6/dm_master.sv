`include "define.sv"

module dm_master (
    input wire             clk_i,
    input wire             rst_i,

    // wishbone master
    output reg             wb_cyc_o,
    output reg             wb_stb_o,
    input wire             wb_ack_i,
    output reg [`ADDRBUS]  wb_adr_o,
    output reg [`DATABUS]  wb_dat_o,
    input wire [`DATABUS]  wb_dat_i,
    output reg [3:0]       wb_sel_o,
    output reg             wb_we_o,

    // ctrl
    // input wire [5:0]       stall_i,
    input wire             flush_i,

    // cpu
    input wire             cpu_ce_i,
	input wire			   cpu_we_i,
    input wire [`DATABUS]  cpu_data_i,
    input wire [`ADDRBUS]  cpu_addr_i,
	input wire [`ADDRBUS]  cpu_prev_addr_i,
    input wire [3:0]       cpu_sel_i,
    output reg [`DATABUS]  cpu_data_o,
	output reg			   cpu_ack_o,
	// cache
	input wire [3:0]	   cache_dirty_i,
	input wire			   reset_cache_i
	// stall
    // output reg             stallreq_o
);

typedef enum logic [1:0] {
    STATE_IDLE = 0,
    STATE_WRITE_ACTION = 1,
    STATE_READ_ACTION = 2,
	STATE_DONE = 3
} state_t;

state_t state;
reg cacheable;
assign cacheable = !reset_cache_i && (cpu_addr_i[31] == 1'b1);

always_ff @ (posedge clk_i) begin
    if (rst_i) begin
        state <= STATE_IDLE;

    end else begin
        case (state)

            STATE_IDLE: begin
                if(cpu_ce_i && !flush_i) begin

					if (cacheable) begin 
						if (cache_dirty_i != 4'b0000) begin
							state <= STATE_WRITE_ACTION;
						end else begin
							state <= STATE_READ_ACTION;
						end
					end

					else begin
						if (cpu_we_i) begin
							state <= STATE_WRITE_ACTION;
						end else begin
							state <= STATE_READ_ACTION;
						end
					end
                end
            end

            STATE_WRITE_ACTION: begin
                if (wb_ack_i) begin
					state <= STATE_DONE;
				end else if (flush_i) begin
					state <= STATE_DONE;
				end                
            end

			STATE_READ_ACTION: begin
                if (wb_ack_i) begin
					state <= STATE_DONE;
				end else if (flush_i) begin
					state <= STATE_DONE;
				end                
            end

			STATE_DONE: begin
				if (cacheable && !cpu_we_i) begin
					state <= STATE_READ_ACTION;
				end else begin
					state <= STATE_IDLE;
				end
			end

            default: begin
				state <= STATE_IDLE;
			end
        endcase
    end
end


always_comb begin
    if(rst_i) begin
		// wishbone
		wb_stb_o = `Disable;
		wb_cyc_o = `Disable;
		wb_adr_o = `ZeroWord;
		wb_dat_o = `ZeroWord;
		wb_sel_o = 4'b0;
		wb_we_o  = `Disable;
		// cpu
        cpu_data_o = `ZeroWord;
		cpu_ack_o  = `Disable;
    end // rst_i

	else begin
		wb_adr_o = `ZeroWord;
		wb_dat_o = `ZeroWord;
		wb_sel_o = 4'b0;
		wb_we_o  = `Disable;
		cpu_ack_o  = `Disable;
        cpu_data_o = wb_dat_i;

        case(state)

            STATE_IDLE: begin
				wb_stb_o = `Disable;
            	wb_cyc_o = `Disable;
            end

			STATE_WRITE_ACTION: begin
				wb_stb_o = `Enable;
            	wb_cyc_o = `Enable;

				wb_we_o  = 1'b1;
				wb_sel_o = (cacheable) ? cache_dirty_i : cpu_sel_i;
				wb_adr_o = (cacheable) ? cpu_prev_addr_i : cpu_addr_i;
                wb_dat_o = cpu_data_i;

				cpu_ack_o = (cacheable && !cpu_we_i) ? `Disable : wb_ack_i;
                
			end

            STATE_READ_ACTION: begin
				wb_stb_o = `Enable;
            	wb_cyc_o = `Enable;

				wb_we_o  = 1'b0;
				wb_sel_o = (cacheable) ? 4'b1111 : cpu_sel_i;
				wb_adr_o = cpu_addr_i;
                wb_dat_o = `ZeroWord;

				cpu_ack_o = wb_ack_i;
                
            end

			STATE_DONE: begin
				wb_stb_o = `Disable;
				wb_cyc_o = `Disable;
			end


            default: begin
				// wishbone
				wb_stb_o = `Disable;
				wb_cyc_o = `Disable;
				wb_adr_o = `ZeroWord;
				wb_dat_o = `ZeroWord;
				wb_sel_o = 4'b0;
				wb_we_o  = `Disable;
				// cpu
				cpu_data_o = `ZeroWord;
				cpu_ack_o  = `Disable;
			end
        endcase
    end
end


endmodule
