`include "define.sv"

module flash_controller (
    input wire             clk_i,
    input wire             rst_i,

    // wishbone master
    input wire             wb_cyc_i,
    input wire             wb_stb_i,
    input wire [`ADDRBUS]  wb_adr_i,
    input wire             wb_we_i,
    //input wire [3:0]       wb_sel_i,
    output reg [`DATABUS]  wb_dat_o,
    output reg             wb_ack_o,
    //input wire [`DATABUS]  wb_dat_i,
    
    // flash
    output reg             flash_rst,
    output reg             flash_oe,
    output reg             flash_ce,
    output reg             flash_we,
    output reg             flash_byte,
    output reg             flash_vpen, // Flash 写保护信号，低电平时不能擦除、烧�?
    output reg [`FLASHADDRBUS] flash_adr_o,
    inout wire [`FLASHDATABUS] flash_dat_i
);

reg [3:0] waitstate;
wire wb_access = wb_cyc_i & wb_stb_i;
wire wb_read = wb_access & (!wb_we_i);
reg [`FLASHDATABUS] flash_dat_i_comb;
reg flash_dat_t_comb;

assign flash_dat_i = flash_dat_t_comb ? 32'bz : 32'b0;
assign flash_dat_i_comb = flash_dat_i;
assign flash_dat_t_comb = wb_read;

assign flash_ce = !wb_access;
assign flash_oe = !wb_read;
assign flash_we = 1'b1;
assign flash_vpen = 1'b0;
assign flash_byte = 1'b1; //use 8 bits mode 
assign flash_rst = !rst_i;

always_ff @(posedge clk_i) begin
    if (rst_i) begin
        waitstate <= 4'h0;
        wb_ack_o <= 1'b0;
    end else if (wb_access == 1'b0) begin
        waitstate <= 4'h0;
        wb_ack_o <= 1'b0;
        wb_dat_o <= 32'b0;
    end else if (waitstate == 4'h0) begin
        wb_ack_o <= 1'b0;
        if (wb_access) begin
            waitstate <= waitstate + 4'h1;
        end
        flash_adr_o <= wb_adr_i[22:0];
    end else begin
        waitstate <= waitstate + 4'h1;
        if (waitstate == 4'h3) begin // currently use 3 period (each access aprox 75ns)
            wb_dat_o <= {16'h0000, flash_dat_i_comb};
            wb_ack_o <= 1'b1;
        end else if (waitstate == 4'h4) begin
            wb_ack_o <= 1'b0;
            waitstate <= 4'h0;
        end
    end
end
endmodule