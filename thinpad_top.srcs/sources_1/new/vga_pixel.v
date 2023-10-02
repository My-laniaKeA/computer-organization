module vga_pixel(
input wire clk,
input wire  [9:0]  col,
input wire [8:0]  row,
output reg [2:0]  red,   // 4-bit color output
output reg [2:0]  green, // 4-bit color output
output reg [1:0]  blue  // 4-bit color output
);

parameter   H_VALID =   10'd800 ,   //行有效数�??
            V_VALID =   10'd600 ;   //场有效数�??

always@(posedge clk)  begin   
    if((col >= 0) && (col < (H_VALID/10)*1)) begin
        red <= 3'b111;
        green <= 3'b000;
        blue <= 2'b00;        
    end  
    else    if((col >= (H_VALID/10)*1) && (col < (H_VALID/10)*2)) begin     
        red <= 3'b000;
        green <= 3'b111;
        blue <= 2'b00;    
    end
    else    if((col >= (H_VALID/10)*2) && (col < (H_VALID/10)*3))  begin       
        red <= 3'b000;
        green <= 3'b000;
        blue <= 2'b11;    
    end   
    else    begin     
        red <= 3'b111;
        green <= 3'b111;
        blue <= 2'b11;
    end
end

endmodule