`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Vithurson Subasharan
// 
// Create Date: 09/25/2017 04:13:22 PM
// Design Name: 
// Module Name: CONTROL_UNIT
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


module CONTROL_UNIT(
    input      [15:12]        INS      ,
    input      [6:0]          INS1      ,
    output reg [3:0]         ALU_CNT  ,
    output reg [1:0]         D_CACHE_CONTROL,
    output reg [2:0]         COMP_CONT,
    output reg               JUMP     ,
    output reg               JUMPR    ,
    output reg               CBRANCH  ,
    output reg    [1:0]      TYPE     ,
    output reg               A_BUS_SEL,
    output reg               B_BUS_SEL
    );
    `include "PipelineParams.vh"
    reg undefined;
    
    always@(*)
    begin
        COMP_CONT       = INS[14:12]        ;
        D_CACHE_CONTROL = {(INS1[6:0]==store),(INS1[6:0]==load)};     
        JUMP            = INS1[6:0]==jump    ;
        JUMPR           = INS1[6:0]==jumpr   ;
        CBRANCH         = INS1[6:0]==cjump   ;
        COMP_CONT       = INS[14:12];
        undefined =0;
        
        case (INS1[6:0])
        
            lui     : begin
                           A_BUS_SEL           = a_bus_imm_sel ;
                           B_BUS_SEL           = b_bus_pc_sel  ;
                           ALU_CNT             = alu_a         ;
                           TYPE                = alu;
                      end  
            auipc   : begin
                   
                           A_BUS_SEL           = a_bus_imm_sel ;
                           B_BUS_SEL           = b_bus_pc_sel  ;
                           ALU_CNT             = alu_add       ; 
                           TYPE                = alu;
                      end
            jump    : begin
                           
                           A_BUS_SEL           = a_bus_imm_sel ;
                           B_BUS_SEL           = b_bus_pc_sel  ;
                           ALU_CNT             = alu_b4        ;
                           TYPE                = alu           ;
                      end 
            jumpr   : begin
                         
                           A_BUS_SEL           = a_bus_imm_sel ;
                           B_BUS_SEL           = b_bus_pc_sel  ;
                           ALU_CNT             = alu_b4        ;
                           TYPE                = alu           ;
                      end
            cjump   : begin
                           A_BUS_SEL           = a_bus_rs2_sel ;
                           B_BUS_SEL           = b_bus_rs1_sel ;
                           ALU_CNT             = alu_idle      ;
                           TYPE                = idle          ;
                      end                                   
            load    : begin
                           
                           A_BUS_SEL           = a_bus_imm_sel ;
                           B_BUS_SEL           = b_bus_rs1_sel ;                                 
                           TYPE                = ld            ;
                           ALU_CNT             = alu_add       ;
                      
                        
                      end                                   
            store   : begin 
                          
                           A_BUS_SEL           = a_bus_imm_sel ;
                           B_BUS_SEL           = b_bus_rs1_sel ;                                
                           TYPE                = idle        ;
                           ALU_CNT             = alu_add     ; 
                      end
            iops    : begin    
                           TYPE                = alu           ;             
                           A_BUS_SEL           = a_bus_imm_sel ;
                           B_BUS_SEL           = b_bus_rs1_sel ;
                           

                           case({((INS[14:12]==srli)& INS[15]),INS[14:12]})
                                {1'b0,addi }    : ALU_CNT = alu_add;
                                {1'b0,slli }    : ALU_CNT = alu_sll;
                                {1'b0,slti }    : ALU_CNT = alu_slt; 
                                {1'b0,sltiu}    : ALU_CNT = alu_sltu;
                                {1'b0,xori }    : ALU_CNT = alu_xor;
                                {1'b0,srli }    : ALU_CNT = alu_srl;
                                {1'b1,srai }    : ALU_CNT = alu_sra;
                                {1'b0,ori  }    : ALU_CNT = alu_or ;
                                {1'b0,andi }    : ALU_CNT = alu_and ;
                                default         : begin
                                                                 undefined= 1'b1;
                                                                 ALU_CNT = alu_idle;
                                                                end
                           endcase
                       end
                       
              rops    : begin
                               
                            TYPE                = alu;
                            A_BUS_SEL           = a_bus_rs2_sel ;
                            B_BUS_SEL           = b_bus_rs1_sel ;
                            
                            case({(((INS[14:12]==srlr) ||(INS[14:12]==addr))& INS[15]),INS[14:12]})
                                {1'b0,addr }    : ALU_CNT = alu_add;
                                {1'b1,subr }    : ALU_CNT = alu_sub;
                                {1'b0,sllr }    : ALU_CNT = alu_sll;
                                {1'b0,sltr }    : ALU_CNT = alu_slt; 
                                {1'b0,sltur}    : ALU_CNT = alu_sltu;
                                {1'b0,xorr }    : ALU_CNT = alu_xor;
                                {1'b0,srlr }    : ALU_CNT = alu_srl;
                                {1'b1,srai }    : ALU_CNT = alu_sra;
                                {1'b0,orr  }    : ALU_CNT = alu_or ;
                                {1'b0,andr }    : ALU_CNT = alu_and ;
                                default         :
                                begin
                                 undefined= 1'b1;
                                 ALU_CNT = alu_idle;
                                end
                            endcase
                       end
               system  :   begin
                                 TYPE                = alu             ;
                                 A_BUS_SEL           = a_bus_imm_sel    ;
                                 B_BUS_SEL           = b_bus_pc_sel     ;
                                 ALU_CNT             = alu_a         ;
                
                           end
              
              default :begin
                             TYPE                = idle              ;
                             A_BUS_SEL           = a_bus_imm_sel    ;
                             B_BUS_SEL           = b_bus_pc_sel     ;
                             ALU_CNT             = alu_idle         ;
                             undefined=INS!=32'd0;
                       end          
//            mops    :   TYPE=rtype;
//            fence   :   TYPE=ntype;
//            amos    :   TYPE=ntype;
//            default :   TYPE=ntype;
        endcase
    end
endmodule
