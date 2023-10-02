`include "define.sv"

module regfile(
    input wire clk_i,
    input wire rst_i,
    
    input wire  [`RegBUS]  raddr_a,
    output reg [`DATABUS] rdata_a,
    input wire  [`RegBUS]  raddr_b,
    output reg [`DATABUS] rdata_b,

    input wire  [`RegBUS]  waddr,
    input wire  [`DATABUS] wdata,
    input wire  we
);

    // logic [`DATABUS] rdata_a_reg;
    // logic [`DATABUS] rdata_b_reg;
    logic [`DATABUS] registers [0:31] = '{default:32'd0};

	always_comb begin
		if (rst_i) begin
			rdata_a = `ZeroWord;
			rdata_b = `ZeroWord;
    	end else begin
			rdata_a = registers[raddr_a];
			rdata_b = registers[raddr_b];

		if (raddr_a == 5'b0)	rdata_a = `ZeroWord;
		if (raddr_b == 5'b0)	rdata_b = `ZeroWord;
   
    	end
	end

	always_ff  @(posedge clk_i) begin
		if (!rst_i) begin
			if (we) begin
				registers[waddr] <= wdata; 
			end
		end
	end
    // always_comb begin
    //     if(raddr_a == waddr && we == 1'b1) begin
    //         rdata_a_reg = wdata;
    //     end else if(raddr_a <= 31 && raddr_a > 0) begin
    //         rdata_a_reg = rf[raddr_a];
    //     end else begin
    //         rdata_a_reg = 32'b0;
    //     end
    // end

    // always_comb begin
    //     if(raddr_b == waddr && we == 1'b1) begin
    //         rdata_b_reg = wdata;
    //     end else if(raddr_b <= 31 && raddr_b > 0) begin
    //         rdata_b_reg = rf[raddr_b];
    //     end else begin
    //         rdata_b_reg = 32'b0;
    //     end
    // end

    // always_ff @ (posedge clk_i) begin
    //     if(we) begin
    //         if(waddr <= 31 && waddr > 0) begin
    //             rf[waddr] <= wdata;
    //         end
    //     end
    // end

    // assign rdata_a = rdata_a_reg;
    // assign rdata_b = rdata_b_reg;

endmodule