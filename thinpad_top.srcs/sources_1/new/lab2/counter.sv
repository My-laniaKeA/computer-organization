`default_nettype none

module counter (
  // 时钟与复位信号，每个时序模块都必须包含
  input wire clk,
  input wire reset,

  // 计数触发信号
  input wire trigger,

  // 当前计数值
  output wire [3:0] count
);
    logic [3:0] count_reg;

// 注意此时的敏感信号列表
always_ff @ (posedge clk or posedge reset) begin
    if(reset) begin
        count_reg <= 4'd0;
    end else begin
        if (trigger) begin  // 增加此处
            if (count_reg == 4'd15) begin
                count_reg <= 4'd15;
            end else begin
                count_reg <= count_reg + 4'd1;
            end
        end
    end
end

assign count = count_reg;


endmodule
