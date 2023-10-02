module reg_File(
    input wire clk,
    input wire reset,

    input wire  [4:0]  raddr_a,
    output  wire [15:0] rdata_a,
    input wire  [4:0]  raddr_b,
    output  wire [15:0] rdata_b,
    input wire  [4:0]  waddr,
    input wire  [15:0] wdata,
    input wire  we
);

    logic [15:0] rdata_a_reg;
    logic [15:0] rdata_b_reg;
    logic [15:0]rf[0:31]='{default:16'd0}; 

    always_comb begin
        rdata_a_reg = rf[raddr_a];
        rdata_b_reg = rf[raddr_b];
    end

always_ff @ (posedge clk) begin
    begin
        if(we) begin
            if(waddr != 5'd0) begin
                rf[waddr] <= wdata;
            end
        end
    end
end

    assign rdata_a = rdata_a_reg;
    assign rdata_b = rdata_b_reg;

endmodule