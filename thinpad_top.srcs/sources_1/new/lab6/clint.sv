module clint #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input  wire                    clk_i,
    input  wire                    rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,

    // output reg                    timer_err_o,
    output reg                    timer_intr_o
);

    // The timers are always 64 bits
    localparam int unsigned TW = 64;

    // Register map 
    localparam bit [31:0] MTIME_LOW =32'h200BFF8;
    localparam bit [31:0] MTIME_HIGH = 32'h200BFFC;
    localparam bit [31:0] MTIMECMP_LOW = 32'h2004000;
    localparam bit [31:0] MTIMECMP_HIGH = 32'h2004004;

    reg                 timer_we;
    reg                 mtime_we, mtimeh_we;
    reg                 mtimecmp_we, mtimecmph_we;
    reg [DATA_WIDTH-1:0] mtime_wdata, mtimeh_wdata;
    reg [DATA_WIDTH-1:0] mtimecmp_wdata, mtimecmph_wdata;
    reg [TW-1:0]        mtime_q, mtime_d, mtime_inc;
    reg [TW-1:0]        mtimecmp_q, mtimecmp_d;
    reg                 interrupt_q, interrupt_d;
    reg                 error_q, error_d;
    reg [DATA_WIDTH-1:0] rdata_q, rdata_d;
    reg                 rvalid_q;

    // Global write enable for all registers
    assign timer_we = wb_stb_i & wb_cyc_i & wb_we_i;

    // mtime increments every cycle
    assign mtime_inc = mtime_q + 64'd1;

    // Generate write data based on byte strobes
    for (genvar b = 0; b < DATA_WIDTH / 8; b++) begin : gen_byte_wdata

        assign mtime_wdata[(b*8)+:8]     = wb_sel_i[b] ? wb_dat_i[b*8+:8] : mtime_q[(b*8)+:8];
        assign mtimeh_wdata[(b*8)+:8]    = wb_sel_i[b] ? wb_dat_i[b*8+:8] : mtime_q[DATA_WIDTH+(b*8)+:8];
        assign mtimecmp_wdata[(b*8)+:8]  = wb_sel_i[b] ? wb_dat_i[b*8+:8] : mtimecmp_q[(b*8)+:8];
        assign mtimecmph_wdata[(b*8)+:8] = wb_sel_i[b] ? wb_dat_i[b*8+:8] : mtimecmp_q[DATA_WIDTH+(b*8)+:8];
    end

    // Generate write enables 
    assign mtime_we     = timer_we & (wb_adr_i == MTIME_LOW);
    assign mtimeh_we    = timer_we & (wb_adr_i == MTIME_HIGH);
    assign mtimecmp_we  = timer_we & (wb_adr_i == MTIMECMP_LOW);
    assign mtimecmph_we = timer_we & (wb_adr_i == MTIMECMP_HIGH);

    // Generate next data
    assign mtime_d    = {(mtimeh_we    ? mtimeh_wdata    : mtime_inc[63:32]),  (mtime_we     ? mtime_wdata     : mtime_inc[31:0])};
    assign mtimecmp_d = {(mtimecmph_we ? mtimecmph_wdata : mtimecmp_q[63:32]), (mtimecmp_we  ? mtimecmp_wdata  : mtimecmp_q[31:0])};

    // Generate registers
    always @(posedge clk_i) begin
        if (rst_i) begin
            mtime_q <= 'b0;
        end else begin
            mtime_q <= mtime_d;
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            mtimecmp_q <= 64'hFFFF_FFFF_FFFF_FFFF;
        end else if (mtimecmp_we | mtimecmph_we) begin
            mtimecmp_q <= mtimecmp_d;
        end
    end

    // interrupt remains set until mtimecmp is written
    assign interrupt_d  = ((mtime_q >= mtimecmp_q) | interrupt_q) & ~(mtimecmp_we | mtimecmph_we);

    always @(posedge clk_i) begin
        if (rst_i) begin
            interrupt_q <= 'b0;
        end else begin
            interrupt_q <= interrupt_d;
        end
    end

    assign timer_intr_o = interrupt_q;

    // Read data
    always @ ( * ) begin
        rdata_d = 'b0;
        error_d = 1'b0;
        case (wb_adr_i)
            MTIME_LOW:     rdata_d = mtime_q[31:0];
            MTIME_HIGH:    rdata_d = mtime_q[63:32];
            MTIMECMP_LOW:  rdata_d = mtimecmp_q[31:0];
            MTIMECMP_HIGH: rdata_d = mtimecmp_q[63:32];
            default: begin
                rdata_d = 'b0;
                // Error if no address matched
                error_d = 1'b1;
            end
        endcase
    end

    // error_q and rdata_q are only valid when rvalid_q is high  //shawn modified to the same cycle
    always @(*) begin    //posedge clk_i
        if (wb_stb_i & wb_cyc_i) begin
            rdata_q = rdata_d;
            error_q = error_d;
        end else begin
            rdata_q = 32'b0;
            error_q = 1'b0;      
        end
    end

    assign wb_dat_o = rdata_q;

    // Read data is always valid one cycle after a request   //shawn modified to the same cycle
    always_ff @(posedge clk_i) begin    //posedge clk_i or negedge rst_i
        if (rst_i) begin
            rvalid_q <= 1'b0;
        end else begin
            rvalid_q <= wb_stb_i & wb_cyc_i;
        end
    end
    
        
    assign wb_ack_o = rvalid_q;
    // assign timer_err_o = error_q;

endmodule
