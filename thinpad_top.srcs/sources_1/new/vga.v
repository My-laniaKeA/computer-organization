`timescale 1ns / 1ps
//
// WIDTH: bits in register hdata & vdata
// HSIZE: horizontal size of visible field 
// HFP: horizontal front of pulse
// HSP: horizontal stop of pulse
// HMAX: horizontal max size of value
// VSIZE: vertical size of visible field 
// VFP: vertical front of pulse
// VSP: vertical stop of pulse
// VMAX: vertical max size of value
// HSPP: horizontal synchro pulse polarity (0 - negative, 1 - positive)
// VSPP: vertical synchro pulse polarity (0 - negative, 1 - positive)
//

// use 640x480@60 25Mhz clock
module vga #(
    parameter WIDTH = 12,
    HSIZE = 640,
    HFP = 648,
    HSP = 744,
    HMAX = 800,
    VSIZE = 480,
    VFP = 481,
    VSP = 484,
    VMAX = 525,
    HSPP = 0,
    VSPP = 0
) (
    input wire clk,
    output wire hsync,
    output wire vsync,
    output reg [WIDTH - 1:0] hdata,
    output reg [WIDTH - 1:0] vdata,
    output wire data_enable
);

  initial begin
    hdata <= 1'b0;
    vdata <= 1'b0;
  end

  // hdata
  always @(posedge clk) begin
    if (hdata == (HMAX - 1)) hdata <= 0;
    else hdata <= hdata + 1;
  end

  // vdata
  always @(posedge clk) begin
    if (hdata == (HMAX - 1)) begin
      if (vdata == (VMAX - 1)) vdata <= 0;
      else vdata <= vdata + 1;
    end
  end

  // hsync & vsync & blank
  assign hsync = ((hdata >= HFP) && (hdata < HSP)) ? HSPP : !HSPP;
  assign vsync = ((vdata >= VFP) && (vdata < VSP)) ? VSPP : !VSPP;
  assign data_enable = ((hdata < HSIZE) & (vdata < VSIZE));

endmodule