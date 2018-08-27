`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yasas Seneviratne and Vithurson Subasharan
// 
// Create Date: 08/12/2016 10:09:38 AM
// Design Name: 
// Module Name: PIPELINE
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


module PIPELINE #(
    // Fixed parameters
        localparam ADDR_WIDTH                   = 32    ,
        localparam DATA_WIDTH                   = 32    ,
        localparam FUNCBIT_WIDTH                = 10    ,        
        localparam OPCODE_WIDTH                 = 7     ,
        localparam REGARRAY_ADDR_WIDTH          = 5     ,
        localparam ALU_CNT_WIDTH                = 4     ,
        localparam FUN_WIDTH                    = 2
    ) (
    
    //////////////////////////////////
    //  INSTRUCTION CACHE SIGNALS   //
    //////////////////////////////////
    
    //Standard inputs
    input                                           CLK                             ,
    input                                           RST                             ,
    
    //Status signals between processor and cache
    input                                           CACHE_READY                     ,    
    output                                          PIPELINE_STALL                  ,
    
    //Input from cache
    input               [ADDR_WIDTH - 1 : 0]        PC_IF_ID                        , 
    input               [DATA_WIDTH - 1 : 0]        INS_IF_ID                       ,
    
    //Output to cache
    output                                          BRANCH_TAKEN                    ,
    output                                          RETURN                          ,
    output              [31:0]                      RETURN_ADDR                     ,
    output              [ADDR_WIDTH - 1 : 0]        BRANCH_ADDRESS                  ,
    
    //////////////////////////////
    //    DATA CACHE SIGNALS    //
    //////////////////////////////
    
    output              [    2      - 1 : 0]        CONTROL_DATA_CACHE          , // CONTROL_FROM_PROC = {00(idle), 01(read), 10(write), 11(flush address from cache)}
    output    reg       [ADDR_WIDTH - 1 : 0]        ADDR_TO_DATA_CACHE =32'd0       ,
    output    reg       [4          - 1 : 0]        BYTE_ENB_TO_CACHE =4'b1111      ,
    output              [DATA_WIDTH - 1 : 0]        DATA_TO_DATA_CACHE              ,
    input               [DATA_WIDTH - 1 : 0]        DATA_TO_PROC                    ,
    output              [ADDR_WIDTH - 1 : 0]        EX_PC                           ,
    output                                          BRANCH                          ,     
    input                                           CACHE_READY_DATA                ,
    output                                          FLUSH                           ,
    output              [ADDR_WIDTH - 1 : 0]        PC_ID_FB                        ,
    output                                          PREDICTED                       ,
    output                                          EXSTAGE_STALLED                 ,
    output              [ADDR_WIDTH - 1 : 0]        INS_ID_EX                       ,
           
           
    input                                           MEIP                            ,   //machine external interupt pending
    input                                           MTIP                            ,   //machine timer interupt pending
    input                                           MSIP                             ,   //machine software interupt pending, from external hart
    output                                          FENCE                          
    );
    
    `include "PipelineParams.vh"
    `include "PipelineConnections.vh"
    
    reg  [63:0] clock=0                     ;
    reg  [63:0] ins=0                       ;
    reg  [31:0] ins_id_fb                   ;
    reg  [31:0] return_addr                 ;
    reg  [31:0] ins_fb_ex                   ;
    
    wire [ 2:0] rs1_count                   ;
    wire [ 2:0] rs2_count                   ;
    
    reg         stall_enable_ex_ex2         ;
    
    wire        flush_internal              ;

    wire [31:0] expecting_pc                ;
    wire [31:0] ins_if_id                   ;
    wire        flush                       ;
    wire [ 1:0] type_out                    ;
    wire        flush_e                     ;
    wire        fence_out                   ;
    
    reg  [ 1:0] data_cache_control_fb_ex    ;
    reg  [31:0] alu_written_back            ;
    reg  [31:0] wb_data_final               ;
    reg  [ 2:0] op_type_ex_ex2              ;
    reg  [ 2:0] op_type_ex_mem1             ;
    reg  [ 2:0] op_type_mem1_mem2           ;
    reg  [ 2:0] op_type_mem2_mem3           ;
    reg  [ 2:0] op_type_mem3_wb             ;
    reg  [31:0] rs1_ex_ex2                  ;
    reg  [31:0] imm_ex_ex2                  ;
    reg  [31:0] imm_fb_ex                   ;
          
    wire [31:0] data_cache_address          ;
    wire [ 1:0] rs1_type                    ;
    wire [ 1:0] rs2_type                    ;
    
    reg  [4:0]  rd_ex_ex2                   ;   
    reg         cache_ready_data            ;
    
    reg  [31:0] pc_ex_ex2                   ;
    reg  [31:0] pc_ex_mem1                  ;
    reg  [31:0] pc_mem1_mem2                ;
    reg  [31:0] pc_mem2_mem3                ;
    reg  [31:0] pc_mem3_wb                  ;
    reg  [31:0] rs2_ex_ex2                  ;
    
    assign ins_if_id = INS_IF_ID            ;
   
    DECODE_UNIT decode_unit(
        .CLK                (CLK)                           ,
        .TYPE_MEM3_WB       (type_mem3_wb)                  ,
        .DATA_CACHE_READY   (CACHE_READY_DATA)              ,
        .INS_CACHE_READY    (CACHE_READY)                   ,
        .INSTRUCTION        (ins_if_id)                     ,
        .WB_DATA            (wb_data_final)                 ,
        .WB_DES             (rd_mem3_wb)                    ,
        .FEED_BACK_MUX1_SEL (feed_back_muxa_sel)            ,
        .FEED_BACK_MUX2_SEL (feed_back_muxb_sel)            ,
        .ALU_CNT            (alu_cnt)                       , 
        .D_CACHE_CONTROL    (data_cache_control_w)          , 
        .FUN3               (fun3)                          , 
        .CSR_CNT            (csr_cnt)                       ,
        .ZIMM               (zimm)                          ,    
        .JUMP               (jump_w)                        ,
        .JUMPR              (jumpr_w)                       ,
        .CBRANCH            (cbranch_w)                     ,
        .OP_TYPE            (op_type)                       ,
        .RS1_OUT            (rs1_out)                       ,
        .RS2_OUT            (rs2_out)                       ,
        .A_BUS_SEL          (a_bus_sel)                     ,
        .B_BUS_SEL          (b_bus_sel)                     ,
        .IMM_OUT            (imm_out)                       ,                    
        .STALL_ENABLE       (stall_enable)                  ,
        .RD_OUT             (rd_out)                        ,
        .FLUSH              (flush_e)                       ,
        .STALL_ENABLE_FB    (stall_enable_id_fb)            ,
        .RS1_TYPE           (rs1_type)                      ,
        .RS2_TYPE           (rs2_type)                  ,
        .RST                (RST)                         ,
        .FENCE              (fence_out)  
        );        
  
    EXSTAGE exstage(
        .CLK(CLK)                                                   ,
        .COMP1              (comp1_fb_ex)                           ,
        .COMP2              (comp2_fb_ex)                           , 
        .COMP1_U            (comp1_fb_ex)                           ,
        .COMP2_U            (comp2_fb_ex)                           , 
        .JUMP_BUS1          (jump1_fb_ex)                           ,
        .JUMP_BUS2          (jump2_fb_ex)                           ,
        .FENCE              (fence_fb_ex)                           ,  
        //.A                  ( ins_fb_ex == 32'hc0002573 ? clock: (ins_fb_ex == 32'hc0202573 ? ins : a_bus_fb_ex))                  ,//clock,ins
        .A                  (a_bus_fb_ex)                           ,
        .B                  (b_bus_fb_ex)                           , 
        //.A_signed           ( ins_fb_ex == 32'hc0002573 ? clock: (ins_fb_ex == 32'hc0202573 ? ins : a_bus_fb_ex ))             ,
        .A_signed           (a_bus_fb_ex)                           ,
        .B_signed           (b_bus_fb_ex)                           ,
        .PC_FB_EX           (pc_fb_ex)                              ,
        .ALU_CNT            (alu_cnt_fb_ex)                         , 
        .JUMP               (jump_fb_ex)                            ,
        .JUMPR              (jumpr_fb_ex)                           ,
        .CBRANCH            (cbranch_fb_ex)                         ,         
        .PC_ID_FB           (pc_id_fb)                              ,
        .STALL_ENABLE_EX    (stall_enable_fb_ex) ,
        .DATA_CACHE_CONTROL_IN(data_cache_control_fb_ex)            ,
        .FUN3               (fun3_fb_ex)                            ,
        .CSR_CNT            (csr_cnt_fb_ex)                         ,
        .ZIMM               (zimm_fb_ex)                            ,
        .CACHE_READY        ( CACHE_READY&CACHE_READY_DATA)         ,
        .TYPE_IN            (ins_fb_ex==32'h00100073 ?2'b0:type_fb_ex ),
        .PROC_IDLE          (!(pc_ex_ex2!=0 && CACHE_READY && CACHE_READY_DATA && !flush_internal))    ,  
        .MEIP               (MEIP)                                  ,   
        .MTIP               (MTIP)                                  ,  
        .MSIP               (MSIP)                                  ,   
        .JUMP_FINAL         (branch_taken)                          ,
        .WB_DATA            (alu_out_wire)                          ,
        .JUMP_ADDR          (BRANCH_ADDRESS)                        ,
        .DATA_ADDRESS       (data_cache_address)                    ,
        .DATA_CACHE_CONTROL (CONTROL_DATA_CACHE)                    ,
        .TYPE_OUT           (type_out)                              ,
        .EXSTAGE_STALLED    (EXSTAGE_STALLED)                       , //mstd
        //   .CACHE_READY_DATA   (CACHE_READY_DATA)             ,
        .FLUSH(flush_e)                                             ,
        .FLUSH_I(flush_internal)                                    ,              
        .PREDICTED(PREDICTED),
        .RST(RST),
        .FENCE_OUT(FENCE)
        );
   
    Multiplexer #(
        .ORDER(3),
        .WIDTH(32)
        ) feed_back_mux_rs1 (
        .SELECT(feed_back_muxa_sel_id_fb),
        .IN({
            alu_written_back,
            (wb_data_final ),
            alu_mem2_mem3,
            alu_mem1_mem2,
            alu_ex_mem1,
            alu_out_wire,
            32'd0,
            rs1_id_fb}),
        .OUT(rs1_final)
        );
   
    Multiplexer #(
        .ORDER(3),
        .WIDTH(32)  
        )feed_back_mux_rs2 (
        .SELECT(feed_back_muxb_sel_id_fb),
        .IN({alu_written_back,
            (wb_data_final ) ,
            alu_mem2_mem3,
            alu_mem1_mem2,
            alu_ex_mem1,
            alu_out_wire,
            32'd0,
            rs2_id_fb}),
        .OUT(rs2_final)
        );
                 
    Multiplexer #(
        .ORDER(1),
        .WIDTH(32)  
        )b_bus_mux (
        .SELECT(b_bus_sel_id_fb),
        .IN({ 
            rs1_final,
            pc_id_fb}),
        .OUT(b_bus_mux_final)
        );
                 
    Multiplexer#(
        .ORDER(1),
        .WIDTH(32)  
        )a_bus_mux (
        .SELECT(a_bus_sel_id_fb),
        .IN({
            rs2_final,
            imm_out_id_fb}),
        .OUT(a_bus_mux_final)
        );
    
    Multiplexer #(
        .ORDER(1),
        .WIDTH(32)  
        )jump2_sel (
        .SELECT(jumpr_id_fb),
        .IN({
            rs1_final ,
            pc_id_fb }),
        .OUT(jmux2_final)
        );
   
    integer writeFile           ;
    integer writeFiled          ;
    
    reg [31:0] xx               ;
    reg [31:0] pc               ;
    reg [31:0] last_data=0      ;
    
    initial
    begin
        writeFile = $fopen("mem_reads.txt", "w");
        $fclose(writeFile);  
        writeFiled = $fopen("clocks.txt", "w");
        $fclose(writeFiled);  
    end
    
    reg  [ 3:0] pred=0          ;
    reg         flag1=0         ;
    reg         init_reg=1      ;
    
    always @(posedge CLK)
    begin
        if(flush_internal)
        begin
            flag1<=1;
            if (!flag1)
            begin
                pred<=pred+1;
            end
        end
        else
        begin
            flag1<=0;
        end
      
        clock<=clock+(1);
        writeFile = $fopen("mem_reads.txt", "a");
        writeFiled = $fopen("clocks.txt", "a");
        if (((ins_fb_ex!=0 && init_reg) |pc_ex_ex2!=0) && CACHE_READY && CACHE_READY_DATA && !flush_internal)
        begin
            $fwrite(writeFile,"%h %h\n",pc_ex_ex2,alu_out_wire);   
            $fwrite(writeFiled,"%d\n",clock);
            ins=ins+1;
            init_reg <= 1'b0;
        end 
        $fclose(writeFiled);                                                             
        $fclose(writeFile);                                                                             
    end      
                                                                              
    reg         flag            ; 
    integer cache_file;
    integer cache_file2;
    initial begin
        cache_file =$fopen("dcache_dump.txt", "w");
        cache_file2 =$fopen("dcache_dump1.txt", "w");
    end
    always@(*)
    begin
        if(type_mem3_wb==ld)
        begin
            case (op_type_mem3_wb)
                load_byte: //lb
                begin
                    case (alu_mem3_wb[1:0])
                        2'b00: wb_data_final = {{24{DATA_TO_PROC[7]}},DATA_TO_PROC[7:0]}    ; 
                        2'b01: wb_data_final = {{24{DATA_TO_PROC[15]}},DATA_TO_PROC[15:8]}  ; 
                        2'b10: wb_data_final = {{24{DATA_TO_PROC[23]}},DATA_TO_PROC[23:16]} ; 
                        2'b11: wb_data_final = {{24{DATA_TO_PROC[31]}},DATA_TO_PROC[31:24]} ; 
                    endcase                   
                end
                load_hword : //Lh                   
                begin
                    case (alu_mem3_wb[1:0])
                        2'b00: wb_data_final = {{16{DATA_TO_PROC[15]}},DATA_TO_PROC[15:0]}  ; 
                        2'b01: wb_data_final = {{16{DATA_TO_PROC[23]}},DATA_TO_PROC[23:8]}  ; 
                        2'b10: wb_data_final = {{16{DATA_TO_PROC[31]}},DATA_TO_PROC[31:16]} ; 
                        default:wb_data_final = 32'd0; 
                    endcase                   
                end
                load_word:  // lw                 
                begin
                    wb_data_final = DATA_TO_PROC;
                end
                load_ubyte : //Lbu                  
                begin
                    case (alu_mem3_wb[1:0])
                        2'b00: wb_data_final = {24'd0,DATA_TO_PROC[7:0]}    ; 
                        2'b01: wb_data_final = {24'd0,DATA_TO_PROC[15:8]}   ; 
                        2'b10: wb_data_final = {24'd0,DATA_TO_PROC[23:16]}  ; 
                        2'b11: wb_data_final = {24'd0,DATA_TO_PROC[31:24]}  ; 
                    endcase                   
                end
                load_uhword:  // lhu                
                begin
                    case (alu_mem3_wb[1:0])
                        2'b00: wb_data_final = {16'd0,DATA_TO_PROC[15:0]}   ; 
                        2'b01: wb_data_final = {16'd0,DATA_TO_PROC[23:8]}   ; 
                        2'b10: wb_data_final = {16'd0,DATA_TO_PROC[31:16]}  ; 
                        default:wb_data_final = 32'd0; 
                    endcase
                end
                default : wb_data_final = DATA_TO_PROC;
            endcase
//            $fdisplay(cache_file,wb_data_final);
//            $fdisplay(cache_file1   ,$time);
        end
        else
            wb_data_final = alu_mem3_wb;
        
        ADDR_TO_DATA_CACHE = {alu_out_wire[31:2],2'b00};
        
        if (op_type_ex_ex2 == store_word)
            BYTE_ENB_TO_CACHE = 4'b1111;
        else if (op_type_ex_ex2 == store_hword)
        begin
            case (alu_out_wire[1:0]) 
                2'b00 : BYTE_ENB_TO_CACHE = 4'b0011;
                2'b01 : BYTE_ENB_TO_CACHE = 4'b0110;
                2'b10 : BYTE_ENB_TO_CACHE = 4'b1100;
                default:BYTE_ENB_TO_CACHE = 4'b0000;
            endcase
            end
        else if (op_type_ex_ex2 == store_byte)
        begin
            case (alu_out_wire[1:0]) 
                2'b00 : BYTE_ENB_TO_CACHE = 4'b0001;
                2'b01 : BYTE_ENB_TO_CACHE = 4'b0010;
                2'b10 : BYTE_ENB_TO_CACHE = 4'b0100;
                2'b11 : BYTE_ENB_TO_CACHE = 4'b1000;
                default:BYTE_ENB_TO_CACHE = 4'b0000;
            endcase
        end
        else
            BYTE_ENB_TO_CACHE = 4'b0000;  
    end
      
    reg       flush_e_i=0;
    reg [1:0] rs1_type_fb;
    reg [1:0] rs2_type_fb;

    assign rs1_count = (flush_e|flush_e_i)?0:(rs1_type_fb==2'b10 ? 5:(rs1_type_fb==2'b00 ? 1:0))    ;
    assign rs2_count = (flush_e|flush_e_i)?0:(rs2_type_fb==2'b10 ? 5:(rs2_type_fb==2'b00 ?1:0))     ;
    
    always@(posedge CLK)
    begin
        // cache_ready_data            <= CACHE_READY_DATA             ;//dummy
        if(RST)
        begin
                rs1_type_fb              <= 0                ; 
                rs2_type_fb              <= 0                ; 
                stall_enable_id_fb       <= 0            ;
                feed_back_muxb_sel_id_fb <= 0      ;  
                feed_back_muxa_sel_id_fb <= 0      ;  
                a_bus_sel_id_fb          <= 0               ;  
                b_bus_sel_id_fb          <= 0               ;                  
                imm_out_id_fb            <= 0                 ;   
                alu_cnt_id_fb            <= 0                 ;    
                fun3_id_fb               <= 0                    ;
                csr_cnt_id_fb            <= 0                 ;
                zimm_id_fb               <= 0                    ; 
                type_id_fb               <= 0                 ;    
                jump_id_fb               <= 0                  ; 
                jumpr_id_fb              <= 0                 ;  
                cbranch_id_fb            <= 0               ;
                rd_id_fb                 <= 0                  ;
                pc_id_fb                 <= 0                ;  
                rs1_id_fb                <= 0                 ;      
                rs2_id_fb                <= 0                 ;    
                data_cache_control_id_fb <= 0    ;
                ins_id_fb                <= 0               ;            
                ins_fb_ex                <= 0               ;
                alu_cnt_fb_ex            <= 0           ;                   
                fun3_fb_ex               <= 0              ;
                csr_cnt_fb_ex            <= 0           ;
                zimm_fb_ex               <= 0              ;    
                type_fb_ex               <= 0              ;    
                jump1_fb_ex              <= 0             ;  
                jump2_fb_ex              <= 0             ;   
                comp1_fb_ex              <= 0            ;  
                comp2_fb_ex              <= 0            ;
                a_bus_fb_ex              <= 0         ;   
                b_bus_fb_ex              <= 0         ;   
                jump_fb_ex               <= 0              ;
                cbranch_fb_ex            <= 0           ;
                jumpr_fb_ex              <= 0             ;
                rd_fb_ex                 <= 0;
                rs2_fb_ex                <= 0               ;      
                rs1_fb_ex                <= 0               ;      
                a_bus_sel_fb_ex          <= 0         ;         
                b_bus_sel_fb_ex          <= 0         ;          
                imm_out_fb_ex            <= 0           ;
                pc_fb_ex                 <= 0                ;
                data_cache_control_fb_ex <= 0;
                rs2_ex_ex2               <= 0               ;
                rs1_ex_ex2               <= 0               ;
                rd_ex_ex2                <= 0                ;   
                op_type_ex_ex2           <= 0              ;     
                pc_ex_ex2                <= 0                ;   
                imm_ex_ex2               <= 0           ;  
                fence_id_fb              <=0;
                fence_fb_ex              <= 0;  
            
        end
        else if(CACHE_READY_DATA & CACHE_READY)
        begin  
            flush_e_i               <= flush_e                      ;
            stall_enable_fb_ex      <= stall_enable_id_fb           ;
            
            if (stall_enable_id_fb||flush_e_i||flush_e)   
            begin  
                fence_id_fb              <= fence_out               ;
                fence_fb_ex              <= fence_id_fb             ;
                rs1_type_fb              <= rs1_type                ; 
                rs2_type_fb              <= rs2_type                ; 
                stall_enable_id_fb       <= stall_enable            ;
                feed_back_muxb_sel_id_fb <= feed_back_muxb_sel      ;  
                feed_back_muxa_sel_id_fb <= feed_back_muxa_sel      ;  
                a_bus_sel_id_fb          <= a_bus_sel               ;  
                b_bus_sel_id_fb          <= b_bus_sel               ;                  
                imm_out_id_fb            <= imm_out                 ;   
                alu_cnt_id_fb            <= alu_cnt                 ;    
                fun3_id_fb               <= fun3                    ;
                csr_cnt_id_fb            <= csr_cnt                 ;
                zimm_id_fb               <= zimm                    ; 
                type_id_fb               <= op_type                 ;    
                jump_id_fb               <= jump_w                  ; 
                jumpr_id_fb              <= jumpr_w                 ;  
                cbranch_id_fb            <= cbranch_w               ;
                rd_id_fb                 <= rd_out                  ;
                pc_id_fb                 <= PC_IF_ID                ;  
                rs1_id_fb                <= rs1_out                 ;      
                rs2_id_fb                <= rs2_out                 ;    
                data_cache_control_id_fb <= data_cache_control_w    ;
                ins_id_fb                <= ins_if_id               ;            
                ins_fb_ex                <= ins_id_fb               ;
                alu_cnt_fb_ex            <= alu_cnt_id_fb           ;                   
                fun3_fb_ex               <= fun3_id_fb              ;
                csr_cnt_fb_ex            <= csr_cnt_id_fb           ;
                zimm_fb_ex               <= zimm_id_fb              ;    
                type_fb_ex               <= type_id_fb              ;    
                jump1_fb_ex              <= jmux1_final             ;  
                jump2_fb_ex              <= jmux2_final             ;   
                comp1_fb_ex              <= c1_mux_final            ;  
                comp2_fb_ex              <= c2_mux_final            ;
                a_bus_fb_ex              <= a_bus_mux_final         ;   
                b_bus_fb_ex              <= b_bus_mux_final         ;   
                jump_fb_ex               <= jump_id_fb              ;
                cbranch_fb_ex            <= cbranch_id_fb           ;
                jumpr_fb_ex              <= jumpr_id_fb             ;
                rd_fb_ex                 <= rd_id_fb                ;
                rs2_fb_ex                <= rs2_final               ;      
                rs1_fb_ex                <= rs1_final               ;      
                a_bus_sel_fb_ex          <= a_bus_sel_id_fb         ;         
                b_bus_sel_fb_ex          <= b_bus_sel_id_fb         ;          
                imm_out_fb_ex            <= imm_out_id_fb           ;
                pc_fb_ex                 <= pc_id_fb                ;
                data_cache_control_fb_ex <= data_cache_control_id_fb;
                rs2_ex_ex2               <= rs2_final               ;
                rs1_ex_ex2               <= rs1_final               ;
                rd_ex_ex2                <= rd_id_fb                ;   
                op_type_ex_ex2           <= fun3_id_fb              ;     
                pc_ex_ex2                <= pc_id_fb                ;   
                imm_ex_ex2               <= imm_out_id_fb           ;        
            end  
            else
            begin     
                if ((feed_back_muxa_sel_id_fb<rs1_count&(feed_back_muxa_sel_id_fb!=0))|(feed_back_muxb_sel_id_fb<rs2_count&(feed_back_muxb_sel_id_fb!=0)))
                begin
                    feed_back_muxa_sel_id_fb <= feed_back_muxa_sel_id_fb+(feed_back_muxa_sel_id_fb!=0);
                    feed_back_muxb_sel_id_fb <= feed_back_muxb_sel_id_fb+(feed_back_muxb_sel_id_fb!=0);
                end
                else
                begin
                    stall_enable_id_fb          <= 1                                                        ;
                    feed_back_muxa_sel_id_fb    <= feed_back_muxa_sel_id_fb+(feed_back_muxa_sel_id_fb!=0)   ;
                    feed_back_muxb_sel_id_fb    <= feed_back_muxb_sel_id_fb+(feed_back_muxb_sel_id_fb!=0)   ;
                end
                 
                if (feed_back_muxa_sel_id_fb==7)
                begin
                    rs1_id_fb <=alu_written_back;
                end
                if (feed_back_muxb_sel_id_fb==7)
                begin
                    rs2_id_fb <=alu_written_back;
                end
                
                alu_cnt_fb_ex            <=    alu_idle             ;
                fun3_fb_ex               <=    no_branch            ;
                csr_cnt_fb_ex            <=    sys_idle             ;
                zimm_fb_ex               <=    0                    ; 
                type_fb_ex               <=    0                    ; 
                jump1_fb_ex              <=    0                    ; 
                jump2_fb_ex              <=    0                    ; 
                comp1_fb_ex              <=    0                    ; 
                comp2_fb_ex              <=    0                    ; 
                a_bus_fb_ex              <=    0                    ; 
                b_bus_fb_ex              <=    0                    ; 
                jump_fb_ex               <=    0                    ; 
                cbranch_fb_ex            <=    0                    ; 
                jumpr_fb_ex              <=    0                    ; 
                rd_fb_ex                 <=    0                    ; 
                rs2_fb_ex                <=    0                    ; 
                rs1_fb_ex                <=    0                    ; 
                a_bus_sel_fb_ex          <=    0                    ; 
                b_bus_sel_fb_ex          <=    0                    ; 
                imm_out_fb_ex            <=    0                    ; 
                //pc_fb_ex                 <=    0                 ; 
                data_cache_control_fb_ex <=    0                    ;
                rs2_ex_ex2               <=    0                    ; 
                rs1_ex_ex2               <=    0                    ; 
                rd_ex_ex2                <=    0                    ; 
                op_type_ex_ex2           <=    0                    ; 
                pc_ex_ex2                <=    0                    ; 
                imm_ex_ex2               <=    0                    ; 
                 fence_id_fb             <= 0                       ;
                fence_fb_ex              <= 0                       ;                 
            end
            
            rd_fb_ex                 <=    rd_id_fb                 ;                      
            rd_ex_mem1               <=    rd_ex_ex2                ;             
            pc_ex_mem1               <=    pc_fb_ex                 ;                                              
            imm_fb_ex                <=    imm_out_id_fb            ;    
        end
        if(RST)
        begin
            type_ex_mem1             <=                 0       ;
            alu_ex_mem1              <=      0                  ;
            op_type_ex_mem1          <=      0                  ;
            feed_back_muxa_sel_id_fb <=0;
            rs1_id_fb<=0; 
            rs2_id_fb <=0;
            type_ex_mem1<=0;
            pc_ex_mem1<=0;
            alu_ex_mem1<=0;
            op_type_ex_mem1<=0;
           alu_mem1_mem2<=0;
           alu_mem2_mem3<=0;
           alu_mem3_wb<=0;
            type_mem1_mem2<=0;
            type_mem2_mem3<=0;
            type_mem3_wb<=0;
            alu_mem1_mem2<=0;
            alu_mem2_mem3<=0;
            alu_mem3_wb<=0;
            return_addr<=0;
            alu_written_back<=0;
            rd_mem1_mem2<=0;
            rd_mem2_mem3<=0;
            rd_mem3_wb<=0;
            pc_mem1_mem2<=0;
            pc_mem2_mem3<=0;
            pc_mem3_wb<=0;
            return_addr<=0;
            op_type_mem1_mem2<=0;
            op_type_mem2_mem3<=0;
            op_type_mem3_wb<=0;


        end
        if (CACHE_READY_DATA)
        begin       
            if (!CACHE_READY)
            begin
                type_ex_mem1             <=      0                  ;
               // pc_ex_mem1               <=      0                  ;            
                alu_ex_mem1              <=      0                  ;
                op_type_ex_mem1          <=      0                  ;
                if(feed_back_muxa_sel_id_fb>2) 
                     feed_back_muxa_sel_id_fb <=      feed_back_muxa_sel_id_fb+1;  
                if(feed_back_muxb_sel_id_fb>2) 
                     feed_back_muxb_sel_id_fb <=    feed_back_muxb_sel_id_fb+1; 
                if (feed_back_muxa_sel_id_fb==7 )
                    rs1_id_fb                <=      alu_written_back;             
                if (feed_back_muxb_sel_id_fb==7 )
                    rs2_id_fb                <=      alu_written_back;                                      
            end
            else 
            begin
                type_ex_mem1             <=      type_out               ;
                pc_ex_mem1               <=      pc_fb_ex               ;            
                alu_ex_mem1              <=      alu_out_wire           ;
                op_type_ex_mem1          <=      op_type_ex_ex2         ;         
            end
           
            type_mem1_mem2           <=      type_ex_mem1               ;
            type_mem2_mem3           <=      type_mem1_mem2             ;
            type_mem3_wb             <=      type_mem2_mem3             ;
            alu_mem1_mem2            <=      alu_ex_mem1                ;
            alu_mem2_mem3            <=      alu_mem1_mem2              ;
            alu_mem3_wb              <=      alu_mem2_mem3              ;
            
            if (rd_mem3_wb==1 & type_mem3_wb!=idle)
            begin
                return_addr          <=      wb_data_final              ;
            end  
            
            alu_written_back         <=       wb_data_final             ;           
            rd_mem1_mem2             <=       rd_ex_mem1                ;    
            rd_mem2_mem3             <=       rd_mem1_mem2              ;    
            rd_mem3_wb               <=       rd_mem2_mem3              ;                   
            pc_mem1_mem2             <=       pc_ex_mem1                ;            
            pc_mem2_mem3             <=       pc_mem1_mem2              ;            
            pc_mem3_wb               <=       pc_mem2_mem3              ;    
            op_type_mem1_mem2        <=       op_type_ex_mem1           ;                           
            op_type_mem2_mem3        <=       op_type_mem1_mem2         ;                         
            op_type_mem3_wb          <=       op_type_mem2_mem3         ; 
        end
    end
    
    assign RETURN               = (ins_fb_ex== 31'h00008067)                        ;
    assign RETURN_ADDR          = return_addr                                       ;
    assign EX_PC                = pc_fb_ex                                          ;
    assign BRANCH               = (jump_fb_ex |cbranch_fb_ex  |jumpr_fb_ex) &  ! flush_internal ;  
    assign FLUSH                = flush_internal                                    ;
    assign BRANCH_TAKEN         = branch_taken                                      ;
    assign PIPELINE_STALL       = (stall_enable_id_fb  ||  branch_taken ||flush_e || flush_e_i || !CACHE_READY) & CACHE_READY_DATA  ;
    assign c1_mux_final         = rs1_final                                         ; 
    assign c2_mux_final         = rs2_final                                         ;
    assign jmux1_final          = imm_out_id_fb                                     ;
    assign INS_ID_EX            = ins_fb_ex                                         ;
    assign DATA_TO_DATA_CACHE   = rs2_ex_ex2 << ({4'b0000,alu_out_wire[1:0]} << 3)  ;
    assign PC_ID_FB             = pc_id_fb                                          ;
    
endmodule