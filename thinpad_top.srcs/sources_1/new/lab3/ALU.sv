module ALU(
    input wire  [15:0] a,
    input wire  [15:0] b,
    input wire  [ 3:0] op,
    output  wire [15:0] y
);

logic [15:0] y_reg;

always_comb begin
    case(op)
        4'd1: begin y_reg = a + b;end
        4'd2: begin y_reg = a - b;end
        4'd3: begin y_reg = a & b;end
        4'd4: begin y_reg = a | b;end
        4'd5: begin y_reg = a ^ b;end
        4'd6: begin y_reg = ~a;   end
        4'd7: begin y_reg = a << (b % 16);end
        4'd8: begin y_reg = a >> (b % 16);end
        4'd9: begin y_reg = ($signed(a)) >>> (b % 16);end
        4'd10: begin y_reg = (a << (b % 16)) + (a >> (16-(b % 16)));end
        default: begin y_reg = 16'b0; end
    endcase
end

    assign y=y_reg;

endmodule