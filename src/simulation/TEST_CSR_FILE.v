module TEST_CSR_FILE();
    localparam     uie            =    12'h004    ;
    localparam     utvec            =    12'h005    ;
    localparam     uscratch        =    12'h040    ;
    localparam     uepc            =    12'h041    ;
    localparam     ucause            =    12'h042    ;
    localparam     utval            =    12'h043    ;
    localparam     uip            =    12'h044    ;
    localparam     fflags            =    12'h001    ;
    localparam     frm            =    12'h002    ;
    localparam     fcsr            =    12'h003    ;
    localparam     cycle            =    12'hC00    ;
    localparam     timer            =    12'hC01    ;
    localparam     instret        =    12'hC02    ;
    localparam     hpmcounter3    =    12'hC03    ;
    localparam     hpmcounter4    =    12'hC04    ;
    localparam     hpmcounter31    =    12'hC1F    ;
    localparam     cycleh            =    12'hC80    ;
    localparam     timeh            =    12'hC81    ;
    localparam     instreth        =    12'hC82    ;
    localparam     hpmcounter3h    =    12'hC83    ;
    localparam     hpmcounter4h    =    12'hC84    ;
    localparam     hpmcounter31h    =    12'hC9F    ;
    localparam     sstatus        =    12'h100    ;
    localparam     sedeleg        =    12'h102    ;
    localparam     sideleg        =    12'h103    ;
    localparam     sie            =    12'h104    ;
    localparam     stvec            =    12'h105    ;
    localparam     scounteren        =    12'h106    ;
    localparam     sscratch        =    12'h140    ;
    localparam     sepc            =    12'h141    ;
    localparam     scause            =    12'h142    ;
    localparam     stval            =    12'h143    ;
    localparam     sip            =    12'h144    ;
    localparam     satp            =    12'h180    ;
    localparam     mvendorid        =    12'hF11    ;
    localparam     marchid        =    12'hF12    ;
    localparam     mimpid            =    12'hF13    ;
    localparam     mhartid        =    12'hF14    ;
    localparam     mstatus        =    12'h300    ;
    localparam     misa            =   12'h301    ;
    localparam     medeleg        =    12'h302    ;
    localparam     mideleg        =    12'h303    ;
    localparam     mie            =    12'h304    ;
    localparam     mtvec            =    12'h305    ;
    localparam     mcounteren        =    12'h306    ;
    localparam     mscratch        =   12'h340    ;
    localparam     mepc            =    12'h341    ;
    localparam     mcause            =    12'h342    ;
    localparam     mtval            =    12'h343    ;
    localparam     mip            =    12'h344    ;
    localparam     pmpcfg0        =    12'h3A0    ;
    localparam     pmpcfg1        =    12'h3A1    ;
    localparam     pmpcfg2        =    12'h3A2    ;
    localparam     pmpcfg3        =    12'h3A3    ;
    localparam     pmpaddr0        =    12'h3B0    ;
    localparam     pmpaddr1        =    12'h3B1    ;
    localparam     pmpaddr15        =    12'h3BF    ;
    localparam     mcycle            =    12'hB00    ;
    localparam     minstret        =    12'hB02    ;
    localparam     mhpmcounter3    =    12'hB03    ;
    localparam     mhpmcounter4    =    12'hB04    ;
    localparam     mhpmcounter31    =    12'hB1F    ;
    localparam     mcycleh        =    12'hB80    ;
    localparam     minstreth        =    12'hB82    ;
    localparam     mhpmcounter3h    =    12'hB83    ;
    localparam     mhpmcounter4h    =    12'hB84    ;
    localparam     mhpmcounter31h    =    12'hB9F    ;
    localparam     mhpmevent3        =    12'h323    ;
    localparam     mhpmevent4        =    12'h324    ;
    localparam     mhpmevent31    =    12'h33F    ;
    localparam     tselect        =    12'h7A0    ;
    localparam     tdata1            =    12'h7A1    ;
    localparam     tdata2            =    12'h7A2    ;
    localparam     tdata3            =    12'h7A3    ;
    localparam     dcsr            =    12'h7B0    ;
    localparam     dpc            =    12'h7B1    ;
    localparam     dscratch        =    12'h7B2    ;
    // functions
    localparam   ecall          =   3'b000  ;
    localparam   ebreak         =   3'b000  ;
    
    localparam   csrrw          =   3'b001  ;
    localparam   csrrs          =   3'b010  ;
    localparam   csrrc          =   3'b011  ;
    localparam   csrrwi         =   3'b101  ;
    localparam   csrrsi         =   3'b110  ;
    localparam   csrrci         =   3'b111  ;
    
    //modes
    localparam   mmode          =   2'd3    ;
    localparam   hmode          =   2'd2    ;
    localparam   smode          =   2'd1    ;
    localparam   umode          =   2'd0 ;
    localparam     ustatus        =    12'h000    ;
   
    
    reg             CLK       =0      ;
    reg   [31  :0]  pc      =0        ;
    reg   [11   :0] csr_address  =0  ;
    reg    [31   :0] write_data  =0   ;
    reg              csr_enable    =0 ;
    reg [2    :0]    csr_op_type   =0 ;
    reg             meip          =0  ;
    reg             mtip          =0  ; 
    reg             msip          =0  ; 
    reg             trap          =0  ;
    reg [29   :0] e_code_c        =0  ;
    reg           trap_return     =0  ;
    wire            tsr           =0  ;
    wire      tvm            ;
    wire      tw             ;
    wire    [31:0]  r_data       ;
    wire [31:0] handler_pc ;
    
     CSR_FILE csr_file( .CLK(CLK),.PC(pc),.CSR_ADDRESS(csr_address),
                           .WRITE_DATA(write_data),.CSR_ENABLE(csr_enable),.CSR_OP_TYPE(csr_op_type),
                           .MEIP(meip), .MTIP(mtip),.MSIP(msip), .TRAP(trap), .E_CODE_C(e_code_c),
                           .TRAP_RETURN(trap_return) ,.R_DATA(r_data) ,.HANDLER_PC(handler_pc) );
               // ADRESS MAPPINGS
//       
    
    initial
    begin
        
//        csr_address =mstatus;
//        csr_op_type =csrrw;
//        csr_enable  =1'b1;
//        write_data  ={32{1'b1}};
//        #30;
        csr_address =mie;
        csr_op_type =csrrw;
        csr_enable  =1'b1;
        write_data  ={32{1'b1}};
        
        #30;
        csr_enable  =1'b0;
        
        #30;
        trap_return =1'b1;
        #30;
        trap_return =1'b0;
        #30;
        csr_address =mip;
        csr_op_type =csrrw;
        csr_enable  =1'b1;
        write_data  ={32{1'b1}};
        
   
        
        
    end
    always begin
        #5;
        CLK = !CLK;
    end
        
        

endmodule