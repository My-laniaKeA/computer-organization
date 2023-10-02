`default_nettype none

module button_in (
  // 时钟与复位信号，每个时序模块都必须包含
  input wire clk,
  input wire reset,
  input wire push_btn,

  // 计数触发信号
  output wire trigger

);
    logic last_button_reg;
    logic trigger_reg;

// 注意此时的敏感信号列表
always_ff @ (posedge clk or posedge reset) begin
    if(reset) begin
        last_button_reg <= 1'b0;
        trigger_reg <= 1'b0;
    end else begin
        last_button_reg <= push_btn;
        if(push_btn && !last_button_reg) begin
            trigger_reg<=1'b1;
        end else begin
            trigger_reg<=1'b0;
        end
    end
end

assign trigger = trigger_reg;


endmodule