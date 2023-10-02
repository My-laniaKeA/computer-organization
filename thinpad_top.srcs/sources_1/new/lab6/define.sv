`define OpcodeBUS 6:0
`define DATABUS 31:0
`define ADDRBUS 31:0
`define RegBUS 4:0

`define OpRtype     7'b0110011
`define OpItype     7'b0010011
`define OpLoad      7'b0000011
`define OpStore     7'b0100011
`define OpBranch    7'b1100011
`define OpJAL       7'b1101111
`define OpJALR      7'b1100111
`define OpLUI       7'b0110111
`define OpAUIPC     7'b0010111
`define OpCSR       7'b1110011
`define OpFence		7'b0001111

`define funct3Add   3'h0
`define funct3Xor   3'h4
`define funct3Or    3'h6
`define funct3And   3'h7
`define funct3Sll   3'h1
`define funct3Sbclr 3'h1
`define funct3Srl   3'h5
`define funct3Sra   3'h5
`define funct3Slt   3'h2
`define funct3Sltu  3'h3
`define funct3Environ 3'b0
`define funct3CSRRW 3'b001
`define funct3CSRRS 3'b010
`define funct3CSRRC 3'b011

`define funct7Base  7'h0
`define funct7Sub   7'h20
`define funct7Sra   7'h20
`define funct7Pcnt  7'h30
`define funct7Minu  7'h05
`define funct7Sbclr 7'h24
`define funct7Sfence 7'b0001001 
`define funct3Lb    3'h0
`define funct3Lw    3'h2
`define funct3Sb    3'h0
`define funct3Sw    3'h2
`define funct3Beq   3'h0
`define funct3Bne   3'h1



//TODO funct load-environ

`define FLASHADDRBUS 22:0
`define FLASHDATABUS 15:0
`define BRAMADDRBUS 18:0
`define BRAMDATABUS 7:0

`define ZeroWord 32'b0
`define Disable 1'b0
`define Enable 1'b1
`define Stop 1'b1
`define NoStop 1'b0
`define Branch 1'b1
`define NotBranch 1'b0
`define InDelaySlot 1'b1
`define NotInDelaySlot 1'b0

`define AluOpBUS 4:0 //FIXME 确认一下有多少个OP
`define AluNOP 5'd0
`define AluADD 5'd1
`define AluAND 5'd2
`define AluSUB 5'd3
`define AluXOR 5'd4
`define AluOR  5'd5
`define AluNOT 5'd6
`define AluSLL 5'd7
`define AluSRL 5'd8
`define AluPC  5'd9
`define AluSETB 5'd10
`define AluPCNT 5'd11
`define AluMINU 5'd12
`define AluSBCLR 5'd13
`define AluSTLU 5'd14
`define AluCSRRW 5'd15
`define AluCSRRS 5'd16
`define AluCSRRC 5'd17


`define immI 3'b000
`define immS 3'b001
`define immB 3'b010
`define immU 3'b011
`define immJ 3'b100
`define immR 3'b101

/*-------------------------- Cache -------------------------*/
`define CTE_NUM 	16		// cache table entry num in one way
`define Valid 		1'b1
`define Invalid 	1'b0
`define Dirty		1'b1
`define NotDirty	1'b0

/* ------ I-Cache ---------*/
`define ICTE_WIDTH 	60
`define ICTE_VALID	59
`define ICTE_RECENT_USED 58
`define ICTE_TAG	57:32
`define ICTE_DATA	31:0

/* ------ D-Cache ---------*/
`define DCTE_WIDTH 	64
`define DCTE_VALID	63
`define DCTE_RECENT_USED 62
`define DCTE_DIRTY	61:58
`define DCTE_TAG	57:32
`define DCTE_DATA	31:0
`define HIT_0		2'd0
`define HIT_1		2'd1
`define MISS 		2'd2

/*-------------------------- TLB & Page Table-------------------------*/
`define TLBE_NUM		32
`define TLBE_WIDTH		39
`define TLBE_VALID		38
`define TLBE_AUTH		37:35
`define TLBE_X			37
`define TLBE_W			36
`define TLBE_R			35
`define TLBE_VPN_TAG	34:20
`define TLBE_PPN1		19:10
`define TLBE_PPN0		9:0
`define VPN_1			31:22
`define	VPN_0			21:12
`define PAGE_OFFSET 	11:0
`define PAGESIZE		4
`define PTE_PPN1		29:20
`define PTE_PPN0		19:10
`define PTE_AUTH		3:1
`define PTE_X			3
`define PTE_W			2
`define PTE_R			1
`define PTE_V			0

/*-------------------------- Branch Prediction -------------------------*/
`define Taken 1'b1
`define NotTaken 1'b0
`define BTBE_NUM 32
`define BTBE_WIDTH 58
`define BTBE_VALID 1'b1
`define BTBE_INVALID 1'b0

/*-------------------------- CSR reg addr -------------------------*/

/* ------ Machine trap setup ---------*/
`define  CSR_MSTATUS_ADDR         12'h300
`define  CSR_MIE_ADDR             12'h304
`define  CSR_MTVEC_ADDR           12'h305

/* ------ Machine trap handling ------*/
`define  CSR_MSCRATCH_ADDR        12'h340
`define  CSR_MEPC_ADDR            12'h341
`define  CSR_MCAUSE_ADDR          12'h342
`define  CSR_MTVAL_ADDR           12'h343
`define  CSR_MIP_ADDR             12'h344

`define  CSR_PMPCFG0_ADDR         12'h3A0
`define  CSR_PMPCFGADDR0_ADDR     12'h3B0

`define  CSR_SATP_ADDR            12'h180

`define  MTVEC_RESET              32'h00000001
`define  USER_MODE				  2'b00
`define  KERNEL_MODE			  2'b11
