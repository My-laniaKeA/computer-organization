`include "define.sv"

module ctrl(
    input wire rst_i,
    input wire clk_i,

    input wire[`DATABUS]          exception_i,
    input wire[`ADDRBUS]          pc_i,
    input wire[`DATABUS]          inst_i,
    input wire itlb_exception,
    input wire dtlb_exception,
    
    input wire if_stallreq,
    input wire id_stallreq,
    input wire ex_stallreq,
    input wire mem_stallreq,

    // from csr
    input wire                   mstatus_ie_i,    // global interrupt enabled or not
    input wire                   mie_external_i,  // external interrupt enbled or not
    input wire                   mie_timer_i,     // timer interrupt enabled or not
    input wire                   mie_sw_i,        // sw interrupt enabled or not

    input wire                   mip_external_i,   // external interrupt pending
    input wire                   mip_timer_i,      // timer interrupt pending
    input wire                   mip_sw_i,         // sw interrupt pending

    input wire[`DATABUS]          mtvec_i,          // the trap vector
    input wire[`ADDRBUS]          epc_i,            // get the epc for the mret instruction

    // to csr
    output reg                   ie_type_o,
    output reg                   set_cause_o,
    output reg[3:0]              trap_cause_o,

    output reg                   set_epc_o,
    output reg[`ADDRBUS]         epc_o,

    output reg                   set_mtval_o,
    output reg[`DATABUS]         mtval_o,

    output reg                   mstatus_ie_clear_o,
    output reg                   mstatus_ie_set_o,

    output reg [5:0] stall,
    output reg flush,
    output reg [`ADDRBUS] new_pc

);
    
    /* -- handle stall signal --*/
    always_comb begin
        if(rst_i) begin
            stall = 6'b000000;
        end else if(mem_stallreq == `Stop) begin
            stall = 6'b011111;
        end else if(ex_stallreq == `Stop) begin
            stall = 6'b001111;
        end else if(id_stallreq == `Stop) begin
            stall = 6'b000111;
        end else if(if_stallreq == `Stop) begin
            stall = 6'b000111;
        end else begin
            stall = 6'b000000;
        end
    end

    /* -- handle the interrupt and exceptions --*/
    typedef enum logic [1:0] {
        STATE_RESET = 0,
        STATE_OPERATING = 1,
        STATE_TRAP_TAKEN = 2,
        STATE_TRAP_RETURN = 3
        } state_t;

    state_t state;

    wire   mret;
    wire   ecall;
    wire   ebreak;
    wire   misaligned_inst;
    wire   illegal_inst;
    wire   misaligned_store;
    wire   misaligned_load;

    assign {misaligned_load, misaligned_store, illegal_inst, misaligned_inst, ebreak, ecall, mret} = exception_i[6:0];

    /* check there is a interrupt on pending*/
    wire   eip;
    wire   tip;
    wire   sip;
    wire   ip;

    assign eip = mie_external_i & mip_external_i;
    assign tip = mie_timer_i &  mip_timer_i;
    assign sip = mie_sw_i & mip_sw_i;
    assign ip = eip | tip | sip;

    /* an interrupt or an exception, need to be processed */
    wire   trap_happened;
    assign trap_happened = (mstatus_ie_i & ip) | ecall | ebreak | misaligned_inst | illegal_inst | misaligned_store | misaligned_load | itlb_exception | dtlb_exception;

    always_ff @(posedge clk_i) begin
        if(rst_i) begin
            state <= STATE_RESET;
        end else begin
            case(state)
                STATE_RESET: begin
                    state <= STATE_OPERATING;
                end
                STATE_OPERATING: begin
                    if(trap_happened)
                        state <= STATE_TRAP_TAKEN;
                    else if(mret)
                        state <= STATE_TRAP_RETURN;
                    else
                        state <= STATE_OPERATING;
                end
                STATE_TRAP_TAKEN: begin
                    state <= STATE_OPERATING;
                end
                STATE_TRAP_RETURN: begin
                    state <= STATE_OPERATING;
                end
                default: begin
                    state <= STATE_OPERATING;
                end
            endcase
        end
    end

    assign epc_o = pc_i;

    reg [1:0]          mtvec_mode; // machine trap mode
    reg [29:0]         mtvec_base; // machine trap base address

    assign mtvec_base = mtvec_i[31:2];
    assign mtvec_mode = mtvec_i[1:0];

    reg  [`DATABUS] trap_mux_out;
    wire [`DATABUS] vec_mux_out;
    wire [`DATABUS] base_offset;

    // mtvec = { base[maxlen-1:2], mode[1:0]}
    // The value in the BASE field must always be aligned on a 4-byte boundary, and the MODE setting may impose
    // additional alignment constraints on the value in the BASE field.
    // when mode =2'b00, direct mode, When MODE=Direct, all traps into machine mode cause the pc to be set to the address in the BASE field.
    // when mode =2'b01, Vectored mode, all synchronous exceptions into machine mode cause the pc to be set to the address in the BASE
    // field, whereas interrupts cause the pc to be set to the address in the BASE field plus four times the interrupt cause number.
    assign base_offset = {26'b0, trap_cause_o, 2'b0};  // trap_cause_o * 4
    assign vec_mux_out = mtvec_i[0] ? {mtvec_base, 2'b00} + base_offset : {mtvec_base, 2'b00};
    assign trap_mux_out = ie_type_o ? vec_mux_out : {mtvec_base, 2'b00};

    // output generation
    always_comb begin
        case(state)
            STATE_RESET: begin
                flush = 1'b0;
                new_pc = 32'h8000_0000; //TODO 确认更新后pc值
                set_epc_o = 1'b0;
                set_cause_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end
            STATE_OPERATING: begin
                flush = 1'b0;
                new_pc = `ZeroWord;
                set_epc_o = 1'b0;
                set_cause_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end
            STATE_TRAP_TAKEN: begin
                flush = 1'b1;
                new_pc = trap_mux_out;       // jump to the trap handler
                set_epc_o = 1'b1;              // update the epc csr
                set_cause_o = 1'b1;            // update the mcause csr
                mstatus_ie_clear_o = 1'b1;     // disable the mie bit in the mstatus ebreak
                mstatus_ie_set_o = 1'b0;
            end
            STATE_TRAP_RETURN: begin //mret
                flush = 1'b1;
                new_pc =  epc_i;
                set_epc_o = 1'b0;
                set_cause_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b1;      //enable the mie
            end
            default: begin
                flush = 1'b0;
                new_pc = `ZeroWord;
                set_epc_o = 1'b0;
                set_cause_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end
        endcase
    end

    /* update the mcause csr */
    always_ff @(posedge clk_i) begin
        if(rst_i == `Enable) begin
            trap_cause_o <= 4'b0;
            ie_type_o <= 1'b0;
            set_mtval_o <= 1'b0;
            mtval_o <= `ZeroWord;

        end else if(state == STATE_OPERATING) begin
            if(mstatus_ie_i & eip) begin
                trap_cause_o <= 4'b1011; // M-mode external interrupt
                ie_type_o <= 1'b1;
            end else if(mstatus_ie_i & sip) begin
                trap_cause_o <= 4'b0011; // M-mode software interrupt
                ie_type_o <= 1'b1;
            end else if(mstatus_ie_i & tip) begin
                trap_cause_o <= 4'b0111; // M-mode timer interrupt
                ie_type_o <= 1'b1;

            end else if(misaligned_inst) begin
                trap_cause_o <= 4'b0000; // Instruction address misaligned, cause = 0
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end else if(illegal_inst) begin
                trap_cause_o <= 4'b0010; // Illegal instruction, cause = 2
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= inst_i;     //set to the instruction

            end else if(ebreak) begin
                trap_cause_o <= 4'b0011; // Breakpoint, cause =3
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end else if(misaligned_store) begin
                trap_cause_o <= 4'b0110; // Store address misaligned  //cause 6
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end else if(misaligned_load) begin
                trap_cause_o <= 4'b0100; // Load address misaligned  cause =4
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end else if(itlb_exception || dtlb_exception) begin
                trap_cause_o <= 4'b0101; // Load/Store access fault  cause =5/7 //TODO
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end else if(ecall) begin
                trap_cause_o <= 4'b1011; // ecall from M-mode, cause = 11
                ie_type_o <= 1'b0;
            end
        end
    end

endmodule