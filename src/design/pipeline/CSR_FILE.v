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
    input               RST             ,
    input       [31:0]  PC              ,
    input       [ 3:0]  CSR_CNT         ,
    input       [11:0]  CSR_ADDRESS     ,
    input       [31:0]  RS1_DATA        ,
    input       [ 4:0]  ZIMM            ,
    output reg  [31:0]  OUTPUT_DATA     ,
    output reg  [31:0]  PRIV_JUMP_ADD   ,
    
    input               PROC_IDLE       ,
    output              PRIV_JUMP       ,
    
    //external interupts >> software interupts >> timer interupts >> synchornous traps
    
    input               MEIP            ,   //machine external interupt pending
    input               MTIP            ,   //machine timer interupt pending
    input               MSIP            ,   //machine software interupt pending, from external hart
    input               TRAP            ,
  
    
    output              TRAP_FINAL      ,
    
    input       [30:0]  E_CODE_C        ,
    input       [31:0]  TVAL            ,
    input               TRAP_RETURN     ,
    
    output reg          TSR             ,
    output reg          TVM             ,
    output reg          TW              
                      
    );  
    
    `include "PipelineParams.vh"
    
    //machine mode specific
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
    
    //supervisor mode specific
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
    //reg     [63     :0]     timer_reg     =0                            ; 
   
    // machine mode wires
    wire    [31 : 0] mip_r       = {20'b0,MEIP,1'b0,seip,ueip,MTIP,1'b0,stip,utip,MSIP,1'b0,ssip,usip}                          ;  //hardwired 0 for hypervisor specs
    wire    [31 : 0] mie_r       = {20'b0,meie,1'b0,seie,ueie,mtie,1'b0,stie,utie,msie,1'b0,ssie,usie}                          ;  
    wire    [31 : 0] mstatus_r   = {sd,8'b0,TSR,TW,TVM,mxr,sum,mprv,4'b0,mpp,2'b0,spp,mpie,1'b0,spie,upie,m_ie,1'b0,s_ie,u_ie}  ;
    wire    [31 : 0] mtvec_r     = {mt_base,mt_mode}                                                                            ;
    wire    [31 : 0] medeleg_r   = medeleg_reg                                                                                  ;
    wire    [31 : 0] mideleg_r   = mideleg_reg                                                                                  ;
    wire    [31 : 0] mscratch_r  = mscratch_reg                                                                                 ;
    wire    [31 : 0] mepc_r      = mepc_reg                                                                                     ;
    wire    [31 : 0] mcycle_r    = mcycle_reg[31 :  0]                                                                          ;
    wire    [31 : 0] mcycleh_r   = mcycle_reg[63 : 32]                                                                          ;
    wire    [31 : 0] mcounteren_r= {29'b0,mir,mtm,mcy}                                                                          ;
    wire    [31 : 0] mcause_r    = {minterrupt,mecode_reg}                                                                      ;
    wire    [31 : 0] mtval_r     = mtval_reg                                                                                    ;   
    wire    [31 : 0] minstret_r  = minsret_reg [31 :  0]                                                                        ;
    wire    [31 : 0] minstreth_r = minsret_reg [63 : 32]                                                                        ;
    wire    [31 : 0] mvendorid_r = 32'd0                                                                                        ;
    wire    [31 : 0] mhartid_r   = 32'd0                                                                                        ;
    wire    [31 : 0] marchid_r   = 32'd0                                                                                        ;
    wire    [31 : 0] mimpid_r    = 32'd0                                                                                        ;
    wire    [31 : 0] misa_r      = 32'b01000000000000000001000100000000                                                         ;    
        
    // supervisor mode wires
    wire    [31 : 0] sstatus_r   = {sd,11'b0,mxr,sum,9'b0,spp,2'b0,spie,upie,2'b0,s_ie,u_ie}    ;
    wire    [31 : 0] stvec_r     = {st_base,st_mode}                                            ;
    wire    [31 : 0] sip_r       = {22'b0,seip,ueip,2'b0,stip,utip,2'b0,ssip,usip}              ;  //hardwired 0 for hypervisor specs
    wire    [31 : 0] sie_r       = {22'b0,seie,ueie,2'b0,stie,utie,2'b0,ssie,usie}              ;  
    wire    [31 : 0] sedeleg_r   = sedeleg_reg                                                  ;
    wire    [31 : 0] sideleg_r   = sideleg_reg                                                  ;
    wire    [31 : 0] sscratch_r  = sscratch_reg                                                 ;
    wire    [31 : 0] sepc_r      = sepc_reg                                                     ;
    wire    [31 : 0] scounteren_r= {29'b0,sir,stm,scy}                                          ;
    wire    [31 : 0] scause_r    = {sinterrupt,secode_reg}                                      ;
    wire    [31 : 0] stval_r     = stval_reg                                                    ;
    wire    [31 : 0] satp_r      = {smode_reg,asid,ppn}                                         ;
   
    // user mode wires 
    wire    [31 : 0] ustatus_r   = {27'b0,upie,3'b0,u_ie}               ;
    wire    [31 : 0] utvec_r     = {ut_base,ut_mode}                    ;
    wire    [31 : 0] uip_r       = { 23'b0,ueip,3'b0,utip,3'b0,usip}    ;  //hardwired 0 for hypervisor specs
    wire    [31 : 0] uie_r       = { 23'b0,ueie,3'b0,utie,3'b0,usie}    ;    
    wire    [31 : 0] uscratch_r  = uscratch_reg                         ;
    wire    [31 : 0] uepc_r      = uepc_reg                             ;
    wire    [31 : 0] ucause_r    = {uinterrupt,uecode_reg}              ;
    wire    [31 : 0] utval_r     = utval_reg                            ;
    wire    [31 : 0] cycle_r     = mcycle_reg [31 :  0]                 ;
    wire    [31 : 0] cycleh_r    = mcycle_reg [63 : 32]                 ;
    //wire    [31 : 0] timer_r     = M_TIME [31 :  0]                     ;
    //wire    [31 : 0] timerh_r    = M_TIME [63 : 32]                     ;
    wire    [31 : 0] instret_r   = minsret_reg [31 :  0]                ;
    wire    [31 : 0] instreth_r  = minsret_reg [63 : 32]                ;
    
    // initial
    // begin
    //     TSR             = 0     ;
    //     TVM             = 0     ;
    //     TW              = 0     ;
    //     OUTPUT_DATA     = 0     ;
    //     PRIV_JUMP_ADD   = 0     ;     
            
    //     {sd,mxr,sum,mprv,mpp,spp,mpie,spie,upie,m_ie,s_ie,u_ie}           = 13'b011000011101        ;
    //     {heip,seip,ueip,htip,stip,utip,hsip,ssip,usip}                    = 9'd0                    ;
    //     {meie,heie,seie,ueie,mtie,htie,stie,utie,msie,hsie,ssie,usie}     = 12'd0                   ;
    //     mpp=2'b11;
    // end
    
    reg     [1  : 0] curr_prev          = mmode                                                     ;
    
    wire             csr_write_allowed  = ((ZIMM==5'b0) | PROC_IDLE) ? 1'b0 : 1'b1                  ;
    wire             illegal_access     = (curr_prev < CSR_ADDRESS[9:8])                            ;
    wire             interrupt          = m_ie & ((meie & MEIP)| (mtie & MTIP) | (MSIP & msie))     ;
    
    reg     [31 : 0] input_data_final   = 32'b0                             ;
    reg     [30 : 0] e_code             = 31'b0                             ;
    reg              trap_return_flag   = 1'b0                              ;
    
    wire             exception          = illegal_access | TRAP             ;
    wire             trap               = exception | interrupt             ;
      
    assign           TRAP_FINAL         = trap                              ;
    
    //Create final write data
    always @(*)
    begin
        case (CSR_CNT)
            sys_csrrw   :    input_data_final =  RS1_DATA                   ;   //Write CSR    
            sys_csrrs   :    input_data_final =  RS1_DATA | OUTPUT_DATA     ;   //Set bits in CSR
            sys_csrrc   :    input_data_final = ~RS1_DATA & OUTPUT_DATA     ;   //Clear bits in CSR
            sys_csrrwi  :    input_data_final =  {27'b0,ZIMM}               ;   //Write imm CSR 
            sys_csrrsi  :    input_data_final =  {27'b0,ZIMM} | OUTPUT_DATA ;   //Set imm bits in CSR
            sys_csrrci  :    input_data_final = ~{27'b0,ZIMM} & OUTPUT_DATA ;   //Cleariimm bits in CSR     
            default     :    input_data_final =   32'b0                     ; 
        endcase
    end
    
    
    //Handling Privilage System instruction and Read from CSR Registers
    always@(*)
    begin
//        if(interrupt)
//        begin
//            if(MEIP)         PRIV_JUMP_ADD = {mt_base,2'b0} + 32'd44; //similarly used and supervisor
//            else if(MSIP)    PRIV_JUMP_ADD = {mt_base,2'b0} + 32'd12;
//            else if(MTIP)    PRIV_JUMP_ADD = {mt_base,2'b0} + 32'd28;
//            //else             ;
//        end
        
        //if(!illegal_access)
        if(1)
        begin
            case ( CSR_ADDRESS )
                ustatus        :    OUTPUT_DATA =  ustatus_r     ;
                uie            :    OUTPUT_DATA =  uie_r         ;
                utvec          :    OUTPUT_DATA =  utvec_r       ;
                uscratch       :    OUTPUT_DATA =  uscratch_r    ;
                uepc           :    OUTPUT_DATA =  uepc_r        ;
                ucause         :    OUTPUT_DATA =  ucause_r      ;
                utval          :    OUTPUT_DATA =  utval_r       ;
                uip            :    OUTPUT_DATA =  uip_r         ;
    /*          fflags         :    OUTPUT_DATA =  fflags_r      ;
                frm            :    OUTPUT_DATA =  frm_r         ;
                fcsr           :    OUTPUT_DATA =  fcsr_r        ;     */
                cycle          :    OUTPUT_DATA =  cycle_r       ;
    //            timer          :    OUTPUT_DATA =  timer_r       ;
                instret        :    OUTPUT_DATA =  instret_r     ;
    /*          hpmcounter3    :    OUTPUT_DATA =  hpmcounter3_r ;
                hpmcounter4    :    OUTPUT_DATA =  hpmcounter4_r ;
                hpmcounter31   :    OUTPUT_DATA =  hpmcounter31_r;      */
                cycleh         :    OUTPUT_DATA =  cycleh_r      ;
    //            timeh          :    OUTPUT_DATA =  timerh_r      ;
                instreth       :    OUTPUT_DATA =  instreth_r    ;
    /*          hpmcounter3h   :    OUTPUT_DATA =  hpmcounter3h_r;
                hpmcounter4h   :    OUTPUT_DATA =  hpmcounter4h_r;
                hpmcounter31h  :    OUTPUT_DATA =  hpmcounter31h_r; */
                sstatus        :    OUTPUT_DATA =  sstatus_r     ;
                sedeleg        :    OUTPUT_DATA =  sedeleg_r     ;
                sideleg        :    OUTPUT_DATA =  sideleg_r     ;
                sie            :    OUTPUT_DATA =  sie_r         ;
                stvec          :    OUTPUT_DATA =  stvec_r       ;
                scounteren     :    OUTPUT_DATA =  scounteren_r  ;
                sscratch       :    OUTPUT_DATA =  sscratch_r    ;
                sepc           :    OUTPUT_DATA =  sepc_r        ;
                scause         :    OUTPUT_DATA =  scause_r      ;
                stval          :    OUTPUT_DATA =  stval_r       ;
                sip            :    OUTPUT_DATA =  sip_r         ;
                satp           :    OUTPUT_DATA =  satp_r        ;
                mvendorid      :    OUTPUT_DATA =  mvendorid_r   ;
                marchid        :    OUTPUT_DATA =  marchid_r     ;
                mimpid         :    OUTPUT_DATA =  mimpid_r      ;
                mhartid        :    OUTPUT_DATA =  mhartid_r     ;
                mstatus        :    OUTPUT_DATA =  mstatus_r     ;
                misa           :    OUTPUT_DATA =  misa_r        ;
                medeleg        :    OUTPUT_DATA =  medeleg_r     ;
                mideleg        :    OUTPUT_DATA =  mideleg_r     ;
                mie            :    OUTPUT_DATA =  mie_r         ;
                mtvec          :    OUTPUT_DATA =  mtvec_r       ;
                mcounteren     :    OUTPUT_DATA =  mcounteren_r  ;
                mscratch       :    OUTPUT_DATA =  mscratch_r    ;
                mepc           :    OUTPUT_DATA =  mepc_r        ;
                mcause         :    OUTPUT_DATA =  mcause_r      ;
                mtval          :    OUTPUT_DATA =  mtval_r       ;
                mip            :    OUTPUT_DATA =  mip_r         ;
    /*          pmpcfg0        :    OUTPUT_DATA =  pmpcfg0_r     ;
                pmpcfg1        :    OUTPUT_DATA =  pmpcfg1_r     ;
                pmpcfg2        :    OUTPUT_DATA =  pmpcfg2_r     ;
                pmpcfg3        :    OUTPUT_DATA =  pmpcfg3_r     ;
                pmpaddr0       :    OUTPUT_DATA =  pmpaddr0_r    ;
                pmpaddr1       :    OUTPUT_DATA =  pmpaddr1_r    ;
                pmpaddr15      :    OUTPUT_DATA =  pmpaddr15_r   ;  */
                mcycle         :    OUTPUT_DATA =  mcycle_r      ;
                minstret       :    OUTPUT_DATA =  minstret_r    ;
    /*          mhpmcounter3   :    OUTPUT_DATA =  mhpmcounter3_r;
                mhpmcounter4   :    OUTPUT_DATA =  mhpmcounter4_r;
                mhpmcounter31  :    OUTPUT_DATA =  mhpmcounter31_r; */
                mcycleh        :    OUTPUT_DATA =  mcycleh_r     ;
                minstreth      :    OUTPUT_DATA =  minstreth_r   ;
    /*          mhpmcounter3h  :    OUTPUT_DATA =  mhpmcounter3h_r;
                mhpmcounter4h  :    OUTPUT_DATA =  mhpmcounter4h_r;
                mhpmcounter31h :    OUTPUT_DATA =  mhpmcounter31h_r;
                mhpmevent3     :    OUTPUT_DATA =  mhpmevent3_r   ;
                mhpmevent4     :    OUTPUT_DATA =  mhpmevent4_r   ;
                mhpmevent31    :    OUTPUT_DATA =  mhpmevent31_r  ;
                tselect        :    OUTPUT_DATA =  tselect_r      ;
                tdata1         :    OUTPUT_DATA =  tdata1_r       ;
                tdata2         :    OUTPUT_DATA =  tdata2_r       ;
                tdata3         :    OUTPUT_DATA =  tdata3_r       ;
                dcsr           :    OUTPUT_DATA =  dcsr_r         ;
                dpc            :    OUTPUT_DATA =  dpc_r          ;
                dscratch       :    OUTPUT_DATA =  dscratch_r     ;  */
                default        :    OUTPUT_DATA =  32'b0          ;
            endcase
            if(interrupt)
            begin
                if(MEIP)         PRIV_JUMP_ADD = {mt_base,2'b0} ; //similarly used and supervisor
                else if(MSIP)    PRIV_JUMP_ADD = {mt_base,2'b0} ;
                else             PRIV_JUMP_ADD = {mt_base,2'b0};
            end
            else
            begin
                case (CSR_CNT)
                    sys_ecall   :  //exception
                    case(curr_prev)
                        umode   : PRIV_JUMP_ADD  = utvec_r    ;
                        smode   : PRIV_JUMP_ADD  = stvec_r    ;
                        mmode   : PRIV_JUMP_ADD  = mtvec_r    ;
                        default : ;
                    endcase
                    
                    sys_uret    :   PRIV_JUMP_ADD = uepc_reg  ;
                    sys_sret    :   PRIV_JUMP_ADD = sepc_reg  ;
                    sys_mret    :   PRIV_JUMP_ADD = mepc_reg  ;
           
                    default     :   PRIV_JUMP_ADD = mepc_reg  ;
                endcase
            end
        end
    end
    
    //Write to CSR Registers and Increment counters
    always@(posedge CLK)
    begin 
        if(RST)
        begin
             mcycle_reg <=0;  
        end  
        else 
             mcycle_reg   <= mcycle_reg + 1'b1       ;

        if(RST)
        begin
            minsret_reg <= 0;
            TSR            <= 0     ;                                                                                             
            TVM            <= 0     ;                                                                                             
            TW             <= 0     ;                                                                                             
            OUTPUT_DATA    <= 0     ;                                                                                             
            PRIV_JUMP_ADD  <= 0     ;                                                                                             
                                                                                                                              
            {sd,mxr,sum,mprv,mpp,spp,mpie,spie,upie,m_ie,s_ie,u_ie}           <= 13'b011000011101        ;                        
            {heip,seip,ueip,htip,stip,utip,hsip,ssip,usip}                    <= 9'd0                    ;                        
            {meie,heie,seie,ueie,mtie,htie,stie,utie,msie,hsie,ssie,usie}     <= 12'd0                   ;                        
            mpp             <=2'b11                      ;                                                                    
            mt_base       <=0                            ;    
            mt_mode       <=0                            ;    
            medeleg_reg   <=0                            ;    
            mideleg_reg   <=0                                ;
            mcycle_reg    <=0                            ;    
            minsret_reg   <=0                            ;    
            {mir,mtm,mcy}   <=0                            ;    
            mscratch_reg  <=0                            ;    
            mepc_reg      <=0                            ;    
            mtval_reg     <=0                            ;    
            mecode_reg    <=0                            ;    
            minterrupt    <=0                            ;    
                                                
                                                
            st_base       <=0                            ;    
            st_mode       <=0                            ;    
            sedeleg_reg   <=0                            ;    
            sideleg_reg   <=0                            ;    
            sinsret_reg   <=0                            ;    
            {sir,stm,scy}   <=0                            ;    
            sscratch_reg  <=0                            ;    
            sepc_reg      <=0                            ;    
            stval_reg     <=0                            ;    
            secode_reg    <=0                            ;    
            sinterrupt    <=0                            ;    
            smode_reg     <=0                            ;    
            asid          <=0                            ;                                                                                                                      
                                                                                                                      
                                                                                                                              
                                                                                                                              

        end
        else if (!PROC_IDLE)
        begin
            //external interupts >> software interupts >> timer interupts >> synchornous traps
             minsret_reg <= minsret_reg + 1'b1   ;
            if(m_ie & meie & MEIP)
            begin
                curr_prev      <=   mmode                                       ;
                mecode_reg     <=   31'd11                                      ;
                minterrupt     <=   1'b1                                        ;    
                mepc_reg       <=   PC                                          ;
                mpp            <=   curr_prev                                   ;
                mpie           <=   m_ie                                        ;
                m_ie           <=   1'b0                                        ;
                //case for others - this for m only
            end
            else if(m_ie & mtie & MTIP)
            begin
                curr_prev      <=   mmode                                       ;
                mecode_reg     <=   31'd7                                       ;
                minterrupt     <=   1'b1                                        ;    
                mepc_reg       <=   PC                                          ;
                mpp            <=   curr_prev                                   ;
                mpie           <=   m_ie                                        ;
                m_ie           <=   1'b0                                        ;
                //case for others - this for m only
            end
            else
            begin
             case(CSR_CNT)
                 sys_ecall   :   
                 begin
                     minterrupt  <= 0    ;
                     case(curr_prev)
                         mmode   :
                         begin
                             mepc_reg    <= PC       ;
                             mpp         <= mmode    ;
                             mecode_reg  <= 31'd11   ;
                         end
                         smode   : 
                         begin
                             sepc_reg    <= PC       ;
                             spp         <= smode    ;
                             mecode_reg  <= 31'd9    ;
                         end
                         umode   :
                         begin
                             uepc_reg    <= PC       ;
                             mecode_reg  <= 31'd8    ;
                         end
                         default : ;
                     endcase
                 end
                 sys_ebreak  :   
                 begin
                     minterrupt  <= 0    ;
                     mecode_reg  <= 3    ;
                     case(curr_prev)
                         umode   : uepc_reg  <= PC   ;
                         smode   : sepc_reg  <= PC   ;
                         mmode   : mepc_reg  <= PC   ;     
                         default : ;
                     endcase
                 end
                 sys_uret    :  
                 begin
                     curr_prev   <= 2'b0         ;
                     u_ie        <= upie         ;
                     upie        <= 1'b1         ;
                 end
                 sys_sret    :  
                 begin
                     curr_prev   <= {1'b0,spp  } ;
                     s_ie        <= spie         ;
                     spie        <= 1'b1         ; 
                 end
                 sys_mret    :
                 begin
                     curr_prev   <= mpp          ;
                     m_ie        <= mpie         ;
                     mpie        <= 1'b0         ;
                 end
                 default     :   ;
            endcase
            end
        
            if(csr_write_allowed)
            begin
                case (CSR_ADDRESS)
                    ustatus         :   {upie,u_ie}         <=  {
                                                                input_data_final[4]         ,
                                                                input_data_final[0]
                                                                }                           ;
                    uie            :    {ueie,utie,usie}    <=  {
                                                                input_data_final[8]         ,
                                                                input_data_final[4]         ,
                                                                input_data_final[0]
                                                                }                           ;
                    utvec          :    {ut_base,ut_mode}   <=  input_data_final            ;   
                    uscratch       :    uscratch_reg        <=  input_data_final            ;
                    uepc           :    uepc_reg            <=  input_data_final            ;
                    ucause         :    {uinterrupt,
                                               uecode_reg}  <=  input_data_final            ;
                    utval          :    utval_reg           <=  input_data_final            ;
                    uip            :    {ueip,utip,usip}    <=  {
                                                                input_data_final[8]         ,
                                                                input_data_final[4]         ,
                                                                input_data_final[0]
                                                                }                           ;
                    sstatus        :    {mxr,sum,spp,spie,
                                        upie,s_ie,u_ie}     <=  {
                                                                input_data_final[19:18]     ,
                                                                input_data_final[8]         ,
                                                                input_data_final[5:4]       ,
                                                                input_data_final[1:0]
                                                                }                           ;
                    sedeleg        :    sedeleg_reg         <=  input_data_final            ;
                    sideleg        :    sideleg_reg         <=  input_data_final            ;
                    sie            :    {seie,ueie,stie,
                                        utie,ssie,usie}     <=  {
                                                                input_data_final[9:8]       ,
                                                                input_data_final[5:4]       ,
                                                                input_data_final[1:0]
                                                                }                           ;
                    stvec          :    {st_base,st_mode}   <=  input_data_final            ;
                    scounteren     :    {sir,stm,scy}       <=  input_data_final[2:0]       ;
                    sscratch       :    sscratch_reg        <=  input_data_final            ;
                    sepc           :    sepc_reg            <=  input_data_final            ;
                    scause         :    {sinterrupt,
                                         secode_reg}        <=  input_data_final            ;
                    stval          :    stval_reg           <=  input_data_final            ;
                    sip            :    {seip,ueip,stip,
                                         utip,ssip,usip}    <=  {
                                                                input_data_final[9:8]       ,
                                                                input_data_final[5:4]       ,
                                                                input_data_final[1:0]
                                                                }                           ;
                    satp           :    {smode_reg,
                                         asid,ppn}          <=  input_data_final            ;
                    mstatus        :    {sd,TSR,TW,TVM,
                                        mxr,sum,mprv,mpp,
                                        spp,mpie,spie,
                                        upie,m_ie,
                                        s_ie,u_ie}          <=  {
                                                                input_data_final[31]        ,
                                                                input_data_final[22:17]     ,
                                                                input_data_final[12:11]     ,
                                                                input_data_final[8:7]       ,
                                                                input_data_final[5:3]       ,
                                                                input_data_final[1:0]
                                                                }                           ;
                    medeleg        :    medeleg_reg         <=  input_data_final            ;
                    mideleg        :    mideleg_reg         <=  input_data_final            ;
                    mie            :    {meie,seie,ueie,
                                        mtie,stie,utie,
                                        msie,ssie,usie}     <=  {
                                                                input_data_final[11]        ,
                                                                input_data_final[9:7]       ,
                                                                input_data_final[5:3]       ,
                                                                input_data_final[1:0]
                                                                }                           ;
                    mtvec          :    {mt_base,mt_mode}   <=  input_data_final            ;
                    mcounteren     :    {mir,mtm,mcy}       <=  input_data_final[2:0]       ;
                    mscratch       :    mscratch_reg        <=  input_data_final            ;
                    mepc           :    mepc_reg            <=  input_data_final            ;
                    mcause         :    {minterrupt,
                                        mecode_reg}         <=  input_data_final            ;
                    mtval          :    mtval_reg           <=  input_data_final            ;
                    mip            :    {seip,ueip,stip,
                                        utip,ssip,usip}     <=  {
                                                                input_data_final[9:8]       ,
                                                                input_data_final[5:4]       ,
                                                                input_data_final[1:0]
                                                                }                           ;
                    mcycle         :    mcycle_reg[31 : 0]  <=  input_data_final            ;
                    minstret       :    minsret_reg [31:0]  <=  input_data_final            ;
                    mcycleh        :    mcycle_reg[63:32]   <=  input_data_final            ;
                    minstreth      :    minsret_reg[63:32]  <=  input_data_final            ;
                    default        :    ; 
                endcase
            end
        end
        
     
    end
    
    assign  PRIV_JUMP       = (CSR_CNT==sys_ecall) | (CSR_CNT==sys_uret) | (CSR_CNT==sys_sret) | (CSR_CNT==sys_mret) | (interrupt)  ;
        
endmodule

                     