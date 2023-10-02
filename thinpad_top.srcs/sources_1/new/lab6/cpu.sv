`include "define.sv"

module cpu(
    input wire clk_i,
    input wire rst_i,

    output reg [5:0] stall_o,
    output reg flush_o,

    output reg wb_if_ce_o,
    output reg [`DATABUS] wb_if_data_o,
    output reg [`ADDRBUS] wb_if_addr_o,
    output reg wb_if_we_o,
    output reg [3:0] wb_if_sel_o,
    input wire [`DATABUS] wb_if_data_i,
	input wire wb_if_ack_i,

    output reg wb_mem_ce_o,
    output reg [`DATABUS] wb_mem_data_o,
    output reg [`ADDRBUS] wb_mem_addr_o,
	output reg [`ADDRBUS] wb_mem_prev_addr_o,
    output reg wb_mem_we_o,
    output reg [3:0] wb_mem_sel_o,
	output reg [3:0] wb_mem_dirty_o,
    input wire [`DATABUS] wb_mem_data_i,
    input wire wb_mem_ack_i,
	output reg wb_mem_reset_cache_o,

    // input wire if_stallreq,
    input wire wb_mem_wbs3_choosen_i,

    input  wire  irq_software_i,
    input  wire  irq_timer_i,
    input  wire  irq_external_i
);

    logic if_stallreq, id_stallreq, ex_stallreq, mem_stallreq;
    logic [`ADDRBUS] pc, new_pc, adr_itlb_2_icache;
    logic ce_if_2_itlb, ce_itlb_2_icache;
    logic [5:0] stall;
    logic flush;

    //csr
    logic [31:0] mem_exception_o;
    logic [31:0] mem_pc_o,mem_inst_o;
    logic csr_mstatus_ie_o;
    logic csr_mie_external_o, csr_mie_timer_o, csr_mie_sw_o;
    logic csr_mip_external_o, csr_mip_timer_o, csr_mip_sw_o;
    logic [31:0] csr_mtvec_o, csr_epc_o;
    logic ctrl_ie_type_o, ctrl_set_epc_o;
    logic ctrl_set_cause_o;
    logic [3:0] ctrl_trap_cause_o;
    logic [31:0] ctrl_epc_o;
    logic ctrl_mstatus_ie_clear_o;
    logic ctrl_mstatus_ie_set_o;
    logic ctrl_set_mtval_o;
    logic [31:0] ctrl_mtval_o;
    logic [1:0]  mode;
    logic [31:0] ppn;
    logic itlb_exception;
    logic dtlb_exception;

    assign stall_o = stall;
    assign flush_o = flush;

    ctrl u_ctrl(
        .clk_i(clk_i),
        .rst_i(rst_i),

        .if_stallreq(if_stallreq),
        .id_stallreq(id_stallreq),
        .ex_stallreq(ex_stallreq),
        .mem_stallreq(mem_stallreq),
        .stall(stall),
        .flush(flush),
        .new_pc(new_pc),

        .exception_i(mem_exception_o),
        .itlb_exception(itlb_exception),
        .dtlb_exception(dtlb_exception),
        .pc_i(mem_pc_o),
        .inst_i(mem_inst_o),

        //from csr
        .mstatus_ie_i(csr_mstatus_ie_o),

        .mie_external_i(csr_mie_external_o),
        .mie_timer_i(csr_mie_timer_o),
        .mie_sw_i (csr_mie_sw_o),

        .mip_external_i(csr_mip_external_o),
		.mip_timer_i(csr_mip_timer_o),
        .mip_sw_i(csr_mip_sw_o),

        .mtvec_i(csr_mtvec_o),
		.epc_i(csr_epc_o),

        // to csr
        .ie_type_o(ctrl_ie_type_o),
        .set_cause_o(ctrl_set_cause_o),
        .trap_cause_o(ctrl_trap_cause_o),

        .set_epc_o(ctrl_set_epc_o),
        .epc_o(ctrl_epc_o),

        .set_mtval_o(ctrl_set_mtval_o),
        .mtval_o(ctrl_mtval_o),

        .mstatus_ie_clear_o(ctrl_mstatus_ie_clear_o),
        .mstatus_ie_set_o(ctrl_mstatus_ie_set_o)
    );

    logic [`ADDRBUS] branch_addr;
    logic id_branch_flag_o,if_branch_flag_o;
	logic reset_icache, id_reset_dcache_o, ex_reset_dcache_i, ex_reset_dcache_o, mem_reset_dcache_i;
    // assign wb_if_data_o = `ZeroWord;
    // assign wb_if_addr_o = pc;
    // assign wb_if_we_o = `Disable;
    // assign wb_if_sel_o = 4'b1111;

	logic [`ADDRBUS] 	next_pc_bpu_2_if;
	logic				next_taken_bpu_2_ifid, next_taken_ifid_2_id;

	logic 				needs_correction;
	logic [`ADDRBUS] 	corrected_pc;

	logic 				is_branch_id_2_bpu, is_jal_id_2_bpu;
	logic 				branch_taken_id_2_bpu;


    pc_reg u_pc_reg( //if
        .clk_i(clk_i),
        .rst_i(rst_i),

        .pc(pc),
        .ce(ce_if_2_itlb),

        .branch_flag_i(id_branch_flag_o),
        // .branch_flag_o(if_branch_flag_o),
        .branch_addr_i(branch_addr),

        .stall(stall),
        .flush(flush),
        .new_pc(new_pc),

		// bpu
		.needs_correction_i(needs_correction),
		.corrected_pc_i(corrected_pc),
		.next_pc_i(next_pc_bpu_2_if)
    );

	bpu u_bpu(
		.clk_i(clk_i),
		.rst_i(rst_i),

		.pc_i(pc),
		.next_pc_o(next_pc_bpu_2_if),
		.next_taken_o(next_taken_bpu_2_ifid),

		.id_branch_taken_i(branch_taken_id_2_bpu),
		.id_is_branch_i(is_branch_id_2_bpu),
		.id_is_jal_i(is_jal_id_2_bpu),
		.id_pc_i(id_pc_o),
		.id_target_adr_i(branch_addr)
	);

	logic [`DATABUS] inst_icache_2_itlb, inst_itlb_2_ifid;
	logic ack_icache_2_itlb;
	logic rst_tlb_id_2_tlb;
	logic rst_icache_itlb_2_icache, rst_dcache_dtlb_2_dcache;

	logic ce_itlb_2_arb, we_itlb_2_arb, ack_arb_2_itlb;
	logic [`ADDRBUS] adr_itlb_2_arb;
	logic [`DATABUS] dat_itlb_2_arb, dat_arb_2_itlb;
	logic [3:0] sel_itlb_2_arb;
	
	mmu_tlb u_i_mmu_tlb(
		.clk_i		(clk_i),
		.rst_i		(rst_i),
		.is_if_tlb_i(1'b1),

		// ctrl
		.stallreq_o	(if_stallreq),
		.flush_i(flush),

		// csr
		.mode_i			(mode),
		.pt_base_adr_i	(ppn),
		.exception_o	(itlb_exception),

		// cpu
		.cpu_ce_i	(ce_if_2_itlb),
		.cpu_adr_i	(pc),
		.cpu_dat_i	(`ZeroWord),
		.cpu_we_i	(`Disable),
		.cpu_sel_i	(4'b1111),
		.cpu_rst_cache_i(reset_icache),
		.cpu_dat_o	(inst_itlb_2_ifid),

		// memory master
		.wb_ce_o	(ce_itlb_2_arb),
		.wb_we_o	(we_itlb_2_arb),
   		.wb_adr_o	(adr_itlb_2_arb),
		.wb_dat_o	(dat_itlb_2_arb),
    	.wb_sel_o	(sel_itlb_2_arb),
    	.wb_dat_i	(dat_arb_2_itlb),
		.wb_ack_i	(ack_arb_2_itlb),

		// cache
		.cache_ce_o	(ce_itlb_2_icache),
		.cache_adr_o(adr_itlb_2_icache),	
		.cache_dat_o(),	// useless
		.cache_we_o	(),	// useless
		.cache_sel_o(),	// useless
		.cache_rst_cache_o(rst_icache_itlb_2_icache),
		.cache_dat_i(inst_icache_2_itlb),
		.cache_ack_i(ack_icache_2_itlb),

		// id
		.reset_tlb_i(rst_tlb_id_2_tlb)
	);		

	logic ce_icache_2_arb, we_icache_2_arb, ack_arb_2_icache;
	logic [`ADDRBUS] adr_icache_2_arb;
	logic [`DATABUS] dat_icache_2_arb, dat_arb_2_icache;
	logic [3:0] sel_icache_2_arb;

	icache u_icache(
		.clk_i(clk_i),
        .rst_i(rst_i),

		.wb_ce_o(ce_icache_2_arb),
		.wb_adr_o(adr_icache_2_arb),
		.wb_dat_o(dat_icache_2_arb),
		.wb_we_o(we_icache_2_arb),
		.wb_sel_o(sel_icache_2_arb),
		.wb_dat_i(dat_arb_2_icache),
		.wb_ack_i(ack_arb_2_icache),

		.tlb_ack_o(ack_icache_2_itlb),

		.if_adr_i(adr_itlb_2_icache),
		.if_ce_i(ce_itlb_2_icache), 

		.reset_cache_i(rst_icache_itlb_2_icache),
		
		.id_dat_o(inst_icache_2_itlb)
	);

	mem_master_arbiter u_i_arbiter(
		.rst_i(rst_i),

		// cache
		.cache_ce_i(ce_icache_2_arb),
		.cache_adr_i(adr_icache_2_arb),
		.cache_sel_i(sel_icache_2_arb),
		.cache_we_i(we_icache_2_arb),
    	.cache_dat_i(dat_icache_2_arb),

		.cache_prev_adr_i(`ZeroWord),
		.cache_dirty_i(4'b0000),
		.cache_reset_cache_i(1'b0),
    
    	.cache_dat_o(dat_arb_2_icache),
		.cache_ack_o(ack_arb_2_icache),

		// tlb
		.tlb_ce_i(ce_itlb_2_arb),
		.tlb_adr_i(adr_itlb_2_arb),
		.tlb_sel_i(sel_itlb_2_arb),
		.tlb_we_i(we_itlb_2_arb),
		.tlb_dat_i(dat_itlb_2_arb),
    
    	.tlb_dat_o(dat_arb_2_itlb),
		.tlb_ack_o(ack_arb_2_itlb),

		// mem_master
		.mm_ce_o(wb_if_ce_o),
		.mm_adr_o(wb_if_addr_o),
		.mm_sel_o(wb_if_sel_o),
		.mm_we_o(wb_if_we_o),
		.mm_dat_o(wb_if_data_o),
		.mm_prev_adr_o(), 	// useless
		.mm_dirty_o(), 		// useless
		.mm_reset_cache_o(),// useless
		
		.mm_dat_i(wb_if_data_i),
		.mm_ack_i(wb_if_ack_i)
	);

    logic [`ADDRBUS] id_pc_i,id_inst_i;

    if_id u_if_id(
        .clk_i(clk_i),
        .rst_i(rst_i),
        .stall(stall),
        .flush(flush),
        .if_pc(pc),
        .if_inst(inst_itlb_2_ifid),
        .id_pc(id_pc_i),
        .id_inst(id_inst_i),
        // .branch_flag(if_branch_flag_o),
		.if_next_taken(next_taken_bpu_2_ifid), 
		.id_next_taken(next_taken_ifid_2_id),
		.needs_correction(needs_correction)
    );

    logic [`OpcodeBUS] ex_op_o;
    logic [`DATABUS] rdata_a,rdata_b;
    logic [`RegBUS] raddr_a,raddr_b;
    logic [`DATABUS] ex_wdata_o, mem_wdata_o;
    logic [`RegBUS] ex_waddr_o, mem_waddr_o;
    logic ex_we_o, mem_we_o;
    logic mem_csr_we_o;
    logic [31:0] mem_csr_waddr_o,mem_csr_wdata_o;
    logic in_delayslot_i,id_in_delayslot_o,next_in_delayslot_o;
    logic [`AluOpBUS] id_aluop_o;
    // logic [3:0] alusel_o;
    logic [`DATABUS] id_reg1_o,id_reg2_o;
    logic id_we_o;
    logic [`DATABUS] id_inst_o;
    logic [`RegBUS] id_waddr_o;
    logic [2:0] id_imm_type_o;
	logic [`DATABUS] id_imm_o;
    logic id_use_reg1, id_use_reg2;
    logic id_mem_en_o;
    logic [3:0] id_mem_sel_o;
    logic [`ADDRBUS] id_pc_o;

	logic [`DATABUS] rdata_a_fw, rdata_b_fw;

    logic id_csr_we_o;
    logic [31:0] id_csr_addr_o, id_exception_o;

    id u_id(
        .rst_i(rst_i),
        .pc_i(id_pc_i),
        .inst_i(id_inst_i),
        .ex_op_i(ex_op_o),

		.pred_taken_i		(next_taken_ifid_2_id),
		.needs_correction_o	(needs_correction),
		.corrected_pc_o		(corrected_pc),

		.is_branch_o		(is_branch_id_2_bpu),
		.is_jal_o			(is_jal_id_2_bpu),
		.branch_taken_o		(branch_taken_id_2_bpu),

        // .rdata_a_i(rdata_a),
        // .rdata_b_i(rdata_b),
		.fw_rs1_dat_i(rdata_a_fw),
		.fw_rs2_dat_i(rdata_b_fw),
        .raddr_a_o(raddr_a),
        .raddr_b_o(raddr_b),

        // .ex_wdata_i(ex_wdata_o),
        .ex_waddr_i(ex_waddr_o),
        // .ex_we_i(ex_we_o),

        // .mem_wdata_i(mem_wdata_o),
        // .mem_waddr_i(mem_waddr_o),
        // .mem_we_i(mem_we_o),

        .in_delayslot_i(in_delayslot_i),
        .next_in_delayslot_o(next_in_delayslot_o),
        .branch_flag_o(id_branch_flag_o),
        .branch_addr_o(branch_addr),
        // .link_addr_o(),
        .in_delayslot_o(id_in_delayslot_o),
        // .current_inst_addr_o(),

        .aluop_o(id_aluop_o),
        // .alusel_o(id_alusel_o),
        .reg1_o(id_reg1_o),
        .reg2_o(id_reg2_o),
        .we_o(id_we_o),
        .waddr_o(id_waddr_o),
        .imm_type_o(id_imm_type_o),
		.imm_o(id_imm_o),
        .use_reg1(id_use_reg1),
        .use_reg2(id_use_reg2),
        .mem_en_o(id_mem_en_o),
        .mem_sel_o(id_mem_sel_o),
        .pc_o(id_pc_o),
        .inst_o(id_inst_o),

		.reset_icache_o(reset_icache),
		.reset_dcache_o(id_reset_dcache_o),
		.reset_tlb_o(rst_tlb_id_2_tlb),

        .csr_we_o(id_csr_we_o),
        .csr_addr_o(id_csr_addr_o),

        .mem_stallreq(mem_stallreq),
        .stallreq(id_stallreq),
        .exception_o(id_exception_o)
    );

    logic [`RegBUS] wb_waddr_i;
    logic wb_we_i;
    logic [`DATABUS] wb_wdata_i;
	logic [`ADDRBUS] wb_pc_i;
    logic wb_csr_we_i;
    logic [31:0] wb_csr_waddr_i,wb_csr_wdata_i;
    logic [31:0] rdata_csr_fw, csr_rdata_o;
    logic [31:0] ex_csr_raddr_o;

    regfile u_regfile(
        .clk_i(clk_i),
        .rst_i(rst_i),

        .we(wb_we_i),
        .waddr(wb_waddr_i),
        .wdata(wb_wdata_i),
        .raddr_a(raddr_a),
        .raddr_b(raddr_b),
        .rdata_a(rdata_a),
        .rdata_b(rdata_b)
    );

    csrfile u_csrfile(
        .clk_i(clk_i),
		.rst_i(rst_i),

		.irq_software_i(irq_software_i),
		.irq_timer_i(irq_timer_i),
		.irq_external_i(irq_external_i),

        // read csr
		.raddr_i(ex_csr_raddr_o),
		.rdata_o(csr_rdata_o),

        //write csr
		.we_i(wb_csr_we_i),
		.waddr_i(wb_csr_waddr_i),
		.wdata_i(wb_csr_wdata_i),

        //from control
        .ie_type_i(ctrl_ie_type_o),
        .set_cause_i(ctrl_set_cause_o),
        .trap_cause_i(ctrl_trap_cause_o),

        .set_epc_i(ctrl_set_epc_o),
        .epc_i(ctrl_epc_o),

        .set_mtval_i(ctrl_set_mtval_o),
        .mtval_i(ctrl_mtval_o),

        .mstatus_ie_clear_i(ctrl_mstatus_ie_clear_o),
        .mstatus_ie_set_i(ctrl_mstatus_ie_set_o),

		// to control
        .mstatus_ie_o(csr_mstatus_ie_o),

        .mie_external_o(csr_mie_external_o),
        .mie_timer_o(csr_mie_timer_o),
        .mie_sw_o(csr_mie_sw_o),

        .mip_external_o(csr_mip_external_o),
		.mip_timer_o(csr_mip_timer_o),
        .mip_sw_o(csr_mip_sw_o),

        .mtvec_o(csr_mtvec_o),
		.epc_o(csr_epc_o),
        .mode_o(mode),
        .ppn_o(ppn)
    );

	forward u_forward(
		.rst_i		(rst_i),

		// id
		.radr1_i	(raddr_a),
		.radr2_i	(raddr_b),
		.rdat1_o	(rdata_a_fw),
		.rdat2_o	(rdata_b_fw),

		// rf
		.rf_rdat1_i	(rdata_a),
		.rf_rdat2_i	(rdata_b),

        // csr
        .csr_rdata_i(csr_rdata_o),
  
		// ex
        .ex_we_i	(ex_we_o),
		.ex_wadr_i	(ex_waddr_o),
		.ex_wdat_i	(ex_wdata_o),

        .csr_raddr_i(ex_csr_raddr_o),
        .csr_rdata_o(rdata_csr_fw),
  
		// mem
		.mem_we_i	(mem_we_o),
		.mem_wadr_i	(mem_waddr_o),
		.mem_wdat_i	(mem_wdata_o),
        
        .mem_csr_we_i(mem_csr_we_o),
        .mem_csr_waddr_i(mem_csr_waddr_o),
        .mem_csr_wdata_i(mem_csr_wdata_o),

		// wb
		.wb_we_i	(wb_we_i),
		.wb_wadr_i	(wb_waddr_i),
		.wb_wdat_i	(wb_wdata_i),

        .wb_csr_we_i(wb_csr_we_i),
        .wb_csr_waddr_i(wb_csr_waddr_i),
        .wb_csr_wdata_i(wb_csr_wdata_i)
	);

    logic [`RegBUS]  ex_waddr_i;
    logic ex_we_i;
    logic [31:0] ex_reg1_i;
    logic [31:0] ex_reg2_i;
    logic [`AluOpBUS]  ex_aluop_i;
    logic [31:0] ex_inst_i;
    logic [2:0] ex_imm_type_i;
	logic [`DATABUS] ex_imm_i;
    logic ex_use_reg1;
    logic ex_use_reg2;
    logic ex_mem_en_i;
    logic [3:0] ex_mem_sel_i;
    logic [31:0] ex_pc_i;
    logic ex_in_delayslot_i;
    logic ex_csr_we_i;
    logic [31:0] ex_csr_addr_i, ex_exception_i;

    id_ex u_id_ex(
        .clk_i(clk_i),
        .rst_i(rst_i),

        .stall(stall),
        .flush(flush),

        .id_pc(id_pc_o),
        .id_aluop(id_aluop_o),
        .id_reg1(id_reg1_o),
        .id_reg2(id_reg2_o),
        .id_waddr(id_waddr_o),
        .id_we(id_we_o),
        .id_imm_type(id_imm_type_o),
		.id_imm(id_imm_o),
        .id_use_reg1(id_use_reg1),
        .id_use_reg2(id_use_reg2),
        .id_mem_en(id_mem_en_o),
        .id_mem_sel(id_mem_sel_o),
        .id_inst(id_inst_o),
        .id_in_delayslot(id_in_delayslot_o),
        .next_in_delayslot_i(next_in_delayslot_o),
		.id_reset_dcache_i(id_reset_dcache_o),
        .id_csr_we(id_csr_we_o),
        .id_csr_addr(id_csr_addr_o),

        .id_exception(id_exception_o),

        .ex_pc(ex_pc_i),
        .ex_aluop(ex_aluop_i),
        .ex_reg1(ex_reg1_i),
        .ex_reg2(ex_reg2_i),
        .ex_waddr(ex_waddr_i),
        .ex_we(ex_we_i),
        .ex_imm_type(ex_imm_type_i),
		.ex_imm(ex_imm_i),
        .ex_use_reg1(ex_use_reg1),
        .ex_use_reg2(ex_use_reg2),
        .ex_mem_en(ex_mem_en_i),
        .ex_mem_sel(ex_mem_sel_i),
        .ex_inst(ex_inst_i),
        .ex_in_delayslot(ex_in_delayslot_i),
        .in_delayslot_o(in_delayslot_i),
		.ex_reset_dcache_o(ex_reset_dcache_i),
        .ex_csr_we(ex_csr_we_i),
        .ex_csr_addr(ex_csr_addr_i),

		.ex_exception(ex_exception_i)
  );

  logic [`DATABUS] ex_reg2_o, ex_pc_o, ex_inst_o;
  logic ex_in_delayslot_o;
  logic [3:0] ex_mem_sel_o;
  logic ex_mem_en_o;
  logic [31:0] ex_csr_waddr_o, ex_csr_wdata_o;
  logic ex_csr_we_o;
  logic [31:0] ex_exception_o;
  logic [`OpcodeBUS] mem_op_o;

  logic [`OpcodeBUS] ex_pre_op_o;
  logic [`RegBUS] ex_pre_waddr_o;

  ex u_ex(
    .rst_i(rst_i),

    .aluop_i(ex_aluop_i),
    .reg1_i(ex_reg1_i),
    .reg2_i(ex_reg2_i),
    .we_i(ex_we_i),
    .waddr_i(ex_waddr_i),
    .inst_i(ex_inst_i),
    .pc_i(ex_pc_i),
    .imm_type_i(ex_imm_type_i),
	.imm_i(ex_imm_i),
    .use_reg1(ex_use_reg1),
    .use_reg2(ex_use_reg2),
    .mem_en_i(ex_mem_en_i),
    .mem_sel_i(ex_mem_sel_i),
    .in_delayslot_i(ex_in_delayslot_i),
	.reset_dcache_i(ex_reset_dcache_i),
    .csr_we_i(ex_csr_we_i),
    .csr_addr_i(ex_csr_addr_i),
    .exception_i(ex_exception_i),
    .csr_raddr_o(ex_csr_raddr_o),
	.fw_csr_data_i(rdata_csr_fw),

    .pre_op_i(mem_op_o),
    .pre_op_o(ex_pre_op_o),
    .pre_waddr_i(mem_waddr_o),
    .pre_waddr_o(ex_pre_waddr_o),

    .we_o(ex_we_o),
    .waddr_o(ex_waddr_o),
    .wdata_o(ex_wdata_o),
    .mem_en_o(ex_mem_en_o),
    .mem_sel_o(ex_mem_sel_o),
    .inst_o(ex_inst_o),
    .pc_o(ex_pc_o),
    .op_o(ex_op_o),
    .reg2_o(ex_reg2_o),
    .in_delayslot_o(ex_in_delayslot_o),
	.reset_dcache_o(ex_reset_dcache_o),
    .stallreq(ex_stallreq),
    .csr_we_o(ex_csr_we_o),
    .csr_waddr_o(ex_csr_waddr_o),
    .csr_wdata_o(ex_csr_wdata_o),

    .exception_o(ex_exception_o)
  );

  logic mem_we_i;
  logic [`RegBUS] mem_waddr_i;
  logic [`DATABUS] mem_wdata_i;
  logic [`OpcodeBUS] mem_op_i;
  logic mem_en_i;
  logic [3:0] mem_sel_i;
  logic [`ADDRBUS] mem_pc_i;
  logic [`DATABUS] mem_inst_i;
  logic [`DATABUS] mem_reg2_i;
  logic mem_in_delayslot_i;
  logic mem_csr_we_i;
  logic [31:0] mem_csr_waddr_i,mem_csr_wdata_i;
  logic [31:0] mem_exception_i;

  ex_mem u_ex_mem(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .stall(stall),
    .flush(flush),

	.ex_we(ex_we_o),
    .ex_waddr(ex_waddr_o),
    .ex_wdata(ex_wdata_o),
    .ex_op(ex_op_o), 
    .ex_mem_en(ex_mem_en_o),
    .ex_mem_sel(ex_mem_sel_o),
    .ex_pc(ex_pc_o),
    .ex_inst(ex_inst_o),
    .ex_reg2(ex_reg2_o),
    .ex_in_delayslot(ex_in_delayslot_o),
	.ex_reset_dcache_i(ex_reset_dcache_o),
    .ex_csr_we(ex_csr_we_o),
    .ex_csr_waddr(ex_csr_waddr_o),
    .ex_csr_wdata(ex_csr_wdata_o),

    .ex_exception(ex_exception_o),

    .pre_op_i(ex_pre_op_o),
    .pre_rd_adr_i(ex_pre_waddr_o),
    .mem_data_i(mem_data_dtlb_2_mem),

	.mem_we(mem_we_i),
    .mem_waddr(mem_waddr_i),
    .mem_wdata(mem_wdata_i),
    .mem_op(mem_op_i),
    .mem_en(mem_en_i),
    .mem_sel(mem_sel_i),
    .mem_pc(mem_pc_i),
    .mem_inst(mem_inst_i),
    .mem_reg2(mem_reg2_i),
    .mem_in_delayslot(mem_in_delayslot_i),
	.mem_reset_dcache_o(mem_reset_dcache_i),
    .mem_csr_we(mem_csr_we_i),   
    .mem_csr_waddr(mem_csr_waddr_i),
    .mem_csr_wdata(mem_csr_wdata_i),

    .mem_exception(mem_exception_i)
  );

  logic mem_in_delayslot_o;
  logic mem_ce_mem_2_dtlb, mem_we_mem_2_dtlb;
  logic [`ADDRBUS] mem_addr_mem_2_dtlb;
  logic [`DATABUS] mem_data_mem_2_dtlb, mem_data_dtlb_2_mem;
  logic [3:0] mem_sel_mem_2_dtlb;

  mem u_mem(
    .clk_i(clk_i),
    .rst_i(rst_i),
			
    .we_i(mem_we_i),
    .waddr_i(mem_waddr_i),
    .wdata_i(mem_wdata_i),	
    .op_i(mem_op_i),
    .mem_en_i(mem_en_i),
    .mem_sel_i(mem_sel_i),
    .pc_i(mem_pc_i),
    .inst_i(mem_inst_i),
    .reg2_i(mem_reg2_i),
    .in_delayslot_i(mem_in_delayslot_i),	
    .mem_wbs3_choosen(wb_mem_wbs3_choosen_i),

    .csr_we_i(mem_csr_we_i),
    .csr_waddr_i(mem_csr_waddr_i),
    .csr_wdata_i(mem_csr_wdata_i),
    .exception_i(mem_exception_i),


    // mem-wb
	.pc_o(mem_pc_o),
    .we_o(mem_we_o),
    .waddr_o(mem_waddr_o),
    .wdata_o(mem_wdata_o),
    .csr_we_o(mem_csr_we_o),
    .csr_waddr_o(mem_csr_waddr_o),
    .csr_wdata_o(mem_csr_wdata_o),

    //wishbone
	.mem_ce_o(mem_ce_mem_2_dtlb),
    .mem_addr_o(mem_addr_mem_2_dtlb),
    .mem_we_o(mem_we_mem_2_dtlb),
    .mem_sel_o(mem_sel_mem_2_dtlb),
    .mem_data_o(mem_data_mem_2_dtlb),
    .mem_data_i(mem_data_dtlb_2_mem),
    
    .in_delayslot_o(mem_in_delayslot_o),
    .exception_o(mem_exception_o),
    .inst_o(mem_inst_o),

    .op_o(mem_op_o)
  );

  logic ce_dtlb_2_arb, we_dtlb_2_arb, ack_arb_2_dtlb;
  logic [`ADDRBUS] adr_dtlb_2_arb;
  logic [`DATABUS] dat_dtlb_2_arb, dat_arb_2_dtlb;
  logic [3:0] sel_dtlb_2_arb;

  mmu_tlb u_d_mmu_tlb(
		.clk_i		(clk_i),
		.rst_i		(rst_i),
		.is_if_tlb_i(1'b0),

		// ctrl
		.stallreq_o	(mem_stallreq),
		.flush_i(flush),

		// csr
		.mode_i			(mode), 
		.pt_base_adr_i	(ppn),
		.exception_o	(dtlb_exception),

		// cpu
		.cpu_ce_i	(mem_ce_mem_2_dtlb),
		.cpu_adr_i	(mem_addr_mem_2_dtlb),
		.cpu_dat_i	(mem_data_mem_2_dtlb),
		.cpu_we_i	(mem_we_mem_2_dtlb),
		.cpu_sel_i	(mem_sel_mem_2_dtlb),
		.cpu_dat_o	(mem_data_dtlb_2_mem),
		.cpu_rst_cache_i(mem_reset_dcache_i),

		// memory master
		.wb_ce_o	(ce_dtlb_2_arb),
		.wb_we_o	(we_dtlb_2_arb),
   		.wb_adr_o	(adr_dtlb_2_arb),
		.wb_dat_o	(dat_dtlb_2_arb),
    	.wb_sel_o	(sel_dtlb_2_arb),
    	.wb_dat_i	(dat_arb_2_dtlb),
		.wb_ack_i	(ack_arb_2_dtlb),

		// cache
		.cache_ce_o	(ce_dtlb_2_dcache),
		.cache_adr_o(adr_dtlb_2_dcache),	
		.cache_dat_o(dat_dtlb_2_dcache),	
		.cache_we_o	(we_dtlb_2_dcache),	
		.cache_sel_o(sel_dtlb_2_dcache),	
		.cache_dat_i(dat_dcache_2_dtlb),
		.cache_ack_i(ack_dcache_2_dtlb),
		.cache_rst_cache_o(rst_dcache_dtlb_2_dcache),

		// id
		.reset_tlb_i(rst_tlb_id_2_tlb)
	);		

	logic ce_dtlb_2_dcache, we_dtlb_2_dcache, ack_dcache_2_dtlb;
	logic [`ADDRBUS] adr_dtlb_2_dcache;
	logic [`DATABUS] dat_dtlb_2_dcache, dat_dcache_2_dtlb;
	logic [3:0] sel_dtlb_2_dcache;


	logic ce_dcache_2_arb, we_dcache_2_arb, ack_arb_2_dcache;
	logic [`ADDRBUS] adr_dcache_2_arb, prev_adr_dcache_2_arb;
	logic [`DATABUS] dat_dcache_2_arb, dat_arb_2_dcache;
	logic [3:0] sel_dcache_2_arb, dirty_dcache_2_arb;
	logic reset_cache_dcache_2_arb;

  dcache u_dcache(
	.clk_i(clk_i),
    .rst_i(rst_i),

	.mem_ce_i(ce_dtlb_2_dcache),
	.mem_adr_i(adr_dtlb_2_dcache),
	.mem_dat_i(dat_dtlb_2_dcache),
	.mem_we_i(we_dtlb_2_dcache),
	.mem_sel_i(sel_dtlb_2_dcache),
	.mem_dat_o(dat_dcache_2_dtlb),
	.mem_ack_o(ack_dcache_2_dtlb),

	.wb_ce_o(ce_dcache_2_arb),
	.wb_we_o(we_dcache_2_arb),
	.wb_adr_o(adr_dcache_2_arb),
	.wb_prev_adr_o(prev_adr_dcache_2_arb), 
	.wb_dat_o(dat_dcache_2_arb),
	.wb_sel_o(sel_dcache_2_arb),
	.wb_dirty_o(dirty_dcache_2_arb),	
	.wb_dat_i(dat_arb_2_dcache),
	.wb_ack_i(ack_arb_2_dcache),

	// .stallreq_o(mem_stallreq),

	.reset_cache_i(rst_dcache_dtlb_2_dcache), 
	.reset_cache_o(reset_cache_dcache_2_arb) 
  );

mem_master_arbiter u_d_arbiter(
	.rst_i(rst_i),

	// cache
	.cache_ce_i(ce_dcache_2_arb),
	.cache_adr_i(adr_dcache_2_arb),
	.cache_sel_i(sel_dcache_2_arb),
	.cache_we_i(we_dcache_2_arb),
	.cache_dat_i(dat_dcache_2_arb),

	.cache_prev_adr_i(prev_adr_dcache_2_arb),
	.cache_dirty_i(dirty_dcache_2_arb),
	.cache_reset_cache_i(reset_cache_dcache_2_arb),

	.cache_dat_o(dat_arb_2_dcache),
	.cache_ack_o(ack_arb_2_dcache),

	// tlb
	.tlb_ce_i(ce_dtlb_2_arb),
	.tlb_adr_i(adr_dtlb_2_arb),
	.tlb_sel_i(sel_dtlb_2_arb),
	.tlb_we_i(we_dtlb_2_arb),
	.tlb_dat_i(dat_dtlb_2_arb),

	.tlb_dat_o(dat_arb_2_dtlb),
	.tlb_ack_o(ack_arb_2_dtlb),

	// mem_master
	.mm_ce_o(wb_mem_ce_o),
	.mm_adr_o(wb_mem_addr_o),
	.mm_sel_o(wb_mem_sel_o),
	.mm_we_o(wb_mem_we_o),
	.mm_dat_o(wb_mem_data_o),

	.mm_prev_adr_o(wb_mem_prev_addr_o),
	.mm_dirty_o(wb_mem_dirty_o),
	.mm_reset_cache_o(wb_mem_reset_cache_o),
	
	.mm_dat_i(wb_mem_data_i),
	.mm_ack_i(wb_mem_ack_i)
);
  mem_wb u_mem_wb(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .stall(stall),
    .flush(flush),

    .mem_pc(mem_pc_o),
	.mem_we(mem_we_o),
    .mem_waddr(mem_waddr_o),
    .mem_wdata(mem_wdata_o),

    .mem_csr_we(mem_csr_we_o),
    .mem_csr_waddr(mem_csr_waddr_o),
    .mem_csr_wdata(mem_csr_wdata_o),

    .wb_pc(wb_pc_i),
    .wb_we(wb_we_i),
    .wb_waddr(wb_waddr_i),
    .wb_wdata(wb_wdata_i),

    .wb_csr_we(wb_csr_we_i),
    .wb_csr_waddr(wb_csr_waddr_i),
    .wb_csr_wdata(wb_csr_wdata_i)
  );

    /* =========== ILA begin =========== */

	// ila_0 ila(
	// 	.clk(clk_i),
	// 	.probe0(id_pc_i),
	// 	.probe1(ex_pc_i),
	// 	.probe2(mem_pc_i)
	// );

  /* =========== ILA end =========== */

endmodule