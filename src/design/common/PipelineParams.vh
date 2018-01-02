    //OPCODES  
    localparam lui      = 7'b0110111 ;
    localparam auipc    = 7'b0010111 ;
    localparam jump     = 7'b1101111 ;
    localparam jumpr    = 7'b1100111 ;
    localparam cjump    = 7'b1100011 ;
    localparam load     = 7'b0000011 ;
    localparam store    = 7'b0100011 ;
    localparam iops     = 7'b0010011 ;
    localparam rops     = 7'b0110011 ;
    localparam system   = 7'b1110011 ;  
    localparam fence    = 7'b0001111 ;
    localparam amos     = 7'b0101111 ;
   
    //BRANCHES
    localparam beq         = 3'b000 ;
    localparam bne         = 3'b001 ;
    localparam no_branch   = 3'b010 ;
    localparam blt         = 3'b100 ;
    localparam bge         = 3'b101 ;
    localparam bltu        = 3'b110 ;
    localparam bgeu        = 3'b111 ;
      
     //INTEGER_OPS
    localparam addi    = 3'b000 ;
    localparam slli    = 3'b001 ;
    localparam slti    = 3'b010 ;
    localparam sltiu   = 3'b011 ;
    localparam xori    = 3'b100 ;
    localparam srli    = 3'b101 ;
    localparam srai    = 3'b101 ;
    localparam ori     = 3'b110 ;
    localparam andi    = 3'b111 ;

    //RGISTEROPS
    localparam addr     = 3'b000 ;
    localparam subr     = 3'b000 ;
    localparam sllr     = 3'b001 ;
    localparam sltr     = 3'b010 ;
    localparam sltur    = 3'b011 ;
    localparam xorr     = 3'b100 ;
    localparam srlr     = 3'b101 ;
    localparam srar     = 3'b101 ;
    localparam orr      = 3'b110 ;
    localparam andr     = 3'b111 ;


    //csr OPS
    localparam ecall   = 3'b000 ;
    localparam ebreak  = 3'b000 ;
    localparam csrrw   = 3'b001 ;
    localparam csrrs   = 3'b010 ;
    localparam csrrc   = 3'b011 ;
    localparam csrrwi  = 3'b101 ;
    localparam csrrsi  = 3'b110 ;
    localparam csrrci  = 3'b111 ;
     
    //mops
    localparam mul    =  3'b000  ;
    localparam mulh   =  3'b001  ;
    localparam mulhsu =  3'b010  ;
    localparam mulhu  =  3'b011  ;
    localparam div    =  3'b100  ;
    localparam divu   =  3'b101  ;
    localparam rem    =  3'b110  ;
    localparam remu   =  3'b111  ;
    
    // INS_TYPE
    localparam rtype       =  3'b000  ;
    localparam itype       =  3'b001  ;
    localparam stype       =  3'b010  ;
    localparam btype       =  3'b011  ;
    localparam utype       =  3'b100  ;
    localparam jtype       =  3'b101  ;
    localparam ntype       =  3'b110  ;

   
    
    //FEED BACK MUX SEL
    
//    localparam  direct = 3'b000  ;
//    localparam  fb     = 3'b001  ;
//    localparam  ex     = 3'b010  ;
//    localparam  mem1   = 3'b011  ;
//    localparam  mem2   = 3'b100  ;
//    localparam  mem3   = 3'b101  ;
//    localparam  wb     = 3'b110  ;
    
    //type of write to be done
    localparam  idle  = 2'b00    ;
    localparam  ld    = 2'b01    ;
    localparam  alu   = 2'b10    ;
    
    //ready not ready
    localparam  ready     = 1'b1       ;
    localparam  not_ready = 1'b0       ;
    
    
    //alu controls
    
    localparam alu_add     = 4'b0000 ;
    localparam alu_sub     = 4'b0001 ;
    localparam alu_sll     = 4'b0010 ;
    localparam alu_sltu    = 4'b0011 ;
    localparam alu_xor     = 4'b0100 ;
    localparam alu_srl     = 4'b0101 ;
    localparam alu_sra     = 4'b0110 ;
    localparam alu_or      = 4'b0111 ;
    localparam alu_and     = 4'b1000 ;
    localparam alu_a       = 4'b1001 ;
    localparam alu_b       = 4'b1010 ;
    localparam alu_slt     = 4'b1011 ;
    localparam alu_b4      = 4'b1100 ;
    localparam alu_idle    = 4'b1101 ;
    localparam alu_mstd    = 4'b1110 ;
    
    //data_cache_cntrol
      
    
    localparam cache_idle  = 2'b00   ;
    localparam cache_read  = 2'b01   ;
    localparam cache_write = 2'b10   ;
    localparam cache_flush = 2'b11   ;
    
    //
    localparam a_bus_rs2_sel =2'b1    ;
    localparam a_bus_imm_sel =1'b0    ;
    localparam b_bus_rs1_sel =1'b1    ;
    localparam b_bus_pc_sel  =1'b0    ; 
    
    localparam ex           =3'd0     ;
    localparam ex2          =3'd1     ;
    localparam mem1         =3'd2     ;
    localparam mem2         =3'd3     ;
    localparam mem3         =3'd4     ;
    localparam wb           =3'd5     ;
    localparam wb2          =3'd6     ;
    
    localparam direct        =5'b00001  ;//first three bit mux sel, next bit load operation or alu operation , next bit whether to stall the pipeline or not
    localparam load_ex       =5'b00110  ;
    localparam load_ex2      =5'b01010  ;
    localparam load_mem1     =5'b01110  ;
    localparam load_mem2     =5'b10010  ;
    localparam load_mem3     =5'b10110  ;
    localparam load_wb       =5'b11011  ;
    localparam load_written  =5'b11111  ;
    localparam reg_ex        =5'b00100  ;
    localparam reg_ex2       =5'b01001  ;
    localparam reg_mem1      =5'b01101  ;
    localparam reg_mem2      =5'b10001  ;
    localparam reg_mem3      =5'b10101  ;
    localparam reg_wb        =5'b11001  ;
    localparam reg_written   =5'b11101  ;

    localparam load_byte     = 3'b000;
    localparam load_hword    = 3'b001;
    localparam load_word     = 3'b010;
    localparam load_ubyte    = 3'b100;
    localparam load_uhword   = 3'b101;
    
    localparam store_byte     = 3'b000;
    localparam store_hword    = 3'b001;
    localparam store_word     = 3'b010;
    
   
