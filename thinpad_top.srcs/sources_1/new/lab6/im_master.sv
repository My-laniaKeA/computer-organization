`include "define.sv"

module im_master (
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
    input wire [5:0]       stall_i,
    input wire             flush_i,

    // cpu
    input wire             cpu_ce_i,
    input wire [`DATABUS]  cpu_data_i,
    input wire [`ADDRBUS]  cpu_addr_i,
    input wire             cpu_we_i,
    input wire [3:0]       cpu_sel_i,
    output reg [`DATABUS]  cpu_data_o,
	output reg			   cpu_ack_o

    // output reg             stallreq
);

typedef enum logic [2:0] {
    STATE_IDLE = 0,
    STATE_SRAM_ACTION = 1,
    STATE_WAIT = 2,
    STATE_FLUSH = 3,
    STATE_DONE = 4
} state_t;

state_t state;
logic [`DATABUS] rdata_reg;

always_ff @ (posedge clk_i) begin
    if (rst_i) begin
        state <= STATE_IDLE;
        // wb_cyc_o <= 1'b0;
        // wb_stb_o <= 1'b0;
        // wb_adr_o <= `ZeroWord;
        // wb_dat_o <= `ZeroWord;
        // wb_sel_o <= 4'b0;
        // wb_we_o <= `Disable;
        rdata_reg <= `ZeroWord;
    end else begin
        case (state)
            STATE_IDLE: begin
                if(cpu_ce_i && !flush_i) begin
                    // wb_stb_o <= 1'b1;
                    // wb_cyc_o <= 1'b1;
                    // wb_adr_o <= cpu_addr_i;
                    // wb_dat_o <= cpu_data_i;
                    // wb_we_o <= cpu_we_i;
                    // wb_sel_o <= cpu_sel_i;
                    state <= STATE_SRAM_ACTION;
                end
            end
            STATE_SRAM_ACTION: begin
                if(wb_ack_i)begin
                    // wb_stb_o <= 1'b0;
                    // wb_cyc_o <= 1'b0;
                    // wb_adr_o <= `ZeroWord;
                    // wb_dat_o <= `ZeroWord;
                    // wb_we_o <= `Disable;
                    // wb_sel_o <= 4'b0000;
                    state <= STATE_DONE;
                    if(cpu_we_i == `Disable) begin
                        rdata_reg <= wb_dat_i;
                    end
                    if(stall_i[1] && stall_i[4]) begin //FIXME
                        state <= STATE_WAIT;
                    end
                end else if(flush_i) begin
                    state <= STATE_FLUSH;
                end
            end
            STATE_FLUSH: begin
                if(wb_ack_i) begin
                    // wb_stb_o <= 1'b0;
                    // wb_cyc_o <= 1'b0;
                    // wb_adr_o <= `ZeroWord;
                    // wb_dat_o <= `ZeroWord;
                    // wb_we_o <= `Disable;
                    // wb_sel_o <= 4'b0000;
                    state <= STATE_IDLE;
                end
            end
            STATE_WAIT: begin
                 if (stall_i == 6'b000000) begin
                    state <= STATE_IDLE;
                end
            end
            STATE_DONE: begin
                state <= STATE_IDLE;
            end
            default: ;
        endcase
    end
end

/*
always_ff @ (posedge clk_i) begin
    if(rst_i) begin
        stallreq <= `NoStop;
        cpu_data_o <= `ZeroWord;
    end else begin
        stallreq <= `NoStop;
        cpu_data_o <= rdata_reg;
        case(state)
            STATE_IDLE: begin
                if(cpu_ce_i && !flush_i) begin
                    stallreq <= `Stop;
                end
            end
            STATE_SRAM_ACTION: begin
                if(wb_ack_i) begin
                    stallreq <= `Stop;
                    if(wb_we_o == `Disable) begin
                        cpu_data_o <= wb_dat_i;
                    end
                end else begin
                    stallreq <= `Stop;
                end
            end
            STATE_WAIT: begin
                stallreq <= `Stop;
            end
            STATE_DONE: begin
                stallreq <= `NoStop;
            end
            default;
        endcase
    end
end
*/

always_comb begin
    if(rst_i) begin
        // stallreq = `NoStop;
        wb_cyc_o = 1'b0;
        wb_stb_o = 1'b0;
        wb_adr_o = `ZeroWord;
        wb_dat_o = `ZeroWord;
        wb_sel_o = 4'b0;
        wb_we_o = `Disable;
        cpu_data_o = `ZeroWord;
		cpu_ack_o = `Disable;
    end else begin
        // stallreq = `NoStop;
		wb_cyc_o = 1'b0;
        wb_stb_o = 1'b0;
        wb_adr_o = `ZeroWord;
        wb_dat_o = `ZeroWord;
        wb_sel_o = 4'b0;
        wb_we_o = `Disable;
        cpu_data_o = rdata_reg;
		cpu_ack_o = wb_ack_i;
        case(state)
            STATE_IDLE: begin
                if(cpu_ce_i && !flush_i) begin
                    // stallreq = `Stop;
                end
            end
            STATE_SRAM_ACTION: begin
				wb_cyc_o = 1'b1;
				wb_stb_o = 1'b1;
				wb_adr_o = cpu_addr_i;
				wb_dat_o = cpu_data_i;
				wb_sel_o = cpu_sel_i;
				wb_we_o  = cpu_we_i;
                if(wb_ack_i) begin
                    // stallreq = `Stop;
                    if(wb_we_o == `Disable) begin
                        cpu_data_o = wb_dat_i;
                    end
                end else begin
                    // stallreq = `Stop;
                end
            end
            STATE_FLUSH: begin
				wb_cyc_o = 1'b1;
				wb_stb_o = 1'b1;
				wb_adr_o = cpu_addr_i;
				wb_dat_o = cpu_data_i;
				wb_sel_o = cpu_sel_i;
				wb_we_o  = cpu_we_i;
				// cpu_ack_o = `Disable;
                // stallreq = `Stop;
            end
            STATE_WAIT: begin
				wb_cyc_o = 1'b0;
				wb_stb_o = 1'b0;
				wb_adr_o = `ZeroWord;
				wb_dat_o = `ZeroWord;
				wb_sel_o = 4'b0000;
				wb_we_o  = `Disable;
                // stallreq = `NoStop;
            end
            STATE_DONE: begin
                // stallreq = `NoStop;
            end
            default;
        endcase
    end
end

endmodule
