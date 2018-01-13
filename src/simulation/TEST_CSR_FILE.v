module TEST_CSR_FILE();

    //csr OPS
    localparam sys_idle    = 4'b0000 ; 
    
    localparam sys_ecall   = 4'b0001 ;
    localparam sys_ebreak  = 4'b0010 ;
    localparam sys_uret    = 4'b0011 ;
    localparam sys_sret    = 4'b0100 ;
    localparam sys_mret    = 4'b0101 ;
    localparam sys_wfi     = 4'b0110 ;
    
    localparam sys_csrrw   = 4'b1000 ;
    localparam sys_csrrs   = 4'b1001 ;
    localparam sys_csrrc   = 4'b1010 ;
    localparam sys_csrrwi  = 4'b1011 ;
    localparam sys_csrrsi  = 4'b1100 ;
    localparam sys_csrrci  = 4'b1101 ;
    
    // CSR ADRESS MAPPINGS
    localparam     ustatus        =    12'h000      ;
    localparam     uie            =    12'h004      ;
    localparam     utvec          =    12'h005      ;
    localparam     uscratch       =    12'h040      ;
    localparam     uepc           =    12'h041      ;
    localparam     ucause         =    12'h042      ;
    localparam     utval          =    12'h043      ;
    localparam     uip            =    12'h044      ;
    localparam     fflags         =    12'h001      ;
    localparam     frm            =    12'h002      ;
    localparam     fcsr           =    12'h003      ;
    localparam     cycle          =    12'hC00      ;
    localparam     timer          =    12'hC01      ;
    localparam     instret        =    12'hC02      ;
    localparam     hpmcounter3    =    12'hC03      ;
    localparam     hpmcounter4    =    12'hC04      ;
    localparam     hpmcounter31   =    12'hC1F      ;
    localparam     cycleh         =    12'hC80      ;
    localparam     timeh          =    12'hC81      ;
    localparam     instreth       =    12'hC82      ;
    localparam     hpmcounter3h   =    12'hC83      ;
    localparam     hpmcounter4h   =    12'hC84      ;
    localparam     hpmcounter31h  =    12'hC9F      ;
    localparam     sstatus        =    12'h100      ;
    localparam     sedeleg        =    12'h102      ;
    localparam     sideleg        =    12'h103      ;
    localparam     sie            =    12'h104      ;
    localparam     stvec          =    12'h105      ;
    localparam     scounteren     =    12'h106      ;
    localparam     sscratch       =    12'h140      ;
    localparam     sepc           =    12'h141      ;
    localparam     scause         =    12'h142      ;
    localparam     stval          =    12'h143      ;
    localparam     sip            =    12'h144      ;
    localparam     satp           =    12'h180      ;
    localparam     mvendorid      =    12'hF11      ;
    localparam     marchid        =    12'hF12      ;
    localparam     mimpid         =    12'hF13      ;
    localparam     mhartid        =    12'hF14      ;
    localparam     mstatus        =    12'h300      ;
    localparam     misa           =    12'h301      ;
    localparam     medeleg        =    12'h302      ;
    localparam     mideleg        =    12'h303      ;
    localparam     mie            =    12'h304      ;
    localparam     mtvec          =    12'h305      ;
    localparam     mcounteren     =    12'h306      ;
    localparam     mscratch       =    12'h340      ;
    localparam     mepc           =    12'h341      ;
    localparam     mcause         =    12'h342      ;
    localparam     mtval          =    12'h343      ;
    localparam     mip            =    12'h344      ;
    localparam     pmpcfg0        =    12'h3A0      ;
    localparam     pmpcfg1        =    12'h3A1      ;
    localparam     pmpcfg2        =    12'h3A2      ;
    localparam     pmpcfg3        =    12'h3A3      ;
    localparam     pmpaddr0       =    12'h3B0      ;
    localparam     pmpaddr1       =    12'h3B1      ;
    localparam     pmpaddr15      =    12'h3BF      ;
    localparam     mcycle         =    12'hB00      ;
    localparam     minstret       =    12'hB02      ;
    localparam     mhpmcounter3   =    12'hB03      ;
    localparam     mhpmcounter4   =    12'hB04      ;
    localparam     mhpmcounter31  =    12'hB1F      ;
    localparam     mcycleh        =    12'hB80      ;
    localparam     minstreth      =    12'hB82      ;
    localparam     mhpmcounter3h  =    12'hB83      ;
    localparam     mhpmcounter4h  =    12'hB84      ;
    localparam     mhpmcounter31h =    12'hB9F      ;
    localparam     mhpmevent3     =    12'h323      ;
    localparam     mhpmevent4     =    12'h324      ;
    localparam     mhpmevent31    =    12'h33F      ;
    localparam     tselect        =    12'h7A0      ;
    localparam     tdata1         =    12'h7A1      ;
    localparam     tdata2         =    12'h7A2      ;
    localparam     tdata3         =    12'h7A3      ;
    localparam     dcsr           =    12'h7B0      ;
    localparam     dpc            =    12'h7B1      ;
    localparam     dscratch       =    12'h7B2      ;
    
    //CSR modes
    localparam     mmode          =    2'b11        ;
    localparam     hmode          =    2'b10        ;
    localparam     smode          =    2'b01        ;
    localparam     umode          =    2'b00        ;
   
    
    reg             clk             ;
    reg   [31  :0]  pc              ;
    reg   [3   :0]  csr_cnt         ;
    reg   [11  :0]  csr_address     ;
    reg   [31  :0]  rs1_data        ;
    reg   [4   :0]  zimm            ;
    reg             proc_idle       ;
    
    wire  [31  :0]  output_data     ;
    wire            priv_jump       ;
  
    reg             meip            ;
    reg             mtip            ; 
    reg             msip            ; 
    reg             trap            ;
    
    CSR_FILE csr_file( 
        .CLK(clk),
        .PC(pc),
        .CSR_CNT(csr_cnt),
        .CSR_ADDRESS(csr_address),
        .RS1_DATA(rs1_data),
        .ZIMM(zimm),
        .OUTPUT_DATA(output_data),
        .PROC_IDLE(proc_idle),
        .PRIV_JUMP(priv_jump),
        .MEIP(meip), 
        .MTIP(mtip),
        .MSIP(msip), 
        .TRAP(trap)
        );
          
          

    initial
    begin
        clk             = 0         ;  
        proc_idle       = 0         ;
        zimm            = 0         ;
      
        /* 
        //test ecall/mtvec - pass
        pc              = 8         ;
        csr_cnt         = sys_csrrw ;
        csr_address     = mtvec     ;
        rs1_data        = 104       ;
        zimm            = 0         ;
        
        #20;
        pc              = 0         ;
        csr_cnt         = sys_idle  ;
        csr_address     = utvec     ;
        rs1_data        = 16        ;
        zimm            = 0         ;
        
        #20
        pc              = 4         ;
        csr_cnt         = sys_ecall ;
        csr_address     = 0         ;
        rs1_data        = 0         ;//output 104
        zimm            = 0         ;
        
        #20;
        pc              = 0         ;
        csr_cnt         = sys_idle  ;
        csr_address     = 0         ;
        rs1_data        = 16        ;
        zimm            = 0         ;
        
        #20
        pc              = 8         ;
        csr_cnt         = sys_csrrs ;
        csr_address     = mepc      ;
        rs1_data        = 0         ;//output 4 
        zimm            = 0         ;
        */
        
        /*
        //RD_INS RD_CYCLE - pass        
        #20;
        pc              = 0         ;
        csr_cnt         = sys_csrrs ;
        csr_address     = cycle     ;
        rs1_data        = 0         ;//x
        zimm            = 0         ;
        
        #20
        pc              = 4         ;
        csr_cnt         = sys_csrrs ;
        csr_address     = instret   ;
        rs1_data        = 0         ; //y
        zimm            = 0         ;
        
        #20;
        pc              = 8         ;
        proc_idle       = 1         ;
        #20;
        pc              = 16        ;
        proc_idle       = 0         ; 
        
        #20;
        pc              = 0         ;
        csr_cnt         = sys_csrrs ;
        csr_address     = cycle     ;
        rs1_data        = 0         ;//output x+8
        zimm            = 0         ;
        
        #20
        pc              = 4         ;
        csr_cnt         = sys_csrrs ;
        csr_address     = instret   ;
        rs1_data        = 0         ;//output y+6  
        zimm            = 0         ;    
        */
        
    end
    
    
    
    always begin
        #5;
        clk = !clk;
    end    

endmodule