///////////////////////////////////////////////
                                               //
wire        [31:0]       comp1              ;  //
wire        [31:0]       comp2              ;  //
wire        [31:0]       c1_mux_final       ;  //
wire        [31:0]       c2_mux_final       ;  //
reg         [31:0]       comp1_id_fb=0      ;  //
reg         [31:0]       comp2_id_fb=0      ;  //
reg         [31:0]       comp1_fb_ex=0      ;  //
reg         [31:0]       comp2_fb_ex=0      ;  //
wire                     branch_taken       ;  //
reg                      branch_taken_reg=0 ;  //
reg         [3:0]        bubble_counter  =0 ;  //
wire                     stall_enable       ;  //
reg                      stall_enable_id_fb=1'b1;//
reg                      stall_enable_fb_ex ;  //
reg [31:0]    imm_out_id_fb   =0            ;  //
reg [31:0]    imm_out_fb_ex   =0            ;  //
reg [31:0]    alu_ex_mem1_d      =0         ;  //
reg [2:0]     feed_back_muxa_sel_id_fb =0   ;  //
reg [2:0]     feed_back_muxb_sel_id_fb  =0  ;  //
reg [2:0]     feed_back_muxa_sel_fb_ex  =0  ;  //
reg [2:0]     feed_back_muxb_sel_fb_ex  =0  ;  //
reg           a_bus_sel_id_fb     =0        ;  //
reg           b_bus_sel_id_fb    =0         ;  //
reg           a_bus_sel_fb_ex    =0         ;  //
reg           b_bus_sel_fb_ex     =0        ;  //
///////////////////////////////////////////////

///////////////////////////////////////////////
                                             //
reg          [31:0]      pc_id_fb  =0       ;//
reg          [31:0]      pc_fb_ex   =0      ;//
                                             //
///////////////////////////////////////////////

///////////////////////////////////////////////
                                             //
wire        [31:0]       jump_bus1        ;  //
wire        [31:0]       jump_bus2        ;  //
wire        [31:0]       jmux1_final      ;  //
wire        [31:0]       jmux2_final      ;  //
reg         [31:0]       jump1_id_fb    =0  ;  //            
reg         [31:0]       jump2_id_fb  =0    ;  //
reg         [31:0]       jump1_fb_ex  =0    ;  //            
reg         [31:0]       jump2_fb_ex  =0    ;  //
                                             //
///////////////////////////////////////////////

/////////////////////////////////////////////////
                                               //
wire                    jump_w            ;    //
wire                    jumpr_w           ;    //
wire                    cbranch_w         ;    //
reg                     jump_id_fb     =0   ;    //
reg                     jumpr_id_fb    =0   ;    //
reg                     cbranch_id_fb    =0 ;    //
reg                     jump_fb_ex      =0  ;    //
reg                     jumpr_fb_ex     =0  ;    //
reg                     cbranch_fb_ex   =0  ;    //
                                               //
/////////////////////////////////////////////////


////////////////////////////////////////////////
wire [31:0]              a_bus            ;   //
wire [31:0]              a_bus_mux_final  ;   //
wire [31:0]              b_bus            ;   //
wire [31:0]              b_bus_mux_final  ;   //
reg  [31:0]              a_bus_id_fb   =0   ;   //
reg  [31:0]              b_bus_id_fb    =0  ;   //
reg  [31:0]              a_bus_fb_ex   =0   ;   //
reg  [31:0]              b_bus_fb_ex    =0  ;   //
                                              //
////////////////////////////////////////////////


/////////////////////////////////////////////////
                                               //
wire [31:0]             alu_out_wire       ;   //
reg  [31:0]             alu_ex_mem1      =0  ;   //
reg  [31:0]             alu_mem1_mem2    =0  ;   //
reg  [31:0]             alu_mem2_mem3    =0  ;   //
reg  [31:0]             alu_mem3_wb       =0 ;    //
reg  [31:0]             alu_ex_mem1_p   =0   ;   //
reg  [31:0]             alu_mem1_mem2_p =0   ;   //
reg  [31:0]             alu_mem2_mem3_p =0   ;   //
reg  [31:0]             alu_mem3_wb_p    =0  ;   //
                                               //
/////////////////////////////////////////////////

/////////////////////////////////////////////////
                                               //
wire [3:0]              alu_cnt             ;  //
wire [2:0]              fun3                ;  //
wire [3:0]              csr_cnt             ;  //
wire [4:0]              zimm                ;  //
reg  [3:0]              alu_cnt_id_fb  =0   ;  //
reg  [2:0]              fun3_id_fb     =0   ;  //
reg  [3:0]              csr_cnt_id_fb  =0   ;  //
reg  [4:0]              zimm_id_fb  =0      ;  //
reg  [3:0]              alu_cnt_fb_ex  =0   ;  //
reg  [2:0]              fun3_fb_ex =0       ;  //
reg  [3:0]              csr_cnt_fb_ex =0    ;  //
reg  [4:0]              zimm_fb_ex =0       ;  //
                                               //
/////////////////////////////////////////////////

/////////////////////////////////////////////////
                                               //
wire [1:0]              op_type           ;    //
reg  [1:0]              type_id_fb     =0   ;    //
reg  [1:0]              type_fb_ex      =0  ;    //
reg  [1:0]              type_ex_mem1    =0  ;    //
reg  [1:0]              type_mem1_mem2 =0   ;    //
reg  [1:0]              type_mem2_mem3  =0  ;    //
reg  [1:0]              type_mem3_wb    =0  ;    //
wire [4 :0]             rd_out            ;    //
reg  [4 :0]             rd_id_fb       =0   ;    //
reg  [4 :0]             rd_fb_ex      =0    ;    //
reg  [4 :0]             rd_ex_mem1    =0    ;    //
reg  [4 :0]             rd_mem1_mem2  =0    ;    //
reg  [4 :0]             rd_mem2_mem3   =0   ;    //
reg  [4 :0]             rd_mem3_wb     =0   ;    //
                                               //
/////////////////////////////////////////////////

/////////////////////////////////////////////////     
                                               //
wire [2:0]              feed_back_muxa_sel ;   //
wire [2:0]              feed_back_muxb_sel ;   //
                                               //
                                               //
/////////////////////////////////////////////////

/////////////////////////////////////////////////     
                                               //
wire [2:0]              mux_sel_wires   [0:5] ;//
wire [31:0]             mux_outputs     [0:5] ;//
wire [31:0]             mux_input_direct[0:5] ;//
                                               //
/////////////////////////////////////////////////

/////////////////////////////////////////////////     
                                               //
wire [31:0]            rs1_out          ;      //
wire [31:0]            rs2_out          ;      //
reg  [31:0]            rs1_id_fb =0     ;      //
reg  [31:0]            rs2_id_fb  =0    ;      //
reg  [31:0]            rs1_fb_ex  =0    ;      //
reg  [31:0]            rs2_fb_ex  =0    ;      //
wire [31:0]            rs1_final        ;      //
wire [31:0]            rs2_final        ;      //
wire                   a_bus_sel        ;      //
wire                   b_bus_sel        ;      //
wire [31:0]            imm_out          ;      //
                                               //
/////////////////////////////////////////////////

wire      [1:0]        data_cache_control_w;
reg       [1:0]        data_cache_control_id_fb=0;
