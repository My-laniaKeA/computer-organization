module lab5_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // TODO: 添加需要的控制信号，例如按键开关？
    input wire [31:0] dip_sw,
    // wishbone master
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o
);

  // TODO: 实现实验 5 的内存+串口 Master
  logic [31:0] addr, randnum;
  logic [7:0] data;
  logic [3:0] i = 4'b0, round = 4'b0;

typedef enum logic [3:0] {
    STATE_IDLE = 0,
    STATE_READ_WAIT_ACTION = 1, //读判断寄存器
    STATE_READ_WAIT_CHECK = 2,  //判断能否读数据
    STATE_READ_DATA_ACTION = 3, //读数据寄存器
    STATE_READ_DATA_DONE = 4,
    STATE_WRITE_SRAM_ACTION = 5,
    STATE_WRITE_SRAM_DONE = 6,
    STATE_WRITE_WAIT_ACTION = 7,
    STATE_WRITE_WAIT_CHECK = 8,
    STATE_WRITE_DATA_ACTION = 9,
    STATE_WRITE_DATA_DONE = 10,
    STATE_DONE = 11
} state_t;

state_t state;

always_ff @ (posedge clk_i) begin
    if (rst_i) begin
        addr <= dip_sw;
        wb_cyc_o <= 1'b0;
        wb_stb_o <= 1'b0;
        i <= 4'b0;
        round <= 4'b0;
        state <= STATE_IDLE;
    end else begin
        case (state)
            STATE_IDLE: begin
                wb_stb_o <= 1'b1;
                wb_cyc_o <= 1'b1;
                wb_adr_o <= 32'h1000_0005;
                wb_sel_o <= 4'b0001;
                wb_we_o <= 1'b0;
                state <= STATE_READ_WAIT_ACTION;
            end
            STATE_READ_WAIT_ACTION: begin
                if(wb_ack_i)begin
                    wb_stb_o <= 1'b0;
                    wb_cyc_o <= 1'b0;
                    data <= wb_dat_i[7:0];
                    state <= STATE_READ_WAIT_CHECK;
                end
            end
            STATE_READ_WAIT_CHECK: begin
                if(data[0]) begin
                    wb_stb_o <= 1'b1;
                    wb_cyc_o <= 1'b1;
                    wb_adr_o <= 32'h1000_0000;
                    wb_sel_o <= 4'b0001;
                    wb_we_o <= 1'b0;
                    state <= STATE_READ_DATA_ACTION;
                end else begin
                    state <= STATE_IDLE;
                end
            end
            STATE_READ_DATA_ACTION: begin
                if(wb_ack_i)begin
                    wb_stb_o <= 1'b0;
                    wb_cyc_o <= 1'b0;
                    randnum <= wb_dat_i;
                    state <= STATE_READ_DATA_DONE;
                end
            end
            STATE_READ_DATA_DONE:begin
                wb_stb_o <= 1'b1;
                wb_cyc_o <= 1'b1;
                wb_adr_o <= addr + 4*i;
                i <= i + 1;
                // wb_sel_o <= 4'b0001<<(addr % 4);
                // wb_dat_o <= randnum<<((addr % 4)*8); FIXME
                wb_sel_o <= 4'b0001;
                wb_dat_o <= randnum;
                wb_we_o <= 1'b1;
                state <= STATE_WRITE_SRAM_ACTION;
            end
            STATE_WRITE_SRAM_ACTION: begin
                if(wb_ack_i)begin
                    wb_stb_o <= 1'b0;
                    wb_cyc_o <= 1'b0;
                    state <= STATE_WRITE_SRAM_DONE;
                end
            end
            STATE_WRITE_SRAM_DONE: begin
                wb_stb_o <= 1'b1;
                wb_cyc_o <= 1'b1;
                wb_adr_o <= 32'h1000_0005;
                wb_sel_o <= 4'b0001;
                wb_we_o <= 1'b0;
                state <= STATE_WRITE_WAIT_ACTION;
            end
            STATE_WRITE_WAIT_ACTION: begin
                if(wb_ack_i)begin
                    wb_stb_o <= 1'b0;
                    wb_cyc_o <= 1'b0;
                    data <= wb_dat_i[7:0];
                    state <= STATE_WRITE_WAIT_CHECK;
                end
            end
            STATE_WRITE_WAIT_CHECK: begin
                if(data[5]) begin
                    wb_stb_o <= 1'b1;
                    wb_cyc_o <= 1'b1;
                    wb_adr_o <= 32'h1000_0000;
                    wb_sel_o <= 4'b0001;
                    wb_dat_o <= randnum;
                    wb_we_o <= 1'b1;
                    state <= STATE_WRITE_DATA_ACTION;
                end else begin
                    state <= STATE_WRITE_SRAM_DONE;
                end
            end
            STATE_WRITE_DATA_ACTION: begin
                if(wb_ack_i)begin
                    wb_stb_o <= 1'b0;
                    wb_cyc_o <= 1'b0;
                    state <= STATE_WRITE_DATA_DONE;
                end
            end
            STATE_WRITE_DATA_DONE: begin
                if(round != 4'b1001) begin
                    round <= round + 1;
                    state <= STATE_IDLE;
                end else begin
                    state<= STATE_DONE;
                end
            end
        
            default: ;
        endcase
    end
end

endmodule
