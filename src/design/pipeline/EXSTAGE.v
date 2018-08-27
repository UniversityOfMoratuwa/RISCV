`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:  Vithurson Subasharan
// 
// Create Date: 08/11/2016 09:46:32 PM
// Design Name: 
// Module Name: EXSTAGE
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


module EXSTAGE(
    input                   CLK                     ,
    input                   RST                     ,
    input signed    [31:0]  COMP1                   ,
    input signed    [31:0]  COMP2                   ,
    input           [31:0]  COMP1_U                 ,
    input           [31:0]  COMP2_U                 ,
    input           [31:0]  JUMP_BUS1               ,
    input           [31:0]  JUMP_BUS2               ,  
    input           [31:0]  A                       ,
    input           [31:0]  B                       ,
    input signed    [31:0]  A_signed                ,
    input signed    [31:0]  B_signed                ,
    input           [31:0]  PC_FB_EX                ,
    input           [ 3:0]  ALU_CNT                 , 
    input                   JUMP                    ,
    input                   JUMPR                   ,
    input                   CBRANCH                 , 
    input           [31:0]  PC_ID_FB                ,
    input                   STALL_ENABLE_EX         ,
    input           [ 1:0]  DATA_CACHE_CONTROL_IN   ,     
    input           [ 2:0]  FUN3                    ,
    input           [ 3:0]  CSR_CNT                 ,
    input           [ 4:0]  ZIMM                    ,
    input                   CACHE_READY             ,
    input           [ 1:0]  TYPE_IN                 ,
    input                   PROC_IDLE               ,
    
    input                   MEIP                    ,   //machine external interupt pending
    input                   MTIP                    ,   //machine timer interupt pending
    input                   MSIP                    ,   //machine software interupt pending, from external hart

    output                  JUMP_FINAL              ,
    output          [31:0]  WB_DATA                 ,   
    output reg      [31:0]  JUMP_ADDR               ,
    output reg      [31:0]  DATA_ADDRESS            ,
    output          [1 :0]  DATA_CACHE_CONTROL      ,
    output          [1 :0]  TYPE_OUT                ,
    output                  EXSTAGE_STALLED         ,//mstd
    output                  FLUSH_I                 ,
    output reg              FLUSH =1'b0             ,
    output reg              PREDICTED               ,
    input                   FENCE          ,
    output                  FENCE_OUT             
    );
    //     reg        comp_out;
     wire [31:0] wb_data;

    `include "PipelineParams.vh"

    reg         jump_reg=0          ;
    reg         jumpr_reg=0         ;
    reg  [31:0] alu_ins [0:15]      ;               
    reg  [31:0] pc_ex_ex2           ;  
                 
    wire [31:0] lshift_out          ;           
    wire [31:0] rshift_out          ;           
    wire [31:0] rashift_out         ; 
    
    wire [31:0] rv32m_out           ;
    wire        rv32m_ready         ;
    
    wire [31:0] csr_out             ;
    wire [31:0] priv_jump_add       ; 
    wire        priv_jump           ;
    
    reg         flush_internal  =0  ;
    reg         cache_ready_fb  =0  ;
    reg         cache_ready_ex  =0  ;
    reg         cache_ready_ex2 =0  ;
    
       
    integer j;   
    
    reg         comp_out [0:7]      ;
    reg  [ 3:0] alu_cnt=alu_idle    ;
    reg  [ 2:0] fun3=no_branch      ;
    
    initial
    begin
        for (j=0; j<=15 ; j = j+1)
        begin
            alu_ins[j]=0;
        end
        for (j=0; j<=7 ; j = j+1)
        begin
            comp_out[j]=0;
        end
    end
      
    Multiplexer #(
        .ORDER(4)       ,
        .WIDTH(32)  
    )alu_mux  (
        .SELECT(alu_cnt),
        .IN({
            alu_ins[15]     ,
            alu_ins[14]     ,
            alu_ins[13]     ,
            alu_ins[12]     ,
            alu_ins[11]     ,
            alu_ins[10]     ,
            alu_ins[9]      ,
            alu_ins[8]      ,
            alu_ins[7]      , 
            alu_ins[6]      ,
            alu_ins[5]      ,
            alu_ins[4]      ,
            alu_ins[3]      ,
            alu_ins[2]      ,
            alu_ins[1]      ,
            alu_ins[0]                     
        }), 
        .OUT(wb_data) 
        );   
                    
    always@(*)
    begin
        if (1)
        begin
            alu_cnt             <=      ALU_CNT                         ;
            alu_ins[alu_add ]   <=      {A + B}                         ;                   
            alu_ins[alu_sub ]   <=      B +{~A + 32'd1}                 ;                       
            alu_ins[alu_sll ]   <=      lshift_out                      ;                 
            alu_ins[alu_sltu]   <=      {31'd0,B<A}                     ;                   
            alu_ins[alu_xor ]   <=      A^B                             ;                    
            alu_ins[alu_srl ]   <=      rshift_out                      ;                     
            alu_ins[alu_sra ]   <=      rashift_out                     ;                     
            alu_ins[alu_or  ]   <=      B|A                             ;                     
            alu_ins[alu_and ]   <=      A&B                             ;                   
            alu_ins[alu_a   ]   <=      A                               ;                        
            alu_ins[alu_b   ]   <=      B                               ;                       
            alu_ins[alu_slt ]   <=      {31'd0,B_signed < A_signed}     ;
            alu_ins[alu_b4  ]   <=      B+32'd4                         ; 
            alu_ins[alu_idle]   <=      32'b0                           ;
            alu_ins[alu_csr ]   <=      csr_out                         ;
            alu_ins[alu_mstd]   <=      rv32m_out                       ;
        end   
    end      
       
    genvar i;
    wire [1023:0] lshift_in;
    wire [1023:0] rshift_in;
    wire [1023:0] rashift_in;
    
    generate
        for (i = 0; i <= 31; i = i + 1) begin : lshift_loop
        if (i==0)
            begin
                assign lshift_in [ 0 +: 32 ]  = B[31:0]                     ;
                assign rshift_in [ 0 +: 32 ]  = B[31:0]                     ;
                assign rashift_in[ 0 +: 32 ]  = B[31:0]                     ;
            end
        else
            begin
                assign lshift_in  [32*i  +: 32] = {B[31-i:0],{i{1'b0}}}     ;
                assign rshift_in  [32*i  +: 32] = {{i{1'b0}},B[31:i]}       ;
                assign rashift_in [32*i  +: 32] = {{i{B[31]}},B[31:i]}      ;
            end
        end
    endgenerate
  
    Multiplexer #(
        .ORDER(5),
        .WIDTH(32)  
    )lshift  (
        .SELECT(A[4:0]),
        .IN(lshift_in),
        .OUT(lshift_out)
        );
        
    Multiplexer #(
        .ORDER(5),
        .WIDTH(32)  
    )rshift  (
        .SELECT(A[4:0]),
        .IN(rshift_in),
        .OUT(rshift_out)
        );
        
    Multiplexer #(
        .ORDER(5),
        .WIDTH(32)  
    )rashift  (
        .SELECT(A[4:0]),
        .IN(rashift_in),
        .OUT(rashift_out)
        );
        
    CSR_FILE csr_file(
        .CLK(CLK),
        .PC(PC_FB_EX),
        .CSR_CNT(CSR_CNT),
        .CSR_ADDRESS(A[11:0]),
        .RS1_DATA(COMP1),
        .ZIMM(ZIMM),
        .OUTPUT_DATA(csr_out),
        .PRIV_JUMP_ADD(priv_jump_add),
        .PROC_IDLE(PROC_IDLE),
        .PRIV_JUMP(priv_jump),
        .MEIP(MEIP),   
        .MTIP(MTIP),   
        .MSIP(MSIP)  ,
        .RST(RST)                      
        );
        
    RV32M rv32m(
        .CLK(CLK),
        .START((ALU_CNT==alu_mstd)& !flush_internal),
        .M_CNT(FUN3),
        .RS1(B),
        .RS2(A),
        .OUT(rv32m_out),
        .READY(rv32m_ready) 
        );
        
    wire        comp_out_w          ; 
                 
    reg         cbranch             ;
    reg  [1:0]  data_cache_control  ;
    reg         flush_out           ;
    
    reg  [1:0]  type_out            ;
    
    (* keep = "true" *) reg [3:0] counter_1=0;
    (* keep = "true" *) reg [3:0] counter_2=0;  
      
    always@(*)
    begin
        if (1)
        begin
            cbranch             <= CBRANCH                      ;
            fun3                <= FUN3                         ;
            comp_out[beq]       <= COMP1 == COMP2               ; 
            comp_out[bne]       <= COMP1 != COMP2               ;
            comp_out[blt]       <= COMP1 < COMP2                ;
            comp_out[bge]       <= COMP1 >= COMP2               ;
            comp_out[bltu]      <= COMP1_U < COMP2_U            ;
            comp_out[bgeu]      <= COMP1_U >= COMP2_U           ;
            pc_ex_ex2           <= PC_FB_EX                     ;
                   
            data_cache_control  <= DATA_CACHE_CONTROL_IN        ;
            type_out            <= TYPE_IN                      ;
            
            JUMP_ADDR           <= FENCE? PC_FB_EX+4 : (priv_jump ? priv_jump_add : (JUMP_BUS1+JUMP_BUS2))    ;  
            jump_reg            <= JUMP                                                 ;          
            jumpr_reg           <= JUMPR                                                ;
            DATA_ADDRESS        <= (A_signed+B_signed)                                  ;
        end
    end
    
    Multiplexer #(
        .ORDER(3),
        .WIDTH(1)  
    )comp  (
        .SELECT(fun3),
        .IN({
            comp_out[7],
            comp_out[6],
            comp_out[5],
            comp_out[4],
            2'b0       ,
            comp_out[1],
            comp_out[0]             
           }),
        .OUT(comp_out_w)
        );             
    
    always@(posedge CLK)
    begin
        if (CACHE_READY)
        begin
             cache_ready_fb <= 1                ;
             cache_ready_ex <= cache_ready_fb   ;
             cache_ready_ex2<= cache_ready_ex   ;
             
             if (JUMP_FINAL)
             begin
                FLUSH               <=    (PC_ID_FB!=JUMP_ADDR) | FENCE;
                flush_internal      <=    (PC_ID_FB!=JUMP_ADDR) | FENCE  ;
             end
             else if (STALL_ENABLE_EX & !flush_internal & cache_ready_ex2)
             begin
                FLUSH               <=    PC_ID_FB!=PC_FB_EX+4;
                flush_internal      <=    PC_ID_FB!=PC_FB_EX+4;
             end
             
             if (FLUSH)
             begin
                counter_1    <= counter_1 + 1; 
             end
             if (flush_internal)
             begin
                counter_2    <= counter_2 + 1;
             end
             if (counter_1 == 3'd3)
             begin
                FLUSH<=1'b0;
             end
             if (counter_2 == 3'd5)
             begin
                flush_internal<=1'b0;
             end
             
             if (!FLUSH)
             begin
                counter_1 <=3'd0;
             end
             if (!flush_internal)
             begin
                counter_2 <= 3'd0;
             end
        end
    end
    
    always@(*)
    begin
        if (JUMP_FINAL & CACHE_READY)
        begin
            PREDICTED=PC_ID_FB==JUMP_ADDR;
        end
        else if (STALL_ENABLE_EX & !flush_internal & cache_ready_ex2 & CACHE_READY)
        begin
            PREDICTED=PC_ID_FB==PC_FB_EX+4;
        end 
        else 
        begin
            PREDICTED=1;
        end    
    end
    
    assign JUMP_FINAL           = (FENCE ? 1:((priv_jump ? priv_jump : (cbranch ? comp_out_w :jump_reg|jumpr_reg )))) & !flush_internal   ; 
    assign WB_DATA              = wb_data & {32{!flush_internal}}                                                           ;
    assign DATA_CACHE_CONTROL   = data_cache_control & {2{!flush_internal}}   & {2{!priv_jump}}                             ;
    assign TYPE_OUT             = type_out & {2{!flush_internal}} & {2{!priv_jump}}                                         ;
    assign FLUSH_I              = flush_internal                                                                            ;
    assign EXSTAGE_STALLED      = ((ALU_CNT==alu_mstd) & !rv32m_ready ) & !flush_internal & {!priv_jump}                    ;
    assign FENCE_OUT            = FENCE & !flush_internal;
  
endmodule
