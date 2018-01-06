`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:     09/02/2017 02:47:55 PM
// Design Name: 
// Module Name:     CSR_FILE
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


module CSR_FILE (
        input               CLK             ,
        input       [31:0]  PC              ,
        input       [ 3:0]  CSR_CNT         ,
        input       [11:0]  CSR_ADDRESS     ,
        input       [31:0]  WRITE_DATA      ,
        input               CSR_ENABLE      ,
        input       [ 2:0]  CSR_OP_TYPE     ,
        input               MEIP            ,
        input               MTIP            , 
        input               MSIP            , 
        input               TRAP            ,
        output              TRAP_FINAL      ,
        input       [30:0]  E_CODE_C        ,
        input       [31:0]  TVAL            ,
        input               TRAP_RETURN     ,
        output reg          TSR             ,
        output reg          TVM             ,
        output reg          TW              ,
        output reg  [31:0]  R_DATA          ,
        output reg  [31:0]  HANDLER_PC      ,          
        output reg  [31:0]  EPC             ,
        output      [ 1:0]  PREV        
    );  
    
    `include "PipelineParams.vh"
    
    reg     heip,seip,ueip,htip,stip,utip,hsip,ssip,usip                ;
    reg     meie,heie,seie,ueie,mtie,htie,stie,utie,msie,hsie,ssie,usie ;
    reg     sd,mxr,sum,mprv,spp,mpie,spie,upie,m_ie,s_ie,u_ie           ;
    reg     [1      :0]     mpp                                         ;
    reg     [29     :0]     mt_base       =0                            ;
    reg     [1      :0]     mt_mode       =0                            ;
    reg     [31     :0]     medeleg_reg   =0                            ;
    reg     [31     :0]     mideleg_reg   =0                            ;
    reg     [63     :0]     mcycle_reg    =0                            ;
    reg     [63     :0]     minsret_reg   =0                            ;
    reg                     mir,mtm,mcy   =0                            ;
    reg     [31     :0]     mscratch_reg  =0                            ;
    reg     [31     :0]     mepc_reg      =0                            ;
    reg     [31     :0]     mtval_reg     =0                            ;
    reg     [30     :0]     mecode_reg    =0                            ;
    reg                     minterrupt    =0                            ;
    
    //supervisor specific
    reg     [29     :0]     st_base       =0                            ;
    reg     [1      :0]     st_mode       =0                            ;
    reg     [31     :0]     sedeleg_reg   =0                            ;
    reg     [31     :0]     sideleg_reg   =0                            ;
    reg     [63     :0]     sinsret_reg   =0                            ;
    reg                     sir,stm,scy   =0                            ;
    reg     [31     :0]     sscratch_reg  =0                            ;
    reg     [31     :0]     sepc_reg      =0                            ;
    reg     [31     :0]     stval_reg     =0                            ;
    reg     [30     :0]     secode_reg    =0                            ;
    reg                     sinterrupt    =0                            ;
    reg                     smode_reg     =0                            ;
    reg     [8      :0]     asid          =0                            ;
    reg     [21     :0]     ppn           =0                            ;
    
    // user mode specific
    reg     [29     :0]     ut_base       =0                            ;
    reg     [1      :0]     ut_mode       =0                            ;
    reg     [63     :0]     ucycle_reg    =0                            ;
    reg     [63     :0]     uinsret_reg   =0                            ;
    reg     [31     :0]     uscratch_reg  =0                            ;
    reg     [31     :0]     uepc_reg      =0                            ;
    reg     [31     :0]     utval_reg     =0                            ;
    reg     [30     :0]     uecode_reg    =0                            ;
    reg                     uinterrupt    =0                            ;
    reg                     umode_reg     =0                            ;
    reg     [63     :0]     cycle_reg     =0                            ; 
    reg     [63     :0]     timer_reg     =0                            ; 
    reg     [63     :0]     instret_reg   =0                            ; 
  
    initial
    begin
        TSR         =0          ;
        TVM         =0          ;
        TW          =0          ;
        R_DATA      =0          ;
        HANDLER_PC  =0          ;        
            
        {sd,mxr,sum,mprv,mpp,spp,mpie,spie,upie,m_ie,s_ie,u_ie}           = 13'b011000011101        ;
        {heip,seip,ueip,htip,stip,utip,hsip,ssip,usip}                    = 9'd0                    ;
        {meie,heie,seie,ueie,mtie,htie,stie,utie,msie,hsie,ssie,usie}     = 12'd0                   ;
    end
   
    // machine mode registers
    wire    [31 : 0] mip_r       = { 20'b0,MEIP,1'b0,seip,ueip,MTIP,1'b0,stip,utip,MSIP,1'b0,ssip,usip};  //hardwired 0 for hypervisor specs
    wire    [31 : 0] mie_r       = { 20'b0,meie,1'b0,seie,ueie,mtie,1'b0,stie,utie,msie,1'b0,ssie,usie};  
    wire    [31 : 0] mstatus_r   = {sd,8'b0,TSR,TW,TVM,mxr,sum,mprv,4'b0,mpp,2'b0,spp,mpie,1'b0,spie,upie,m_ie,1'b0,s_ie,u_ie};
    wire    [31 : 0] mtvec_r     = {mt_base,mt_mode};
    wire    [31 : 0] medeleg_r   = medeleg_reg;
    wire    [31 : 0] mideleg_r   = mideleg_reg;
    wire    [31 : 0] mscratch_r  = mscratch_reg;
    wire    [31 : 0] mepc_r      = mepc_reg;
    wire    [31 : 0] mcycle_r    = cycle_reg [31 :  0];
    wire    [31 : 0] mcycleh_r   = cycle_reg [63 : 32];
    wire    [31 : 0] mcounteren_r= {29'b0,mir,mtm,mcy};
    wire    [31 : 0] mcause_r    = {minterrupt,mecode_reg};
    wire    [31 : 0] mtval_r     = mtval_reg;
    wire    [31 : 0] minstret_r  = instret_reg [31 :  0];
    wire    [31 : 0] minstreth_r = instret_reg [63 : 32];
    wire    [31 : 0] mvendorid_r = 32'd0                 ;
    wire    [31 : 0] mhartid_r   = 32'd0                 ;
    wire    [31 : 0] marchid_r   = 32'd0                 ;
    wire    [31 : 0] mimpid_r    = 32'd0                 ;
    wire    [31 : 0] misa_r      = 32'b01000000000000000001000100000000;    
        
    // supervisor mode registers
    wire    [31 : 0] sstatus_r   = {sd,11'b0,mxr,sum,9'b0,spp,2'b0,spie,upie,2'b0,s_ie,u_ie};
    wire    [31 : 0] stvec_r     = {st_base,st_mode};
    wire    [31 : 0] sip_r       = { 22'b0,seip,ueip,2'b0,stip,utip,2'b0,ssip,usip};  //hardwired 0 for hypervisor specs
    wire    [31 : 0] sie_r       = { 22'b0,seie,ueie,2'b0,stie,utie,2'b0,ssie,usie};  
    wire    [31 : 0] sedeleg_r   = sedeleg_reg;
    wire    [31 : 0] sideleg_r   = sideleg_reg;
    wire    [31 : 0] sscratch_r  = sscratch_reg;
    wire    [31 : 0] sepc_r      = sepc_reg;
    wire    [31 : 0] scounteren_r= {29'b0,sir,stm,scy};
    wire    [31 : 0] scause_r    = {sinterrupt,secode_reg};
    wire    [31 : 0] stval_r     = stval_reg;
    wire    [31 : 0] satp_r      = {smode_reg,asid,ppn};
   
    // user mode registers 
    wire    [31 : 0] ustatus_r   = {27'b0,upie,3'b0,u_ie};
    wire    [31 : 0] utvec_r     = {ut_base,ut_mode};
    wire    [31 : 0] uip_r       = { 23'b0,ueip,3'b0,utip,3'b0,usip};  //hardwired 0 for hypervisor specs
    wire    [31 : 0] uie_r       = { 23'b0,ueie,3'b0,utie,3'b0,usie}; 
    wire    [31 : 0] uscratch_r  = uscratch_reg;
    wire    [31 : 0] uepc_r      = uepc_reg;
    wire    [31 : 0] ucause_r    = {uinterrupt,uecode_reg};
    wire    [31 : 0] utval_r     = utval_reg;
    wire    [31 : 0] cycle_r     = cycle_reg [31 :  0];
    wire    [31 : 0] cycleh_r    = cycle_reg [63 : 32];
    wire    [31 : 0] timer_r     = timer_reg [31 :  0];
    wire    [31 : 0] timerh_r    = timer_reg [63 : 32];
    wire    [31 : 0] instret_r   = instret_reg [31 :  0];
    wire    [31 : 0] instreth_r  = instret_reg [63 : 32];
    
    reg     [1  : 0] curr_prev             = 2'b11                         ;
    
    wire             ie          = curr_prev == 2'b11 ? m_ie: (curr_prev == 2'b01 ? s_ie & m_ie :( curr_prev ==2'b00 ? u_ie:1'b0));
    reg              interrupt;

    reg            illegal_access        =  1'b0                         ;
    reg   [31 :0]    write_data_final      =  32'b0                        ;
    reg   [30:0]   e_code                =  29'b0                        ;
    
    wire exception =   ( illegal_access  )|TRAP                 ;
    wire trap      =    exception | interrupt               ;
   
    //read_    assign prev=curr_prev;data
    assign PREV=curr_prev;
        
    assign TRAP_FINAL =trap;
    
    always @(*)
    begin
//        e_code=30'd0;

//        if(MEIP&meie)
//        begin
//            e_code=30'd11;
//        end
//        else if (MSIP&msie)
//        begin
//           e_code=30'd3;
//        end
//        else if (MTIP&mtie)
//        begin
//           e_code=29'd7;
//        end
//        else if(seip&seie)
//        begin
//            e_code=29'd9;
//        end
//        else if (ssip&msie)
//        begin
//           e_code=29'd1;
//        end
//        else if (stip&stie)
//        begin
//           e_code=29'd5;
//        end
//        else if(ueip&meie)
//        begin
//            e_code=29'd8;
//        end
//        else if (usip&msie)
//        begin
//           e_code=29'd0;
//        end
//        else if (utip&mtie)
//        begin
//           e_code=29'd4;
//        end
//        else if (illegal_access)
//        begin
//           e_code= 29'd2;
//        end
//        else if (TRAP)
//        begin
//           e_code=E_CODE_C;
//        end
//        case (curr_prev)
//           2'b11: HANDLER_PC  = {mt_base,2'b00};//+// ({32{mt_mode[0]}}& {1'b0,e_code} & {32{interrupt}});
//           2'b10: HANDLER_PC  = {mt_base,2'b00};//+ ({32{mt_mode[0]}}& {1'b0,e_code } & {32{interrupt}});
//           2'b01: HANDLER_PC  = {st_base,2'b00};//+ {32{st_mode[0]}}& {1'b0,e_code } & {32{interrupt}};
//           2'b00: HANDLER_PC  = {ut_base,2'b00};//+ {32{ut_mode[0]}}& {1'b0,e_code} & {32{interrupt}};
//        endcase
//         case (curr_prev)
//              2'b11: EPC  = mepc_r          ;
//              2'b10: EPC  = mepc_r          ;
//              2'b01: EPC  = sepc_r          ;
//              2'b00: EPC  = uepc_r          ;          
//         endcase
          illegal_access  =
                          ((curr_prev < CSR_ADDRESS[9:8])& CSR_ENABLE);//||ill8); //|
                       //  (CSR_ADDRESS[11:9]==2'b11 && );
//                         ((TVM==1)           &&  CSR_ADDRESS  ==  satp                                         )|
//                         ((curr_prev<=2'b01) && (((CSR_ADDRESS == instret)|(CSR_ADDRESS == instreth))&&(mir==0))) |
//                         ((curr_prev<=2'b01) && (((CSR_ADDRESS == timer)  |(CSR_ADDRESS == timeh)  ) &&(mtm==0))) |
//                         ((curr_prev<=2'b01) && (((CSR_ADDRESS == cycle)  |(CSR_ADDRESS == cycleh) ) &&(mcy==0))) |
//                         ((curr_prev==2'b00) && (((CSR_ADDRESS == instret)|(CSR_ADDRESS == instreth))&&(sir==0))) |
//                         ((curr_prev==2'b00) && (((CSR_ADDRESS == timer)  |(CSR_ADDRESS == timeh))   &&(stm==0))) |
//                         ((curr_prev==2'b00) && (((CSR_ADDRESS == cycle)  |(CSR_ADDRESS == cycleh))  &&(scy==0))));
        
        case (CSR_OP_TYPE)
            csrrw    :    write_data_final =  WRITE_DATA         ;    
            csrrs    :    write_data_final =  WRITE_DATA  | R_DATA;   
            csrrc    :    write_data_final = ~WRITE_DATA  & R_DATA;         
            csrrwi   :    write_data_final =  WRITE_DATA          ;    
            csrrsi   :    write_data_final =  WRITE_DATA  | R_DATA;   
            csrrci   :    write_data_final = ~WRITE_DATA  & R_DATA;         
            default  :    write_data_final =  WRITE_DATA          ; 
        endcase
        
        case (CSR_ADDRESS )
             ustatus	    :	 R_DATA =  ustatus_r	 ;
             uie            :    R_DATA =  uie_r         ;
             utvec          :    R_DATA =  utvec_r       ;
             uscratch       :    R_DATA =  uscratch_r    ;
             uepc           :    R_DATA =  uepc_r        ;
             ucause         :    R_DATA =  ucause_r      ;
             utval          :    R_DATA =  utval_r       ;
             uip            :    R_DATA =  uip_r         ;
 /*          fflags         :    R_DATA =  fflags_r      ;
             frm            :    R_DATA =  frm_r         ;
             fcsr           :    R_DATA =  fcsr_r        ;     */
             cycle          :    R_DATA =  cycle_r       ;
             timer          :    R_DATA =  timer_r       ;
             instret        :    R_DATA =  instret_r     ;
 /*          hpmcounter3    :    R_DATA =  hpmcounter3_r ;
             hpmcounter4    :    R_DATA =  hpmcounter4_r ;
             hpmcounter31   :    R_DATA =  hpmcounter31_r;  */
             cycleh         :    R_DATA =  cycleh_r      ;
             timeh          :    R_DATA =  timerh_r      ;
             instreth       :    R_DATA =  instreth_r    ;
/*           hpmcounter3h   :    R_DATA =  hpmcounter3h_r;
             hpmcounter4h   :    R_DATA =  hpmcounter4h_r;
             hpmcounter31h  :    R_DATA =  hpmcounter31h_r; */
             sstatus        :    R_DATA =  sstatus_r     ;
             sedeleg        :    R_DATA =  sedeleg_r     ;
             sideleg        :    R_DATA =  sideleg_r     ;
             sie            :    R_DATA =  sie_r         ;
             stvec          :    R_DATA =  stvec_r       ;
             scounteren     :    R_DATA =  scounteren_r  ;
             sscratch       :    R_DATA =  sscratch_r    ;
             sepc           :    R_DATA =  sepc_r        ;
             scause         :    R_DATA =  scause_r      ;
             stval          :    R_DATA =  stval_r       ;
             sip            :    R_DATA =  sip_r         ;
             satp           :    R_DATA =  satp_r        ;
             mvendorid      :    R_DATA =  mvendorid_r   ;
             marchid        :    R_DATA =  marchid_r     ;
             mimpid         :    R_DATA =  mimpid_r      ;
             mhartid        :    R_DATA =  mhartid_r     ;
             mstatus        :    R_DATA =  mstatus_r     ;
             misa           :    R_DATA =  misa_r        ;
             medeleg        :    R_DATA =  medeleg_r     ;
             mideleg        :    R_DATA =  mideleg_r     ;
             mie            :    R_DATA =  mie_r         ;
             mtvec          :    R_DATA =  mtvec_r       ;
             mcounteren     :    R_DATA =  mcounteren_r  ;
             mscratch       :    R_DATA =  mscratch_r    ;
             mepc           :    R_DATA =  mepc_r        ;
             mcause         :    R_DATA =  mcause_r      ;
             mtval          :    R_DATA =  mtval_r       ;
             mip            :    R_DATA =  mip_r         ;
/*           pmpcfg0        :    R_DATA =  pmpcfg0_r     ;
             pmpcfg1        :    R_DATA =  pmpcfg1_r     ;
             pmpcfg2        :    R_DATA =  pmpcfg2_r     ;
             pmpcfg3        :    R_DATA =  pmpcfg3_r     ;
             pmpaddr0       :    R_DATA =  pmpaddr0_r    ;
             pmpaddr1       :    R_DATA =  pmpaddr1_r    ;
             pmpaddr15      :    R_DATA =  pmpaddr15_r   ;  */
             mcycle         :    R_DATA =  mcycle_r      ;
             minstret       :    R_DATA =  minstret_r    ;
/*           mhpmcounter3   :    R_DATA =  mhpmcounter3_r;
             mhpmcounter4   :    R_DATA =  mhpmcounter4_r;
             mhpmcounter31  :    R_DATA =  mhpmcounter31_r; */
             mcycleh        :    R_DATA =  mcycleh_r     ;
             minstreth      :    R_DATA =  minstreth_r   ;
/*           mhpmcounter3h  :    R_DATA =  mhpmcounter3h_r;
             mhpmcounter4h  :    R_DATA =  mhpmcounter4h_r;
             mhpmcounter31h :    R_DATA =  mhpmcounter31h_r;
             mhpmevent3     :    R_DATA =  mhpmevent3_r   ;
             mhpmevent4     :    R_DATA =  mhpmevent4_r   ;
             mhpmevent31    :    R_DATA =  mhpmevent31_r  ;
             tselect        :    R_DATA =  tselect_r      ;
             tdata1         :    R_DATA =  tdata1_r       ;
             tdata2         :    R_DATA =  tdata2_r       ;
             tdata3         :    R_DATA =  tdata3_r       ;
             dcsr           :    R_DATA =  dcsr_r         ;
             dpc            :    R_DATA =  dpc_r          ;
             dscratch       :    R_DATA =  dscratch_r     ;  */
             default        :    begin
                                     illegal_access =      CSR_ENABLE;
                                     
                                     R_DATA         =    32'b0;
                                 end
        endcase
    end
    
    reg trap_return_flag=0;
    // writing to the CSRs
    
    always@(posedge CLK)
    begin
//        cycle_reg <=cycle_reg+1'b1;
        interrupt <=    |(mip_r  & mie_r & { 20'b0,ie,1'b0,ie,ie,ie,1'b0,ie,ie,ie,1'b0,ie,ie} )            ;
        trap_return_flag<=1'b0;
        if (CSR_ENABLE && !trap)
        begin
            case (CSR_ADDRESS)
                ustatus	       :	{upie,u_ie}        <= {
                                                           write_data_final[4]      ,
                                                           write_data_final[0]
                                                           }                        ;
                uie            :    {ueie,utie,usie}   <= {
                                                           write_data_final[8]      ,
                                                           write_data_final[4]      ,
                                                           write_data_final[0]
                                                           }                        ;
                utvec          :    {ut_base,ut_mode}  <=  write_data_final         ;   
                uscratch       :    uscratch_reg       <=  write_data_final         ;
                uepc           :    uepc_reg           <=  write_data_final         ;
                ucause         :    {uinterrupt,
                                           uecode_reg} <=  write_data_final         ;
                utval          :    utval_reg          <=  write_data_final         ;
                uip            :    {ueip,utip,usip}   <=  {
                                                           write_data_final[8]      ,
                                                           write_data_final[4]      ,
                                                           write_data_final[0]
                                                           }                        ;
                cycle          :    cycle_reg [31 : 0] <=  write_data_final         ;
                timer          :    timer_reg [31 : 0] <=  write_data_final         ;
                instret        :    instret_reg[31 :0] <=  write_data_final         ;
                cycleh         :    cycle_reg [63 : 32]<=  write_data_final         ;
                timeh          :    timer_reg [63 : 32]<=  write_data_final         ;
                instreth       :    instret_reg[63:32] <=  write_data_final         ;
                sstatus        :    {mxr,sum,spp,spie,
                                    upie,s_ie,u_ie}    <=  {
                                                           write_data_final[19:18]  ,
                                                           write_data_final[8]      ,
                                                           write_data_final[5:4]    ,
                                                           write_data_final[1:0]
                                                           }                        ;
                sedeleg        :    sedeleg_reg       <=  write_data_final          ;
                sideleg        :    sideleg_reg       <=  write_data_final          ;
                sie            :    {seie,ueie,stie,
                                    utie,ssie,usie}   <= {
                                                          write_data_final[9:8]     ,
                                                          write_data_final[5:4]     ,
                                                          write_data_final[1:0]
                                                         }                          ;
                stvec          :    {st_base,st_mode} <=  write_data_final          ;
                scounteren     :    {sir,stm,scy}     <=  write_data_final[2:0]     ;
                sscratch       :    sscratch_reg      <=  write_data_final          ;
                sepc           :    sepc_reg          <=  write_data_final          ;
                scause         :    {sinterrupt,
                                     secode_reg}      <=  write_data_final          ;
                stval          :    stval_reg         <=  write_data_final          ;
                sip            :    {seip,ueip,stip,
                                     utip,ssip,usip}  <=  {
                                                          write_data_final[9:8]     ,
                                                          write_data_final[5:4]     ,
                                                          write_data_final[1:0]
                                                          }                         ;
                satp           :    {smode_reg,
                                     asid,ppn}        <=  write_data_final          ;
                mstatus        :    {sd,TSR,TW,TVM,
                                    mxr,sum,mprv,mpp,
                                    spp,mpie,spie,
                                    upie,m_ie,
                                    s_ie,u_ie}        <=  {
                                                          write_data_final[31]       ,
                                                          write_data_final[22:17]    ,
                                                          write_data_final[12:11]    ,
                                                          write_data_final[8:7]      ,
                                                          write_data_final[5:3]      ,
                                                          write_data_final[1:0]
                                                          }                          ;
                medeleg        :    medeleg_reg       <=  write_data_final           ;
                mideleg        :    mideleg_reg       <=  write_data_final           ;
                mie            :    {meie,seie,ueie,
                                    mtie,stie,utie,
                                    msie,ssie,usie}   <=  {
                                                          write_data_final[11]       ,
                                                          write_data_final[9:7]      ,
                                                          write_data_final[5:3]      ,
                                                          write_data_final[1:0]
                                                          }                          ;
                mtvec          :    {mt_base,mt_mode} <=  write_data_final           ;
                mcounteren     :    {mir,mtm,mcy}     <=  write_data_final[2:0]      ;
                mscratch       :    mscratch_reg      <=  write_data_final           ;
                mepc           :    mepc_reg          <=  write_data_final           ;
                mcause         :    {minterrupt,
                                    mecode_reg}       <=  write_data_final           ;
                mtval          :    mtval_reg         <=  write_data_final           ;
                mip            :    {seip,ueip,stip,
                                    utip,ssip,usip}   <=  {
                                                          write_data_final[9:8]      ,
                                                          write_data_final[5:4]      ,
                                                          write_data_final[1:0]
                                                          }                          ;
                mcycle         :    cycle_reg [31 : 0] <=  write_data_final          ;
                minstret       :    instret_reg [31:0] <=  write_data_final          ;
                mcycleh        :    cycle_reg [63:32]  <=  write_data_final          ;
                minstreth      :    instret_reg[63:32] <=  write_data_final          ;   
            endcase
        end
        
//        else if (interrupt)
//        begin
//            case({mideleg_r [e_code]&!curr_prev[1],sideleg_r[e_code]&!curr_prev[0]} )
//                2'b00: 
//                begin
//                    curr_prev      <=   mmode                                           ;
         
//                    mecode_reg     <=   e_code                                   ;
//                    minterrupt     <=   1'b1                                     ;    
//                    mepc_reg       <=   PC                                       ;
//                    mpp            <=   curr_prev                                ;
//                    mpie           <=   m_ie                                     ;
//                    m_ie           <=   1'b0                                     ;
//                end
//                2'b01: 
//                begin
//                    curr_prev      <=   mmode                                     ;
                         
//                    mecode_reg     <=   e_code                                    ;
//                    minterrupt     <=   1'b1                                      ; 
//                    mepc_reg       <=   PC                                        ;
//                    mpp            <=   curr_prev                                ;
//                    mpie           <=   m_ie                                     ;
//                    m_ie           <=   1'b0                                     ;

//                end
            
//                2'b10: begin
                
//                    curr_prev      <=  smode                                      ;
  
//                    secode_reg     <=  e_code                                     ;
//                    sinterrupt     <=   1'b1                                      ;
//                    sepc_reg       <=  PC                                         ;
//                    spp            <=   curr_prev[0]                              ;
//                    spie           <=   s_ie                                      ;
//                    s_ie           <=   1'b0                                      ;
//                end     
//                2'b11:
//                begin
//                    curr_prev      <=  umode                                      ;
               
//                    uecode_reg     <=  e_code                                     ;
//                    uinterrupt     <=  1'b1                                       ;    
//                    uepc_reg       <=  PC                                         ;
//                    upie           <=  s_ie                                       ;
//                    u_ie           <=  1'b0                                       ;
//                end              
//            endcase
//        end
        
//        else if (exception)
//        begin
//            case({medeleg_r [e_code]&!curr_prev[1],sedeleg_r[e_code]&!curr_prev[0]} )
//                2'b00: 
//                begin
//                    curr_prev      <=   mmode                                    ;
                  
//                    mecode_reg     <=   e_code                                   ;
//                    minterrupt     <=   1'b0                                     ;
//                    if ((e_code <= 29'd1) | ((e_code >= 29'd4) & (e_code <= 29'd7)) | ((e_code >= 29'd12) & (e_code <= 29'd15)))
//                    begin 
//                         mtval_reg      <=   PC                                  ;
//                    end
//                    else
//                    begin
//                          mtval_reg      <= 32'd0                                 ;
//                    end     
//                    mepc_reg           <=   PC                                    ;
//                    mpp                <=   curr_prev                             ;
//                    mpie               <=   m_ie                                  ;
//                    m_ie               <=   1'b0                                  ;
                    
                
//                end
//                2'b01: 
//                begin
//                    curr_prev      <=   mmode                                     ;
//                    mecode_reg     <=   e_code                                    ;
//                    minterrupt     <=   1'b0                                      ;
//                    if ((e_code <= 29'd1) | ((e_code >= 29'd4) & (e_code <= 29'd7)) | ((e_code >= 29'd12) & (e_code <= 29'd15)))
//                    begin 
//                         mtval_reg     <=   PC                                   ;
//                    end
//                    else
//                    begin
//                          mtval_reg    <= 32'd0                                 ;
//                    end     
//                    mepc_reg           <=   PC                                    ;
//                    mpp                <=   curr_prev                             ;
//                    mpie               <=   m_ie                                  ;
//                    m_ie               <=   1'b0                                  ;
                
//                end
            
//                2'b10: begin
                
//                    curr_prev      <=  smode                                      ;
            
//                    secode_reg     <=  e_code                                     ;
//                    sinterrupt     <=   1'b0                                      ;
//                    if ((e_code <= 29'd1) | ((e_code >= 29'd4) & (e_code <= 29'd7)) | ((e_code >= 29'd12) & (e_code <= 29'd15)))
//                    begin 
//                         stval_reg      <= PC                                     ; 
//                    end
//                    else
//                    begin
//                         stval_reg      <= 32'd0                                  ;
//                    end
//                    sepc_reg           <=   PC                                    ;
//                    spp                <=   curr_prev[0]                          ;
//                    mpie               <=   m_ie                                  ;
//                    m_ie               <=   1'b0                                  ;

//                end     
//                2'b11:
//                begin
//                    curr_prev      <=  umode                                      ;
//                    uecode_reg     <=  e_code                                     ;
//                    uinterrupt     <=  1'b0                                       ;
//                    if ((e_code <= 29'd1) | ((e_code >= 29'd4) & (e_code <= 29'd7)) | ((e_code >= 29'd12) & (e_code <= 29'd15)))
//                    begin 
//                       utval_reg     <= PC                                        ;
//                    end
//                    else
//                    begin
//                       utval_reg     <= 32'd0                                     ;
//                    end     
//                    uepc_reg         <= PC                                        ;   
//                    upie             <= m_ie                                      ;
//                    u_ie             <= 1'b0                                      ;

//                end
                
                
                
//            endcase
//        end
//        else if (TRAP_RETURN)
//        begin
//            trap_return_flag<=1'b1;
//            if(!trap_return_flag)
//            begin
//            instret_reg <=instret_reg+1'b1;
//            end
            
//            case(curr_prev)
//            2'b11:
//                begin
//                    mpie             <= 1'b0                                      ;
//                    m_ie             <= mpie                                      ;                    
//                    curr_prev        <= mpp                                       ;                    
//                end
//            2'b01:
//                begin
//                    spie             <= 1'b1                                      ;
//                    s_ie             <= spie                                      ;                    
//                    curr_prev        <= {1'b0,spp  }                              ;                    
                
//                end
//            2'b00:
//                begin
//                    upie             <= 1'b1                                      ;
//                    u_ie             <= upie                                      ;                    
//                end
//            endcase
//        end
                                                                      
                        
                      
        end
    /*  hpmcounter3    :    R_DATA =  hpmcounter3_r ;
        hpmcounter4    :    R_DATA =  hpmcounter4_r ;
        hpmcounter31   :    R_DATA =  hpmcounter31_r;  
        hpmcounter3h   :    R_DATA =  hpmcounter3h_r;
        hpmcounter4h   :    R_DATA =  hpmcounter4h_r;
        hpmcounter31h  :    R_DATA =  hpmcounter31h_r; 
        pmpcfg0        :    R_DATA =  pmpcfg0_r     ;
        pmpcfg1        :    R_DATA =  pmpcfg1_r     ;
        pmpcfg2        :    R_DATA =  pmpcfg2_r     ;
        pmpcfg3        :    R_DATA =  pmpcfg3_r     ;
        pmpaddr0       :    R_DATA =  pmpaddr0_r    ;
        pmpaddr1       :    R_DATA =  pmpaddr1_r    
        pmpaddr15      :    R_DATA =  pmpaddr15_r   ;  
        mhpmcounter3   :    R_DATA =  mhpmcounter3_r;
        mhpmcounter4   :    R_DATA =  mhpmcounter4_r;
        mhpmcounter31  :    R_DATA =  mhpmcounter31_r;    
        mhpmcounter3h  :    R_DATA =  mhpmcounter3h_r;
        mhpmcounter4h  :    R_DATA =  mhpmcounter4h_r;
        mhpmcounter31h :    R_DATA =  mhpmcounter31h_r;
        mhpmevent3     :    R_DATA =  mhpmevent3_r   ;
        mhpmevent4     :    R_DATA =  mhpmevent4_r   ;
        mhpmevent31    :    R_DATA =  mhpmevent31_r  ;
        tselect        :    R_DATA =  tselect_r      ;
        tdata1         :    R_DATA =  tdata1_r       ;
        tdata2         :    R_DATA =  tdata2_r       ;
        tdata3         :    R_DATA =  tdata3_r       ;
        dcsr           :    R_DATA =  dcsr_r         ;
        dpc            :    R_DATA =  dpc_r          ;
        dscratch       :    R_DATA =  dscratch_r     ;  
        flags          :    R_DATA =  fflags_r      ;
        frm            :    R_DATA =  frm_r       
        fcsr           :    R_DATA =  fcsr_r        ;     */    



      
       
endmodule
                                                            
                                                                                      
                                   