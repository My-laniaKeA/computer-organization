module vga_controller(
    input wire clk,
    input wire [7:0]   bram_dat_i,
    output reg [18:0]  addr,  //log2 480000
    output wire [2:0]   red,    // 红色像素�?????3 �?????
    output wire [2:0]   green,  // 绿色像素�?????3 �?????
    output wire [1:0]   blue,   // 蓝色像素�?????2 �?????
    output wire         hsync,  // 行同步（水平同步）信�?????
    output wire         vsync,  // 场同步（垂直同步）信�?????
    output wire         de
);

wire [11:0] col;
wire [11:0] row;
reg  [7:0]  bram_dat_i_reg;

always @(posedge clk) begin
    bram_dat_i_reg <= bram_dat_i;
end

assign red = bram_dat_i_reg[2:0];
assign green = bram_dat_i_reg[5:3];
assign blue = bram_dat_i_reg[7:6];

// assign red = 3'b111;
// assign green = 3'b000;
// assign blue = 2'b00;

vga u_vga(
    .clk(clk),
    .hsync(hsync),
    .vsync(vsync),
    .hdata(col),
    .vdata(row),
    .data_enable(de)
);

//pixel address
always @(posedge clk) begin
    if ((col == 1'b0) && (row == 1'b0)) begin
        addr <= 19'b0;
end else begin
    if (de) begin
        addr <= addr + 1'b1;
    end
end
end

endmodule
