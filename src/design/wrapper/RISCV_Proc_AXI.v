`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/26/2017 04:39:18 PM
// Design Name: 
// Module Name: RISCV_Proc_AXI
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RISCV_Proc_AXI # (
        // Fixed parameters
        localparam ADDR_WIDTH           = 32,
        localparam DATA_WIDTH           = 32,
           
        // Primary parameters
        parameter S                     = 17,                    // Size of the cache will be 2^S bits
        parameter B                     = 9,                     // Size of a block will be 2^B bits
        parameter a                     = 1,                     // Associativity of the cache would be 2^a
        parameter T                     = 1,                     // Width to depth translation amount
        parameter W                     = 7,                     // Width of the L2-L1 bus would be 2^W
        parameter N                     = 3,                     // Number of stream buffers
        parameter n                     = 1,                     // Depth of stream buffers would be 2^n
        parameter p                     = 2,                     // Prefetch queue's depth is 2^p
        parameter V                     = 2,                     // Size of the victim cache will be 2^V cache lines
        parameter L2_DELAY_RD           = 7,                     // Delay of the second level of cache
        
        //AXI interface parameters
        parameter PROCESSOR_DATA_WIDTH          = 32,
        parameter C_M_TARGET_SLAVE_BASE_ADDR    = 32'h40000000,
        parameter C_M_AXI_BURST_LEN             = 4,
        parameter C_M_AXI_ID_WIDTH              = 1,
        parameter C_M_AXI_ADDR_WIDTH            = 32,
        parameter C_M_AXI_DATA_WIDTH            = 128,
        parameter C_M_AXI_AWUSER_WIDTH          = 0,
        parameter C_M_AXI_ARUSER_WIDTH          = 0,
        parameter C_M_AXI_WUSER_WIDTH           = 0,
        parameter C_M_AXI_RUSER_WIDTH           = 0,
        parameter C_M_AXI_BUSER_WIDTH           = 0,
        
        // Calculated parameters
        localparam L2_BUS_WIDTH         = 1 << W
    ) (
        input CLK,
        (* mark_debug *) output wire                                   EXT_FIFO_WR_ENB   ,
        (* mark_debug *) output wire [DATA_WIDTH              - 1 : 0] EXT_FIFO_WR_DATA  ,
                        
        // AXI interface for instruction cache
        (* mark_debug *) input  wire                                   P0_INIT_AXI_TXN   ,
        output wire                                   P0_TXN_DONE       ,
        output wire                                   P0_ERROR          ,
        input  wire                                   M0_AXI_ACLK       ,
        input  wire                                   M0_AXI_ARESETN    ,
        output wire [C_M_AXI_ID_WIDTH        - 1 : 0] M0_AXI_AWID       ,
        output wire [C_M_AXI_ADDR_WIDTH      - 1 : 0] M0_AXI_AWADDR     ,
        output wire [7                           : 0] M0_AXI_AWLEN      ,
        output wire [2                           : 0] M0_AXI_AWSIZE     ,
        output wire [1                           : 0] M0_AXI_AWBURST    ,
        output wire                                   M0_AXI_AWLOCK     ,
        output wire [3                           : 0] M0_AXI_AWCACHE    ,
        output wire [2                           : 0] M0_AXI_AWPROT     ,
        output wire [3                           : 0] M0_AXI_AWQOS      ,
        output wire [C_M_AXI_AWUSER_WIDTH    - 1 : 0] M0_AXI_AWUSER     ,
        output wire                                   M0_AXI_AWVALID    ,
        input  wire                                   M0_AXI_AWREADY    ,
        output wire [C_M_AXI_DATA_WIDTH      - 1 : 0] M0_AXI_WDATA      ,
        output wire [C_M_AXI_DATA_WIDTH / 8  - 1 : 0] M0_AXI_WSTRB      ,
        output wire                                   M0_AXI_WLAST      ,
        output wire [C_M_AXI_WUSER_WIDTH     - 1 : 0] M0_AXI_WUSER      ,
        output wire                                   M0_AXI_WVALID     ,
        input  wire                                   M0_AXI_WREADY     ,
        input  wire [C_M_AXI_ID_WIDTH        - 1 : 0] M0_AXI_BID        ,
        input  wire [1                           : 0] M0_AXI_BRESP      ,
        input  wire [C_M_AXI_BUSER_WIDTH     - 1 : 0] M0_AXI_BUSER      ,
        input  wire                                   M0_AXI_BVALID     ,
        output wire                                   M0_AXI_BREADY     ,
        output wire [C_M_AXI_ID_WIDTH        - 1 : 0] M0_AXI_ARID       ,
        output wire [C_M_AXI_ADDR_WIDTH      - 1 : 0] M0_AXI_ARADDR     ,
        output wire [7                           : 0] M0_AXI_ARLEN      ,
        output wire [2                           : 0] M0_AXI_ARSIZE     ,
        output wire [1                           : 0] M0_AXI_ARBURST    ,
        output wire                                   M0_AXI_ARLOCK     ,
        output wire [3                           : 0] M0_AXI_ARCACHE    ,
        output wire [2                           : 0] M0_AXI_ARPROT     ,
        output wire [3                           : 0] M0_AXI_ARQOS      ,
        output wire [C_M_AXI_ARUSER_WIDTH    - 1 : 0] M0_AXI_ARUSER     ,
        output wire                                   M0_AXI_ARVALID    ,
        input  wire                                   M0_AXI_ARREADY    ,
        input  wire [C_M_AXI_ID_WIDTH        - 1 : 0] M0_AXI_RID        ,
        input  wire [C_M_AXI_DATA_WIDTH      - 1 : 0] M0_AXI_RDATA      ,
        input  wire [1                           : 0] M0_AXI_RRESP      ,
        input  wire                                   M0_AXI_RLAST      ,
        input  wire [C_M_AXI_RUSER_WIDTH     - 1 : 0] M0_AXI_RUSER      ,
        input  wire                                   M0_AXI_RVALID     ,
        output wire                                   M0_AXI_RREADY     ,
        input wire                                    FIFO_FULL         ,   
        input  wire                                   P1_INIT_AXI_TXN   ,
        output wire                                   P1_TXN_DONE       ,
        output wire                                   P1_ERROR          ,
        input  wire                                   M1_AXI_ACLK       ,
        input  wire                                   M1_AXI_ARESETN    ,
        output wire [C_M_AXI_ID_WIDTH        - 1 : 0] M1_AXI_AWID       ,
        output wire [C_M_AXI_ADDR_WIDTH      - 1 : 0] M1_AXI_AWADDR     ,
        output wire [7                           : 0] M1_AXI_AWLEN      ,
        output wire [2                           : 0] M1_AXI_AWSIZE     ,
        output wire [1                           : 0] M1_AXI_AWBURST    ,
        output wire                                   M1_AXI_AWLOCK     ,
        output wire [3                           : 0] M1_AXI_AWCACHE    ,
        output wire [2                           : 0] M1_AXI_AWPROT     ,
        output wire [3                           : 0] M1_AXI_AWQOS      ,
        output wire [C_M_AXI_AWUSER_WIDTH    - 1 : 0] M1_AXI_AWUSER     ,
        output wire                                   M1_AXI_AWVALID    ,
        input  wire                                   M1_AXI_AWREADY    ,
        output wire [C_M_AXI_DATA_WIDTH      - 1 : 0] M1_AXI_WDATA      ,
        output wire [C_M_AXI_DATA_WIDTH / 8  - 1 : 0] M1_AXI_WSTRB      ,
        output wire                                   M1_AXI_WLAST      ,
        output wire [C_M_AXI_WUSER_WIDTH     - 1 : 0] M1_AXI_WUSER      ,
        output wire                                   M1_AXI_WVALID     ,
        input  wire                                   M1_AXI_WREADY     ,
        input  wire [C_M_AXI_ID_WIDTH        - 1 : 0] M1_AXI_BID        ,
        input  wire [1                           : 0] M1_AXI_BRESP      ,
        input  wire [C_M_AXI_BUSER_WIDTH     - 1 : 0] M1_AXI_BUSER      ,
        input  wire                                   M1_AXI_BVALID     ,
        output wire                                   M1_AXI_BREADY     ,
        output wire [C_M_AXI_ID_WIDTH        - 1 : 0] M1_AXI_ARID       ,
        output wire [C_M_AXI_ADDR_WIDTH      - 1 : 0] M1_AXI_ARADDR     ,
        output wire [7                           : 0] M1_AXI_ARLEN      ,
        output wire [2                           : 0] M1_AXI_ARSIZE     ,
        output wire [1                           : 0] M1_AXI_ARBURST    ,
        output wire                                   M1_AXI_ARLOCK     ,
        output wire [3                           : 0] M1_AXI_ARCACHE    ,
        output wire [2                           : 0] M1_AXI_ARPROT     ,
        output wire [3                           : 0] M1_AXI_ARQOS      ,
        output wire [C_M_AXI_ARUSER_WIDTH    - 1 : 0] M1_AXI_ARUSER     ,
        output wire                                   M1_AXI_ARVALID    ,
        input  wire                                   M1_AXI_ARREADY    ,
        input  wire [C_M_AXI_ID_WIDTH        - 1 : 0] M1_AXI_RID        ,
        input  wire [C_M_AXI_DATA_WIDTH      - 1 : 0] M1_AXI_RDATA      ,
        input  wire [1                           : 0] M1_AXI_RRESP      ,
        input  wire                                   M1_AXI_RLAST      ,
        input  wire [C_M_AXI_RUSER_WIDTH     - 1 : 0] M1_AXI_RUSER      ,
        input  wire                                   M1_AXI_RVALID     ,
        output wire                                   M1_AXI_RREADY      
    );
    
    wire                          RSTN = 1;
    
    wire                          ADDR_TO_L2_READY_INS;
    wire                          ADDR_TO_L2_VALID_INS;      
    wire [ADDR_WIDTH - 2 - 1 : 0] ADDR_TO_L2_INS;
    
    
    wire                          DATA_FROM_L2_VALID_INS;
    wire                          DATA_FROM_L2_READY_INS;
    wire [L2_BUS_WIDTH   - 1 : 0] DATA_FROM_L2_INS;
    
    wire                          WR_TO_L2_READY_DAT;
    wire                          WR_TO_L2_VALID_DAT;
    wire [ADDR_WIDTH - 2 - 1 : 0] WR_ADDR_TO_L2_DAT;
    wire [L2_BUS_WIDTH   - 1 : 0] DATA_TO_L2_DAT;
    wire                          WR_CONTROL_TO_L2_DAT;
    wire                          WR_COMPLETE_DAT;
    
    wire                          RD_ADDR_TO_L2_READY_DAT;
    wire                          RD_ADDR_TO_L2_VALID_DAT;
    wire [ADDR_WIDTH - 2 - 1 : 0] RD_ADDR_TO_L2_DAT;
    
    wire                          DATA_FROM_L2_VALID_DAT;
    wire                          DATA_FROM_L2_READY_DAT;
    wire [L2_BUS_WIDTH   - 1 : 0] DATA_FROM_L2_DAT;  

   
    
    MEMORY_INTERFACE # ( 
        .PROCESSOR_DATA_WIDTH       (PROCESSOR_DATA_WIDTH),
        .C_M_TARGET_SLAVE_BASE_ADDR (C_M_TARGET_SLAVE_BASE_ADDR),
        .C_M_AXI_BURST_LEN          (C_M_AXI_BURST_LEN         ),
        .C_M_AXI_ID_WIDTH           (C_M_AXI_ID_WIDTH          ),
        .C_M_AXI_ADDR_WIDTH         (C_M_AXI_ADDR_WIDTH        ),
        .C_M_AXI_DATA_WIDTH         (C_M_AXI_DATA_WIDTH        ),
        .C_M_AXI_AWUSER_WIDTH       (C_M_AXI_AWUSER_WIDTH      ),
        .C_M_AXI_ARUSER_WIDTH       (C_M_AXI_ARUSER_WIDTH      ),
        .C_M_AXI_WUSER_WIDTH        (C_M_AXI_WUSER_WIDTH       ),
        .C_M_AXI_RUSER_WIDTH        (C_M_AXI_RUSER_WIDTH       ),
        .C_M_AXI_BUSER_WIDTH        (C_M_AXI_BUSER_WIDTH       )
    ) ins_cache_interface (
        // AXI ports for memory
        .INIT_AXI_TXN       (P0_INIT_AXI_TXN ),
        .TXN_DONE           (P0_TXN_DONE     ),
        .ERROR              (P0_ERROR        ),
        .M_AXI_ACLK         (M0_AXI_ACLK     ),
        .M_AXI_ARESETN      (M0_AXI_ARESETN  ),
        .M_AXI_AWID         (M0_AXI_AWID     ),
        .M_AXI_AWADDR       (M0_AXI_AWADDR   ),
        .M_AXI_AWLEN        (M0_AXI_AWLEN    ),
        .M_AXI_AWSIZE       (M0_AXI_AWSIZE   ),
        .M_AXI_AWBURST      (M0_AXI_AWBURST  ),
        .M_AXI_AWLOCK       (M0_AXI_AWLOCK   ),
        .M_AXI_AWCACHE      (M0_AXI_AWCACHE  ),
        .M_AXI_AWPROT       (M0_AXI_AWPROT   ),
        .M_AXI_AWQOS        (M0_AXI_AWQOS    ),
        .M_AXI_AWUSER       (M0_AXI_AWUSER   ),
        .M_AXI_AWVALID      (M0_AXI_AWVALID  ),
        .M_AXI_AWREADY      (M0_AXI_AWREADY  ),
        .M_AXI_WDATA        (M0_AXI_WDATA    ),
        .M_AXI_WSTRB        (M0_AXI_WSTRB    ),
        .M_AXI_WLAST        (M0_AXI_WLAST    ),
        .M_AXI_WUSER        (M0_AXI_WUSER    ),
        .M_AXI_WVALID       (M0_AXI_WVALID   ),
        .M_AXI_WREADY       (M0_AXI_WREADY   ),
        .M_AXI_BID          (M0_AXI_BID      ),
        .M_AXI_BRESP        (M0_AXI_BRESP    ),
        .M_AXI_BUSER        (M0_AXI_BUSER    ),
        .M_AXI_BVALID       (M0_AXI_BVALID   ),
        .M_AXI_BREADY       (M0_AXI_BREADY   ),
        .M_AXI_ARID         (M0_AXI_ARID     ),
        .M_AXI_ARADDR       (M0_AXI_ARADDR   ),
        .M_AXI_ARLEN        (M0_AXI_ARLEN    ),
        .M_AXI_ARSIZE       (M0_AXI_ARSIZE   ),
        .M_AXI_ARBURST      (M0_AXI_ARBURST  ),
        .M_AXI_ARLOCK       (M0_AXI_ARLOCK   ),
        .M_AXI_ARCACHE      (M0_AXI_ARCACHE  ),
        .M_AXI_ARPROT       (M0_AXI_ARPROT   ),
        .M_AXI_ARQOS        (M0_AXI_ARQOS    ),
        .M_AXI_ARUSER       (M0_AXI_ARUSER   ),
        .M_AXI_ARVALID      (M0_AXI_ARVALID  ),
        .M_AXI_ARREADY      (M0_AXI_ARREADY  ),
        .M_AXI_RID          (M0_AXI_RID      ),
        .M_AXI_RDATA        (M0_AXI_RDATA    ),
        .M_AXI_RRESP        (M0_AXI_RRESP    ),
        .M_AXI_RLAST        (M0_AXI_RLAST    ),
        .M_AXI_RUSER        (M0_AXI_RUSER    ),
        .M_AXI_RVALID       (M0_AXI_RVALID   ),
        .M_AXI_RREADY       (M0_AXI_RREADY   ),
        // Cache side ports
        .dout_ra           (ADDR_TO_L2_INS),
        .valid_ra          (ADDR_TO_L2_VALID_INS),
        .ready_ra          (ADDR_TO_L2_READY_INS),
        .dout_wa           (30'd0),
        .valid_wc          (1'd0),
        .ready_wc          (),
        .dout_wd           (128'd0),
        .din_rd            (DATA_FROM_L2_INS  ),
        .ready_rd          (DATA_FROM_L2_READY_INS),
        .valid_rd          (DATA_FROM_L2_VALID_INS),
        .ack               ()
    );
    
    MEMORY_INTERFACE # ( 
        .PROCESSOR_DATA_WIDTH       (PROCESSOR_DATA_WIDTH),
        .C_M_TARGET_SLAVE_BASE_ADDR (C_M_TARGET_SLAVE_BASE_ADDR),
        .C_M_AXI_BURST_LEN          (C_M_AXI_BURST_LEN         ),
        .C_M_AXI_ID_WIDTH           (C_M_AXI_ID_WIDTH          ),
        .C_M_AXI_ADDR_WIDTH         (C_M_AXI_ADDR_WIDTH        ),
        .C_M_AXI_DATA_WIDTH         (C_M_AXI_DATA_WIDTH        ),
        .C_M_AXI_AWUSER_WIDTH       (C_M_AXI_AWUSER_WIDTH      ),
        .C_M_AXI_ARUSER_WIDTH       (C_M_AXI_ARUSER_WIDTH      ),
        .C_M_AXI_WUSER_WIDTH        (C_M_AXI_WUSER_WIDTH       ),
        .C_M_AXI_RUSER_WIDTH        (C_M_AXI_RUSER_WIDTH       ),
        .C_M_AXI_BUSER_WIDTH        (C_M_AXI_BUSER_WIDTH       )
    ) data_cache_interface (
        // AXI ports for memory
        .INIT_AXI_TXN       (P1_INIT_AXI_TXN ),
        .TXN_DONE           (P1_TXN_DONE     ),
        .ERROR              (P1_ERROR        ),
        .M_AXI_ACLK         (M1_AXI_ACLK     ),
        .M_AXI_ARESETN      (M1_AXI_ARESETN  ),
        .M_AXI_AWID         (M1_AXI_AWID     ),
        .M_AXI_AWADDR       (M1_AXI_AWADDR   ),
        .M_AXI_AWLEN        (M1_AXI_AWLEN    ),
        .M_AXI_AWSIZE       (M1_AXI_AWSIZE   ),
        .M_AXI_AWBURST      (M1_AXI_AWBURST  ),
        .M_AXI_AWLOCK       (M1_AXI_AWLOCK   ),
        .M_AXI_AWCACHE      (M1_AXI_AWCACHE  ),
        .M_AXI_AWPROT       (M1_AXI_AWPROT   ),
        .M_AXI_AWQOS        (M1_AXI_AWQOS    ),
        .M_AXI_AWUSER       (M1_AXI_AWUSER   ),
        .M_AXI_AWVALID      (M1_AXI_AWVALID  ),
        .M_AXI_AWREADY      (M1_AXI_AWREADY  ),
        .M_AXI_WDATA        (M1_AXI_WDATA    ),
        .M_AXI_WSTRB        (M1_AXI_WSTRB    ),
        .M_AXI_WLAST        (M1_AXI_WLAST    ),
        .M_AXI_WUSER        (M1_AXI_WUSER    ),
        .M_AXI_WVALID       (M1_AXI_WVALID   ),
        .M_AXI_WREADY       (M1_AXI_WREADY   ),
        .M_AXI_BID          (M1_AXI_BID      ),
        .M_AXI_BRESP        (M1_AXI_BRESP    ),
        .M_AXI_BUSER        (M1_AXI_BUSER    ),
        .M_AXI_BVALID       (M1_AXI_BVALID   ),
        .M_AXI_BREADY       (M1_AXI_BREADY   ),
        .M_AXI_ARID         (M1_AXI_ARID     ),
        .M_AXI_ARADDR       (M1_AXI_ARADDR   ),
        .M_AXI_ARLEN        (M1_AXI_ARLEN    ),
        .M_AXI_ARSIZE       (M1_AXI_ARSIZE   ),
        .M_AXI_ARBURST      (M1_AXI_ARBURST  ),
        .M_AXI_ARLOCK       (M1_AXI_ARLOCK   ),
        .M_AXI_ARCACHE      (M1_AXI_ARCACHE  ),
        .M_AXI_ARPROT       (M1_AXI_ARPROT   ),
        .M_AXI_ARQOS        (M1_AXI_ARQOS    ),
        .M_AXI_ARUSER       (M1_AXI_ARUSER   ),
        .M_AXI_ARVALID      (M1_AXI_ARVALID  ),
        .M_AXI_ARREADY      (M1_AXI_ARREADY  ),
        .M_AXI_RID          (M1_AXI_RID      ),
        .M_AXI_RDATA        (M1_AXI_RDATA    ),
        .M_AXI_RRESP        (M1_AXI_RRESP    ),
        .M_AXI_RLAST        (M1_AXI_RLAST    ),
        .M_AXI_RUSER        (M1_AXI_RUSER    ),
        .M_AXI_RVALID       (M1_AXI_RVALID   ),
        .M_AXI_RREADY       (M1_AXI_RREADY   ),
        // Cache side ports
        .dout_ra           (RD_ADDR_TO_L2_DAT ),
        .valid_ra          (RD_ADDR_TO_L2_VALID_DAT),
        .ready_ra          (RD_ADDR_TO_L2_READY_DAT),
        .dout_wa           (WR_ADDR_TO_L2_DAT ),
        .valid_wc          (WR_TO_L2_VALID_DAT),
        .ready_wc          (WR_TO_L2_READY_DAT),
        .dout_wd           (DATA_TO_L2_DAT ),
        .din_rd            (DATA_FROM_L2_DAT  ),
        .ready_rd          (DATA_FROM_L2_READY_DAT),
        .valid_rd          (DATA_FROM_L2_VALID_DAT),
        .ack               (WR_COMPLETE_DAT     )
    );
     RISCV_PROCESSOR # (
           .S          (S),                               // Size of the cache will be 2^S bits
           .B          (B),                               // Size of a block will be 2^B bits
           .a          (a),                               // Associativity of the cache would be 2^a
           .T          (T),                               // Width to depth translation amount
           .W          (W),                               // Width of the L2-L1 bus would be 2^W
           .N          (N),                               // Number of stream buffers
           .n          (n),                               // Depth of stream buffers would be 2^n
           .p          (p),                               // Prefetch queue's depth is 2^p
           .V          (V),                               // Size of the victim cache will be 2^V cache lines
           .L2_DELAY_RD(L2_DELAY_RD)                      // Delay of the second level of cache    
       ) riscv_proc (
           .CLK                    (CLK                    ),
           .RSTN                   (RSTN                   ),
           // Instruction cache    
           .ADDR_TO_L2_READY_INS   (ADDR_TO_L2_READY_INS   ),
           .ADDR_TO_L2_VALID_INS   (ADDR_TO_L2_VALID_INS   ),      
           .ADDR_TO_L2_INS         (ADDR_TO_L2_INS         ),
           .DATA_FROM_L2_VALID_INS (DATA_FROM_L2_VALID_INS ),
           .DATA_FROM_L2_READY_INS (DATA_FROM_L2_READY_INS ),
           .DATA_FROM_L2_INS       (DATA_FROM_L2_INS       ),
           // Data cache          
           .WR_TO_L2_READY_DAT     (WR_TO_L2_READY_DAT     ),
           .WR_TO_L2_VALID_DAT     (WR_TO_L2_VALID_DAT     ),
           .WR_ADDR_TO_L2_DAT      (WR_ADDR_TO_L2_DAT      ),
           .DATA_TO_L2_DAT         (DATA_TO_L2_DAT         ),
           .WR_CONTROL_TO_L2_DAT   (WR_CONTROL_TO_L2_DAT   ),
           .WR_COMPLETE_DAT        (WR_COMPLETE_DAT        ),
           .RD_ADDR_TO_L2_READY_DAT(RD_ADDR_TO_L2_READY_DAT),
           .RD_ADDR_TO_L2_VALID_DAT(RD_ADDR_TO_L2_VALID_DAT),
           .RD_ADDR_TO_L2_DAT      (RD_ADDR_TO_L2_DAT      ),
           .DATA_FROM_L2_VALID_DAT (DATA_FROM_L2_VALID_DAT ),
           .DATA_FROM_L2_READY_DAT (DATA_FROM_L2_READY_DAT ),
           .DATA_FROM_L2_DAT       (DATA_FROM_L2_DAT       ),
           .EXT_FIFO_WR_ENB        (EXT_FIFO_WR_ENB        ),
           .EXT_FIFO_WR_DATA       (EXT_FIFO_WR_DATA       )
           //.P0_INIT_AXI_TXN        (!FIFO_FULL)   
           
       );
  
endmodule
