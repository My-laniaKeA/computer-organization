`include "define.sv"

module csrfile(

    input wire               clk_i,
    input wire               rst_i,

    // from clint
    input  wire              irq_software_i, // interrupt request
    input  wire              irq_timer_i, 
    input  wire              irq_external_i,

    // from exe
    input wire[`ADDRBUS]      raddr_i,           // the register to read
    output reg[`DATABUS]      rdata_o,           // ouput the register


    // from wb
    input wire               we_i,            // write enable
    input wire[`ADDRBUS]      waddr_i,         // the register to write
    input wire[`DATABUS]      wdata_i,         // the data to write

    // from ctrl
    input wire               ie_type_i,          // interrupt or exception
    input wire               set_cause_i,
    input wire [3:0]         trap_cause_i,

    input wire               set_epc_i,
    input wire[`ADDRBUS]     epc_i,

    input wire               set_mtval_i,
    input wire[`DATABUS]     mtval_i,

    input wire               mstatus_ie_clear_i,
    input wire               mstatus_ie_set_i,

    // to ctrl
    output reg              mstatus_ie_o,
    output reg              mie_external_o,
    output reg              mie_timer_o,
    output reg              mie_sw_o,

    output reg              mip_external_o,
    output reg              mip_timer_o,
    output reg              mip_sw_o,
    output reg[`DATABUS]     mtvec_o,
    output reg[`ADDRBUS]     epc_o,
    output reg [1:0]         mode_o,
    output reg [31:0]        ppn_o
);

    /*--------------------------------------------- mstatus ----------------------------------------*/
    // {SD(1), WPRI(8), TSR(1), TW(1), TVM(1), MXR(1), SUM(1), MPRV(1), XS(2),
    //  FS(2), MPP(2), WPRI(2), SPP(1), MPIE(1), WPRI(1), SPIE(1), UPIE(1),MIE(1), WPRI(1), SIE(1), UIE(1)}
    // Global interrupt-enable bits, MIE, SIE, and UIE, are provided for each privilege mode.
    // xPIE holds the value of the interrupt-enable bit active prior to the trap, and xPP holds the previous privilege mode.
    reg[`DATABUS]       mstatus;
    reg                mstatus_pie; // prior interrupt enable
    reg                mstatus_ie;
    reg[1:0]           mstatus_mpp; //FIXME ecall/ebreak -> MMode mret -> UMode
    reg[1:0]           mstatus_pm;  // privilege mode
    assign             mstatus_ie_o = mstatus_ie;
    assign mstatus = {19'b0, mstatus_mpp, 3'b0, mstatus_pie, 3'b0 , mstatus_ie, 3'b0};
    assign mode_o = mstatus_pm;

    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            mstatus_ie <= 1'b0;
            mstatus_pie <= 1'b1;
            mstatus_mpp <= 2'b11; 
            mstatus_pm <= 2'b11;
        end else if( (waddr_i[11:0] == `CSR_MSTATUS_ADDR) && (we_i == `Enable)) begin
            mstatus_ie <= wdata_i[3];
            mstatus_pie <= wdata_i[7];
            mstatus_mpp <= wdata_i[12:11];
        end else if(mstatus_ie_clear_i == 1'b1) begin // ebreak etc. exceptions
            mstatus_pie <= mstatus_ie;
            mstatus_ie <= 1'b0;
            mstatus_mpp <= mstatus_pm;
            mstatus_pm <= 2'b11;
        end else if(mstatus_ie_set_i == 1'b1) begin // mret
            mstatus_ie <= mstatus_pie;
            mstatus_pie <= 1'b1;
            mstatus_pm <= mstatus_mpp;
            mstatus_mpp <= 2'b0;
        end
    end


    /*--------------------------------------------- mie ----------------------------------------*/
    // mie: {WPRI[31:12], MEIE(1), WPRI(1), SEIE(1), UEIE(1), MTIE(1), WPRI(1), STIE(1), UTIE(1), MSIE(1), WPRI(1), SSIE(1), USIE(1)}
    // MTIE, STIE, and UTIE for M-mode, S-mode, and U-mode timer interrupts respectively.
    // MSIE, SSIE, and USIE fields enable software interrupts in M-mode, S-mode software, and U-mode, respectively.
    // MEIE, SEIE, and UEIE fields enable external interrupts in M-mode, S-mode software, and U-mode, respectively.
    reg[`DATABUS]  mie;
    reg           mie_external; // external interrupt enable
    reg           mie_timer;    // timer interrupt enable
    reg           mie_sw;       // software interrupt enable

    assign mie_external_o = mie_external;
    assign mie_timer_o = mie_timer;
    assign mie_sw_o = mie_sw;

    assign mie = {20'b0, mie_external, 3'b0, mie_timer, 3'b0, mie_sw, 3'b0};

    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            mie_external <= 1'b0;
            mie_timer <= 1'b0;
            mie_sw <= 1'b0;
        end else if((waddr_i[11:0] == `CSR_MIE_ADDR) && (we_i == `Enable)) begin
            mie_external <= wdata_i[11];
            mie_timer <= wdata_i[7];
            mie_sw <= wdata_i[3];
        end
    end


    /*--------------------------------------------- mtvec ----------------------------------------*/
    // The mtvec register is an MXLEN-bit read/write register that holds trap vector configuration,
    // consisting of a vector base address (BASE) and a vector mode (MODE).
    // mtvec = { base[maxlen-1:2], mode[1:0]}
    // The value in the BASE field must always be aligned on a 4-byte boundary, and the MODE setting may impose
    // additional alignment constraints on the value in the BASE field.
    // when mode =2'b00, direct mode, When MODE=Direct, all traps into machine mode cause the pc to be set to the address in the BASE field.
    // when mode =2'b01, Vectored mode, all synchronous exceptions into machine mode cause the pc to be set to the address in the BASE
    // field, whereas interrupts cause the pc to be set to the address in the BASE field plus four times the interrupt cause number.

    reg[`DATABUS]     mtvec;
    assign mtvec_o = mtvec;

    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            mtvec <= `MTVEC_RESET;
        end else if( (waddr_i[11:0] == `CSR_MTVEC_ADDR) && (we_i == `Enable) ) begin
            mtvec <= wdata_i;
        end
    end


    /*--------------------------------------------- mscratch ----------------------------------------*/
    // mscratch : Typically, it is used to hold a pointer to a machine-mode hart-local context space and swapped
    // with a user register upon entry to an M-mode trap handler.
    reg[`DATABUS]       mscratch;

    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable)
            mscratch <= `ZeroWord;
        else if( (waddr_i[11:0] == `CSR_MSCRATCH_ADDR) && (we_i == `Enable) )
            mscratch <= wdata_i;
    end

    /*--------------------------------------------- mepc ----------------------------------------*/
    // When a trap is taken into M-mode, mepc is written with the virtual address of the instruction
    // that was interrupted or that encountered the exception.
    // The low bit of mepc (mepc[0]) is always zero.
    // On implementations that support only IALIGN=32, the two low bits (mepc[1:0]) are always zero.
    reg[`DATABUS]       mepc;

    assign epc_o = mepc;
    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable)
            mepc <= `ZeroWord;
        else if(set_epc_i)
            mepc <= {epc_i[31:2], 2'b00};
        else if( (waddr_i[11:0] == `CSR_MEPC_ADDR) && (we_i == `Enable) )
            mepc <= {wdata_i[31:2], 2'b00};
    end


    /*--------------------------------------------- mcause ----------------------------------------*/
    // When a trap is taken into M-mode, mcause is written with a code indicating the event that caused the trap.
    // Otherwise, mcause is never written by the implementation, though it may be explicitly written by software.
    // mcause = {interupt[31:30], Exception code }
    // The Interrupt bit in the mcause register is set if the trap was caused by an interrupt. The Exception
    // Code field contains a code identifying the last exception.

    reg[`DATABUS]       mcause;
    reg [3:0]          cause; // interrupt cause
    reg [26:0]         cause_rem; // remaining bits of mcause register
    reg                int_or_exc; // interrupt or exception signal

    assign mcause = {int_or_exc, cause_rem, cause};
    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            cause <= 4'b0000;
            cause_rem <= 27'b0;
            int_or_exc <= 1'b0;
        end else if(set_cause_i) begin
            cause <= trap_cause_i;
            cause_rem <= 27'b0;
            int_or_exc <= ie_type_i;
        end else if( (waddr_i[11:0] == `CSR_MCAUSE_ADDR) && (we_i == `Enable) ) begin
            cause <= wdata_i[3:0];
            cause_rem <= wdata_i[30:4];
            int_or_exc <= wdata_i[31];
        end
    end

    /*--------------------------------------------- mip ----------------------------------------*/
    // mip: {WPRI[31:12], MEIP(1), WPRI(1), SEIP(1), UEIP(1), MTIP(1), WPRI(1), STIP(1), UTIP(1), MSIP(1), WPRI(1), SSIP(1), USIP(1)}
    // The MTIP, STIP, UTIP bits correspond to timer interrupt-pending bits for machine, supervisor, and user timer interrupts, respectively.
    reg[`DATABUS]      mip;
    reg                mip_external; // external interrupt pending
    reg                mip_timer; // timer interrupt pending
    reg                mip_sw; // software interrupt pending

    assign mip = {20'b0, mip_external, 3'b0, mip_timer, 3'b0, mip_sw, 3'b0};

    assign mip_external_o = mip_external;
    assign mip_timer_o = mip_timer;
    assign mip_sw_o = mip_sw;

    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            mip_external <= 1'b0;
            mip_timer <= 1'b0;
            mip_sw <= 1'b0;
        end else begin
            mip_external <= irq_external_i;
            mip_timer <= irq_timer_i;
            mip_sw <= irq_software_i;
        end
    end

    /*--------------------------------------------- mtval ----------------------------------------*/
    // When a trap is taken into M-mode, mtval is either set to zero or written with exception-specific information
    // to assist software in handling the trap.
    // When a hardware breakpoint is triggered, or an instruction-fetch, load, or store address-misaligned,
    // access, or page-fault exception occurs, mtval is written with the faulting virtual address.
    // On an illegal instruction trap, mtval may be written with the first XLEN or ILEN bits of the faulting instruction
    reg[`DATABUS]       mtval;
    // wire               MISALIGNED_EXCEPTION;  //todo

    always_ff @(posedge clk_i)  begin
        if(rst_i == `Enable)
            mtval <= 32'b0;
        else if(set_mtval_i) begin
            mtval <= mtval_i;
        end else if((waddr_i[11:0] == `CSR_MTVAL_ADDR) && (we_i == `Enable)) begin
            mtval <= wdata_i;
        end
    end

    /*--------------------------------------------- pmpcfg0 ----------------------------------------*/
    // pmpcfg: {L(1), 2'b0, A(2), X(1), W(1), R(1)}
    // TODO physical memory protection
    reg[`DATABUS]      pmpcfg0;
    reg[7:0]           pmp3cfg;
    reg[7:0]           pmp2cfg;
    reg[7:0]           pmp1cfg;
    reg[7:0]           pmp0cfg;

    assign {pmp3cfg, pmp2cfg, pmp1cfg, pmp0cfg} = pmpcfg0;

    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            pmpcfg0 <= 32'b0;
        end else if( (waddr_i[11:0] == `CSR_PMPCFG0_ADDR) && (we_i == `Enable)) begin
            pmpcfg0 <= wdata_i;
        end
    end

    /*--------------------------------------------- pmpaddr0 ----------------------------------------*/
    // pmpaddr0: {addr[33:2]}
    // TODO physical memory protection
    reg[`DATABUS]      pmpaddr0;

    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            pmpaddr0 <= 32'b0;
        end else if( (waddr_i[11:0] == `CSR_PMPCFGADDR0_ADDR) && (we_i == `Enable)) begin
            pmpaddr0 <= wdata_i;
        end
    end

    /*--------------------------------------------- satp ----------------------------------------*/
    // satp: {MODE(1), 9'b0, PPN(22)}
    reg[`DATABUS]  satp;
    reg[21:0]      ppn;
    reg            mode;

    assign satp = {mode, 9'b0, ppn};
    assign ppn_o = {ppn[19:0], 12'b0};

    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            mode <= 1'b0;
            ppn <= 22'b0;
        end else if( (waddr_i[11:0] == `CSR_SATP_ADDR) && (we_i == `Enable)) begin
            mode <= wdata_i[31];
            ppn <= wdata_i[21:0];
        end
    end

    /* ----------------------- read csr --------------------------------------*/
    always_comb begin
        // bypass the write port to the read port
        if ((waddr_i[11:0] == raddr_i[11:0]) && (we_i == `Enable)) begin
            rdata_o = wdata_i;
        end else begin
            case (raddr_i[11:0])

                `CSR_MSTATUS_ADDR: begin
                    rdata_o = mstatus;
                end

                `CSR_MIE_ADDR: begin
                    rdata_o = mie;
                end

                `CSR_MTVEC_ADDR: begin
                    rdata_o = mtvec;
                end

                `CSR_MTVAL_ADDR: begin
                    rdata_o = mtval;
                end

                `CSR_MSCRATCH_ADDR: begin
                    rdata_o = mscratch;
                end

                `CSR_MEPC_ADDR: begin
                    rdata_o = mepc;
                end

                `CSR_MCAUSE_ADDR: begin
                    rdata_o = mcause;
                end

                `CSR_MIP_ADDR: begin
                    rdata_o = mip;
                end

                `CSR_PMPCFG0_ADDR: begin
                    rdata_o = pmpcfg0;
                end

                `CSR_PMPCFGADDR0_ADDR: begin
                    rdata_o = pmpaddr0;
                end

                `CSR_SATP_ADDR: begin
                    rdata_o = satp;
                end

                default: begin
                    rdata_o = `ZeroWord;
                end
            endcase // case (waddr_i[11:0])
        end //end else begin
    end //always_ff @ (*) begin
endmodule
