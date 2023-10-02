`include "define.sv"

module bram_controller (
    input wire             clk_i,
    input wire             rst_i,

    // wishbone master
    input wire             wb_cyc_i,
    input wire             wb_stb_i,
    input wire             wb_we_i,
    input wire [`ADDRBUS]  wb_adr_i,
    input wire [`DATABUS]  wb_dat_i,
    output reg [`DATABUS]  wb_dat_o,
    output reg             wb_ack_o,

    // VGA
    // input wire [`BRAMADDRBUS]  vga_adr_i,
    // output reg [`BRAMDATABUS]  vga_dat_o,
    
    // bram
    output reg                 bram_we,
    output reg [`BRAMADDRBUS]  bram_waddr,
    output reg [`BRAMDATABUS]  bram_wdata
    // output reg [`BRAMADDRBUS]  bram_raddr,
    // input wire [`BRAMDATABUS]  bram_rdata
);

reg [3:0] waitstate_write;
reg [3:0] waitstate_read;
wire wb_access = wb_cyc_i & wb_stb_i;

assign bram_we = wb_we_i;

// write
always_ff @(posedge clk_i) begin
    if (rst_i) begin
        waitstate_write <= 4'h0;
        wb_ack_o <= 1'b0;
    end else if (wb_access == 1'b0) begin
        waitstate_write <= 4'h0;
        wb_ack_o <= 1'b0;
        wb_dat_o <= 32'b0;
    end else if (waitstate_write == 4'h0) begin
        wb_ack_o <= 1'b0;
        if (wb_access) begin
            waitstate_write <= waitstate_write + 4'h1;
        end
        bram_waddr <= wb_adr_i[18:0];
        bram_wdata <= wb_dat_i[7:0];
    end else begin
        waitstate_write <= waitstate_write + 4'h1;
        if (waitstate_write == 4'h2) begin // currently use 2 period
            wb_ack_o <= 1'b1;
        end else if (waitstate_write == 4'h3) begin
            wb_ack_o <= 1'b0;
            waitstate_write <= 4'h0;
        end
    end
end

// read
// always_ff @(posedge clk_i) begin
//     if (rst_i) begin
//         waitstate_read <= 4'h0;
//     end else if (waitstate_read == 4'h0) begin
//         bram_raddr <= vga_adr_i;
//         waitstate_read <= waitstate_read + 4'h1;
//     end else begin
//         waitstate_read <= waitstate_read + 4'h1;
//         if (waitstate_read == 4'h2) begin // currently use 2 period
//             vga_dat_o <= bram_rdata;
//         //end else if (waitstate_read == 4'h3) begin
//             waitstate_read <= 4'h0;
//         end
//     end
// end
endmodule