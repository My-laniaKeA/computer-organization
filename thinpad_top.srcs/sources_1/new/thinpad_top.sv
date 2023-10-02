`default_nettype none

module thinpad_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮�?????关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时�????? 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时�????? 1
    output wire [15:0] leds,       // 16 �????? LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信�?????
    output wire uart_rdn,        // 读串口信号，低有�?????
    output wire uart_wrn,        // 写串口信号，低有�?????
    input  wire uart_dataready,  // 串口数据准备�?????
    input  wire uart_tbre,       // 发�?�数据标�?????
    input  wire uart_tsre,       // 数据发�?�完毕标�?????

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共�?????
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持�????? 0
    output wire base_ram_ce_n,  // BaseRAM 片�?�，低有�?????
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有�?????
    output wire base_ram_we_n,  // BaseRAM 写使能，低有�?????

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持�????? 0
    output wire ext_ram_ce_n,  // ExtRAM 片�?�，低有�?????
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有�?????
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有�?????

    // 直连串口信号
    output wire txd,  // 直连串口发�?�端
    input  wire rxd,  // 直连串口接收�?????

    // Flash 存储器信号，参�?? JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效�?????16bit 模式无意�?????
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧�?????
    output wire flash_ce_n,  // Flash 片�?�信号，低有�?????
    output wire flash_oe_n,  // Flash 读使能信号，低有�?????
    output wire flash_we_n,  // Flash 写使能信号，低有�?????
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash �????? 16 位模式时请设�????? 1

    // USB 控制器信号，参�?? SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参�?? DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素�?????3 �?????
    output wire [2:0] video_green,  // 绿色像素�?????3 �?????
    output wire [1:0] video_blue,   // 蓝色像素�?????2 �?????
    output wire       video_hsync,  // 行同步（水平同步）信�?????
    output wire       video_vsync,  // 场同步（垂直同步）信�?????
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐�?????
);

  /* =========== Demo code begin =========== */

  // PLL 分频示例
  logic locked, clk_10M, clk_25M, clk_30M, clk_40M, clk_80M, clk_100M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // 外部时钟输入
      // Clock out ports
      .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设�?????
      .clk_out2(clk_25M),  // 时钟输出 2，频率在 IP 配置界面中设�?????
      .clk_out3(clk_100M),
      .clk_out4(clk_80M),
      .clk_out5(clk_30M),
      .clk_out6(clk_40M),
      // Status and control signals
      .reset(reset_btn),  // PLL 复位输入
      .locked(locked)  // PLL 锁定指示输出�?????"1"表示时钟稳定�?????
                       // 后级电路复位信号应当由它生成（见下）
  );

  logic reset_of_clk10M;
  // 异步复位，同步释放，�????? locked 信号转为后级电路的复�????? reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end
  
  logic reset_of_clk25M;
  always_ff @(posedge clk_25M or negedge locked) begin
    if (~locked) reset_of_clk25M <= 1'b1;
    else reset_of_clk25M <= 1'b0;
  end

  logic reset_of_clk30M;
  always_ff @(posedge clk_30M or negedge locked) begin
    if (~locked) reset_of_clk30M <= 1'b1;
    else reset_of_clk30M <= 1'b0;
  end

  logic reset_of_clk40M;
  always_ff @(posedge clk_40M or negedge locked) begin
    if (~locked) reset_of_clk40M <= 1'b1;
    else reset_of_clk40M <= 1'b0;
  end

  logic reset_of_clk80M;
  always_ff @(posedge clk_80M or negedge locked) begin
    if (~locked) reset_of_clk80M <= 1'b1;
    else reset_of_clk80M <= 1'b0;
  end
  
  logic reset_of_clk100M;
  always_ff @(posedge clk_100M or negedge locked) begin
    if (~locked) reset_of_clk100M <= 1'b1;
    else reset_of_clk100M <= 1'b0;
  end

  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;
  
  assign video_clk = clk_25M;
  
  logic bram_we;
  logic [18:0] bram_waddr;
  logic [7:0]  bram_wdata;
  // logic [18:0]  bram_raddr;
  // logic [7:0]  bram_rdata;
  logic [18:0]  vga_adr;
  logic [7:0]  vga_dat;

  /*----------- block ram start -----------*/
block_mem u_block_mem ( //A for write, B for read
  .clka(clk_40M),    // input wire clka
  .wea(bram_we),      // input wire [0 : 0] wea
  .addra(bram_waddr),  // input wire [18 : 0] addra
  .dina(bram_wdata),    // input wire [7 : 0] dina
  .clkb(clk_25M),    // input wire clkb
  .addrb(vga_adr),  // input wire [18 : 0] addrb
  .doutb(vga_dat)  // output wire [7 : 0] doutb
);
 /*----------- block ram end -----------*/



vga_controller u_vga_controller(
  .clk(clk_25M),
  .bram_dat_i(vga_dat),
  .addr(vga_adr),
  .red(video_red),
  .green(video_green),
  .blue(video_blue),
  .hsync(video_hsync),
  .vsync(video_vsync),
  .de(video_de)
);
  /* =========== Demo code end =========== */

  logic sys_clk;
  logic sys_rst;

  assign sys_clk = clk_40M;
  assign sys_rst = reset_of_clk40M;

//   /* =========== ILA begin =========== */
// 	(* MARK_DEBUG = "TRUE" *) logic [31:0] if_data_i;

// 	ila_0 ila(
// 		.clk(sys_clk),
// 		.probe0(if_data_i)
// 	);


  /* =========== CPU begin =========== */
  logic [5:0] stall;
  logic flush;
  logic if_ce_o;
  logic [31:0] if_data_o;
  logic [31:0] if_addr_o;
  logic if_we_o;
  logic [3:0] if_sel_o;
  logic [31:0] if_data_i;
  logic if_stallreq;
  logic if_ack_i;
  logic mem_ce_o;
  logic [31:0] mem_data_o;
  logic [31:0] mem_addr_o, mem_prev_addr_o;
  logic mem_we_o;
  logic [3:0] mem_sel_o, mem_dirty_o;
  logic [31:0] mem_data_i;
  logic mem_stallreq;
  logic irq_timer,irq_external,irq_software;

  // assign irq_timer = 1'b0;
  assign irq_external = 1'b0;
  assign irq_software = 1'b0;
  logic mem_reset_cache;
  logic mem_ack_i;
  logic mem_wbs3_choosen;

  cpu u_cpu(
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      .stall_o(stall),
      .flush_o(flush),

      .wb_if_ce_o(if_ce_o),
      .wb_if_data_o(if_data_o),
      .wb_if_addr_o(if_addr_o),
      .wb_if_we_o(if_we_o),
      .wb_if_sel_o(if_sel_o),
      .wb_if_data_i(if_data_i),
	  .wb_if_ack_i(if_ack_i),

      .wb_mem_ce_o(mem_ce_o),
      .wb_mem_data_o(mem_data_o),
      .wb_mem_addr_o(mem_addr_o),
	  .wb_mem_prev_addr_o(mem_prev_addr_o),
      .wb_mem_we_o(mem_we_o),
      .wb_mem_sel_o(mem_sel_o),
	  .wb_mem_dirty_o(mem_dirty_o),
      .wb_mem_data_i(mem_data_i),
	  .wb_mem_ack_i(mem_ack_i),
	  .wb_mem_reset_cache_o(mem_reset_cache),
      .wb_mem_wbs3_choosen_i(mem_wbs3_choosen),

      .irq_external_i(irq_external),
      .irq_software_i(irq_software),
      .irq_timer_i(irq_timer)
  );

  /* =========== CPU end =========== */


  /* =========== Wishbone Master begin =========== */
  // Wishbone Master => Wishbone MUX (Slave)
  logic        wbm0_cyc_o;
  logic        wbm0_stb_o;
  logic        wbm0_ack_i;
  logic [31:0] wbm0_adr_o;
  logic [31:0] wbm0_dat_o;
  logic [31:0] wbm0_dat_i;
  logic [ 3:0] wbm0_sel_o;
  logic        wbm0_we_o;

  im_master u_wishbone_if_master (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // wishbone master
      .wb_cyc_o(wbm0_cyc_o),
      .wb_stb_o(wbm0_stb_o),
      .wb_ack_i(wbm0_ack_i),
      .wb_adr_o(wbm0_adr_o),
      .wb_dat_o(wbm0_dat_o),
      .wb_dat_i(wbm0_dat_i),
      .wb_sel_o(wbm0_sel_o),
      .wb_we_o (wbm0_we_o),

      .stall_i(stall),
      .flush_i(1'b0),

      .cpu_ce_i(if_ce_o),
      .cpu_data_i(if_data_o),
      .cpu_addr_i(if_addr_o),
      .cpu_we_i(if_we_o),
      .cpu_sel_i(if_sel_o),
      .cpu_data_o(if_data_i),
	  .cpu_ack_o(if_ack_i)

      // .stallreq(if_stallreq)
  );

  logic        wbm1_cyc_o;
  logic        wbm1_stb_o;
  logic        wbm1_ack_i;
  logic [31:0] wbm1_adr_o;
  logic [31:0] wbm1_dat_o;
  logic [31:0] wbm1_dat_i;
  logic [ 3:0] wbm1_sel_o;
  logic        wbm1_we_o;

  dm_master u_wishbone_mem_master (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // wishbone master
      .wb_cyc_o(wbm1_cyc_o),
      .wb_stb_o(wbm1_stb_o),
      .wb_ack_i(wbm1_ack_i),
      .wb_adr_o(wbm1_adr_o),
      .wb_dat_o(wbm1_dat_o),
      .wb_dat_i(wbm1_dat_i),
      .wb_sel_o(wbm1_sel_o),
      .wb_we_o (wbm1_we_o),

      // .stall_i(stall),
      .flush_i(1'b0),

      .cpu_ce_i(mem_ce_o),
      .cpu_data_i(mem_data_o),
      .cpu_addr_i(mem_addr_o),
	  .cpu_prev_addr_i(mem_prev_addr_o),
      .cpu_we_i(mem_we_o),
      .cpu_sel_i(mem_sel_o),
	  .cache_dirty_i(mem_dirty_o),
      .cpu_data_o(mem_data_i),
	  .cpu_ack_o(mem_ack_i),
	  .reset_cache_i(mem_reset_cache)

      // .stallreq(mem_stallreq)
  );

  /* =========== Wishbone Master end =========== */

  /* =========== Wishbone Arbiter begin =========== */
  logic wbs_cyc_i;
  logic wbs_stb_i;
  logic wbs_ack_o;
  logic [31:0] wbs_adr_i;
  logic [31:0] wbs_dat_o;
  logic [31:0] wbs_dat_i;
  logic [3:0] wbs_sel_i;
  logic wbs_we_i;  

  wb_arbiter_2 #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .ARB_TYPE_ROUND_ROBIN(0),
    .ARB_LSB_HIGH_PRIORITY(0)
  ) u_arbiter(
      .clk(sys_clk),
      .rst(sys_rst),

      .wbm0_adr_i(wbm0_adr_o),
      .wbm0_dat_i(wbm0_dat_o),
      .wbm0_dat_o(wbm0_dat_i),
      .wbm0_we_i (wbm0_we_o),
      .wbm0_sel_i(wbm0_sel_o),
      .wbm0_stb_i(wbm0_stb_o),
      .wbm0_ack_o(wbm0_ack_i),
      .wbm0_err_o(),
      .wbm0_rty_o(),
      .wbm0_cyc_i(wbm0_cyc_o),

      .wbm1_adr_i(wbm1_adr_o),
      .wbm1_dat_i(wbm1_dat_o),
      .wbm1_dat_o(wbm1_dat_i),
      .wbm1_we_i (wbm1_we_o),
      .wbm1_sel_i(wbm1_sel_o),
      .wbm1_stb_i(wbm1_stb_o),
      .wbm1_ack_o(wbm1_ack_i),
      .wbm1_err_o(),
      .wbm1_rty_o(),
      .wbm1_cyc_i(wbm1_cyc_o),

      .wbs_adr_o(wbs_adr_i),
      .wbs_dat_i(wbs_dat_o),
      .wbs_dat_o(wbs_dat_i),
      .wbs_we_o (wbs_we_i),
      .wbs_sel_o(wbs_sel_i),
      .wbs_stb_o(wbs_stb_i),
      .wbs_ack_i(wbs_ack_o),
      .wbs_err_i('0),
      .wbs_rty_i('0),
      .wbs_cyc_o(wbs_cyc_i)

  );
  /* =========== Wishbone Arbiter end =========== */

  /* =========== Wishbone MUX begin =========== */
  // Wishbone MUX (Masters) => bus slaves
  logic wbs0_cyc_o;
  logic wbs0_stb_o;
  logic wbs0_ack_i;
  logic [31:0] wbs0_adr_o;
  logic [31:0] wbs0_dat_o;
  logic [31:0] wbs0_dat_i;
  logic [3:0] wbs0_sel_o;
  logic wbs0_we_o;

  logic wbs1_cyc_o;
  logic wbs1_stb_o;
  logic wbs1_ack_i;
  logic [31:0] wbs1_adr_o;
  logic [31:0] wbs1_dat_o;
  logic [31:0] wbs1_dat_i;
  logic [3:0] wbs1_sel_o;
  logic wbs1_we_o;

  logic wbs2_cyc_o;
  logic wbs2_stb_o;
  logic wbs2_ack_i;
  logic [31:0] wbs2_adr_o;
  logic [31:0] wbs2_dat_o;
  logic [31:0] wbs2_dat_i;
  logic [3:0] wbs2_sel_o;
  logic wbs2_we_o;

  logic wbs3_cyc_o;
  logic wbs3_stb_o;
  logic wbs3_ack_i;
  logic [31:0] wbs3_adr_o;
  //logic [31:0] wbs3_dat_o;
  logic [31:0] wbs3_dat_i;
  //logic [3:0] wbs3_sel_o;
  logic wbs3_we_o;

  logic wbs4_cyc_o;
  logic wbs4_stb_o;
  logic wbs4_ack_i;
  logic [31:0] wbs4_adr_o;
  logic [31:0] wbs4_dat_o;
  logic [31:0] wbs4_dat_i;
  //logic [3:0] wbs3_sel_o;
  logic wbs4_we_o;

  logic wbs5_cyc_o;
  logic wbs5_stb_o;
  logic wbs5_ack_i;
  logic [31:0] wbs5_adr_o;
  logic [31:0] wbs5_dat_o;
  logic [31:0] wbs5_dat_i;
  logic [3:0] wbs5_sel_o;
  logic wbs5_we_o;


  wb_mux_6 u_wb_mux (
      .clk(sys_clk),
      .rst(sys_rst),

      // Master interface (to arbiter)
      .wbm_adr_i(wbs_adr_i),
      .wbm_dat_i(wbs_dat_i),
      .wbm_dat_o(wbs_dat_o),
      .wbm_we_i (wbs_we_i),
      .wbm_sel_i(wbs_sel_i),
      .wbm_stb_i(wbs_stb_i),
      .wbm_ack_o(wbs_ack_o),
      .wbm_err_o(),
      .wbm_rty_o(),
      .wbm_cyc_i(wbs_cyc_i),

      // Slave interface 0 (to BaseRAM controller)
      // Address range: 0x8000_0000 ~ 0x803F_FFFF
      .wbs0_addr    (32'h8000_0000),
      .wbs0_addr_msk(32'hFFC0_0000),

      .wbs0_adr_o(wbs0_adr_o),
      .wbs0_dat_i(wbs0_dat_i),
      .wbs0_dat_o(wbs0_dat_o),
      .wbs0_we_o (wbs0_we_o),
      .wbs0_sel_o(wbs0_sel_o),
      .wbs0_stb_o(wbs0_stb_o),
      .wbs0_ack_i(wbs0_ack_i),
      .wbs0_err_i('0),
      .wbs0_rty_i('0),
      .wbs0_cyc_o(wbs0_cyc_o),

      // Slave interface 1 (to ExtRAM controller)
      // Address range: 0x8040_0000 ~ 0x807F_FFFF
      .wbs1_addr    (32'h8040_0000),
      .wbs1_addr_msk(32'hFFC0_0000),

      .wbs1_adr_o(wbs1_adr_o),
      .wbs1_dat_i(wbs1_dat_i),
      .wbs1_dat_o(wbs1_dat_o),
      .wbs1_we_o (wbs1_we_o),
      .wbs1_sel_o(wbs1_sel_o),
      .wbs1_stb_o(wbs1_stb_o),
      .wbs1_ack_i(wbs1_ack_i),
      .wbs1_err_i('0),
      .wbs1_rty_i('0),
      .wbs1_cyc_o(wbs1_cyc_o),

      // Slave interface 2 (to UART controller)
      // Address range: 0x1000_0000 ~ 0x1000_FFFF
      .wbs2_addr    (32'h1000_0000),
      .wbs2_addr_msk(32'hFFFF_0000),

      .wbs2_adr_o(wbs2_adr_o),
      .wbs2_dat_i(wbs2_dat_i),
      .wbs2_dat_o(wbs2_dat_o),
      .wbs2_we_o (wbs2_we_o),
      .wbs2_sel_o(wbs2_sel_o),
      .wbs2_stb_o(wbs2_stb_o),
      .wbs2_ack_i(wbs2_ack_i),
      .wbs2_err_i('0),
      .wbs2_rty_i('0),
      .wbs2_cyc_o(wbs2_cyc_o),

      // Slave interface 3 (to flash controller)
      // Address range: 0x1100_0000 ~ 0x117F_FFFF
      .wbs3_addr    (32'h1100_0000),
      .wbs3_addr_msk(32'hFF80_0000),

      .wbs3_adr_o(wbs3_adr_o),
      .wbs3_dat_i(wbs3_dat_i),
      //.wbs3_dat_o(wbs3_dat_o),
      .wbs3_we_o (wbs3_we_o),
      //.wbs3_sel_o(wbs3_sel_o),
      .wbs3_stb_o(wbs3_stb_o),
      .wbs3_ack_i(wbs3_ack_i),
      .wbs3_err_i('0),
      .wbs3_rty_i('0),
      .wbs3_cyc_o(wbs3_cyc_o),
      .wbs3_choosen(mem_wbs3_choosen),

      // Slave interface 4 (to bram controller)
      // Address range: 0x1210_0000 ~ 0x1217_52FF
      .wbs4_addr    (32'h1210_0000),
      .wbs4_addr_msk(32'hFFF8_0000),

      .wbs4_adr_o(wbs4_adr_o),
      .wbs4_dat_i(wbs4_dat_i),
      .wbs4_dat_o(wbs4_dat_o),
      .wbs4_we_o (wbs4_we_o),
      //.wbs4_sel_o(wbs4_sel_o),
      .wbs4_stb_o(wbs4_stb_o),
      .wbs4_ack_i(wbs4_ack_i),
      .wbs4_err_i('0),
      .wbs4_rty_i('0),
      .wbs4_cyc_o(wbs4_cyc_o),

	   // Slave interface 5 (to CLINT controller) 
      // Address range: 0x200_BFF8 and 0x200_4000
      .wbs5_addr    (32'h200_0000),
      .wbs5_addr_msk(32'hFFFF_0000),

      .wbs5_adr_o(wbs5_adr_o),
      .wbs5_dat_i(wbs5_dat_i),
      .wbs5_dat_o(wbs5_dat_o),
      .wbs5_we_o (wbs5_we_o),
      .wbs5_sel_o(wbs5_sel_o),
      .wbs5_stb_o(wbs5_stb_o),
      .wbs5_ack_i(wbs5_ack_i),
      .wbs5_err_i('0),   
      .wbs5_rty_i('0),
      .wbs5_cyc_o(wbs5_cyc_o)
  );

  /* ===========  Wishbone MUX end =========== */

  /* =========== Wishbone Slaves begin =========== */
  sram_controller #(
      .SRAM_ADDR_WIDTH(20),
      .SRAM_DATA_WIDTH(32)
  ) sram_controller_base (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs0_cyc_o),
      .wb_stb_i(wbs0_stb_o),
      .wb_ack_o(wbs0_ack_i),
      .wb_adr_i(wbs0_adr_o),
      .wb_dat_i(wbs0_dat_o),
      .wb_dat_o(wbs0_dat_i),
      .wb_sel_i(wbs0_sel_o),
      .wb_we_i (wbs0_we_o),

      // To SRAM chip
      .sram_addr(base_ram_addr),
      .sram_data(base_ram_data),
      .sram_ce_n(base_ram_ce_n),
      .sram_oe_n(base_ram_oe_n),
      .sram_we_n(base_ram_we_n),
      .sram_be_n(base_ram_be_n)
  );

  sram_controller #(
      .SRAM_ADDR_WIDTH(20),
      .SRAM_DATA_WIDTH(32)
  ) sram_controller_ext (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs1_cyc_o),
      .wb_stb_i(wbs1_stb_o),
      .wb_ack_o(wbs1_ack_i),
      .wb_adr_i(wbs1_adr_o),
      .wb_dat_i(wbs1_dat_o),
      .wb_dat_o(wbs1_dat_i),
      .wb_sel_i(wbs1_sel_o),
      .wb_we_i (wbs1_we_o),

      // To SRAM chip
      .sram_addr(ext_ram_addr),
      .sram_data(ext_ram_data),
      .sram_ce_n(ext_ram_ce_n),
      .sram_oe_n(ext_ram_oe_n),
      .sram_we_n(ext_ram_we_n),
      .sram_be_n(ext_ram_be_n)
  );

  // 串口控制器模�???
  // NOTE: 如果修改系统时钟频率，也�???要修改此处的时钟频率参数
  uart_controller #(
      .CLK_FREQ(40_000_000),
      .BAUD    (115200)
  ) uart_controller (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      .wb_cyc_i(wbs2_cyc_o),
      .wb_stb_i(wbs2_stb_o),
      .wb_ack_o(wbs2_ack_i),
      .wb_adr_i(wbs2_adr_o),
      .wb_dat_i(wbs2_dat_o),
      .wb_dat_o(wbs2_dat_i),
      .wb_sel_i(wbs2_sel_o),
      .wb_we_i (wbs2_we_o),

      // to UART pins
      .uart_txd_o(txd),
      .uart_rxd_i(rxd)
  );

  clint u_clint (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs5_cyc_o),
      .wb_stb_i(wbs5_stb_o),
      .wb_ack_o(wbs5_ack_i),
      .wb_adr_i(wbs5_adr_o),
      .wb_dat_i(wbs5_dat_o),
      .wb_dat_o(wbs5_dat_i),
      .wb_sel_i(wbs5_sel_o),
      .wb_we_i (wbs5_we_o),

      .timer_intr_o(irq_timer)
  );

  //flash控制�????
  flash_controller u_flash_controller(
    .clk_i(sys_clk),
    .rst_i(sys_rst),
    .wb_cyc_i(wbs3_cyc_o),
    .wb_stb_i(wbs3_stb_o),
    .wb_adr_i(wbs3_adr_o),
    .wb_we_i(wbs3_we_o),
    .wb_dat_o(wbs3_dat_i),
    .wb_ack_o(wbs3_ack_i),
    .flash_rst(flash_rp_n),
    .flash_oe(flash_oe_n),
    .flash_ce(flash_ce_n),
    .flash_we(flash_we_n),
    .flash_byte(flash_byte_n),
    .flash_vpen(flash_vpen),
    .flash_adr_o(flash_a),
    .flash_dat_i(flash_d)
  );

  // bram控制
  bram_controller u_bram_controller(
    .clk_i(sys_clk),
    .rst_i(sys_rst),
    .wb_cyc_i(wbs4_cyc_o),
    .wb_stb_i(wbs4_stb_o),
    .wb_we_i(wbs4_we_o),
    .wb_adr_i(wbs4_adr_o),
    .wb_dat_i(wbs4_dat_o),
    .wb_dat_o(wbs4_dat_i),
    .wb_ack_o(wbs4_ack_i),
    //.vga_adr_i(vga_adr),
    //.vga_dat_o(vga_dat),
    .bram_we(bram_we),
    .bram_waddr(bram_waddr),
    .bram_wdata(bram_wdata)
    // .bram_raddr(bram_raddr),
    // .bram_rdata(bram_rdata)
  );
  /* =========== Wishbone Slaves end =========== */

endmodule
