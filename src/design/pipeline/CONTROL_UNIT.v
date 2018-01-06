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
    input      [17:12]      INS             ,
    input      [ 6: 0]      INS1            ,
    output reg [ 3: 0]      ALU_CNT         ,
    output reg [ 1: 0]      D_CACHE_CONTROL ,
    output reg [ 2: 0]      FUN3            ,
    output reg [ 3: 0]      CSR_CNT         ,
    output reg              JUMP            ,
    output reg              JUMPR           ,
    output reg              CBRANCH         ,
    output reg [1:0]        TYPE            ,
    output reg              A_BUS_SEL       ,
    output reg              B_BUS_SEL
    );
    
    `include "PipelineParams.vh"
    
    reg undefined;
    
    always@(*)
    begin
        FUN3            = INS[14:12]                            ;
        D_CACHE_CONTROL = {(INS1[6:0]==store),(INS1[6:0]==load)};     
        JUMP            = INS1[6:0]==jump                       ;
        JUMPR           = INS1[6:0]==jumpr                      ;
        CBRANCH         = INS1[6:0]==cjump                      ;
        undefined =0                                            ;
        
        case (INS1[6:0])
        
            lui     : 
            begin
                A_BUS_SEL          = a_bus_imm_sel  ;
                B_BUS_SEL          = b_bus_pc_sel   ;
                ALU_CNT            = alu_a          ;
                CSR_CNT            = sys_idle       ;
                TYPE               = alu            ;
            end  
            auipc   : 
            begin       
                A_BUS_SEL           = a_bus_imm_sel ;
                B_BUS_SEL           = b_bus_pc_sel  ;
                ALU_CNT             = alu_add       ;
                CSR_CNT             = sys_idle      ;
                TYPE                = alu           ;
            end
            jump    : 
            begin      
                A_BUS_SEL           = a_bus_imm_sel ;
                B_BUS_SEL           = b_bus_pc_sel  ;
                ALU_CNT             = alu_b4        ;
                CSR_CNT             = sys_idle      ;
                TYPE                = alu           ;
            end 
            jumpr   : 
            begin    
                A_BUS_SEL           = a_bus_imm_sel ;
                B_BUS_SEL           = b_bus_pc_sel  ;
                ALU_CNT             = alu_b4        ;
                CSR_CNT             = sys_idle      ;
                TYPE                = alu           ;
            end
            cjump   : 
            begin
                A_BUS_SEL           = a_bus_rs2_sel ;
                B_BUS_SEL           = b_bus_rs1_sel ;
                ALU_CNT             = alu_idle      ;
                CSR_CNT             = sys_idle      ;
                TYPE                = idle          ;
            end                                   
            load    : 
            begin             
                A_BUS_SEL           = a_bus_imm_sel ;
                B_BUS_SEL           = b_bus_rs1_sel ;
                ALU_CNT             = alu_add       ;
                CSR_CNT             = sys_idle      ;   
                TYPE                = ld            ;    
            end                                   
            store   : 
            begin       
                A_BUS_SEL           = a_bus_imm_sel ;
                B_BUS_SEL           = b_bus_rs1_sel ;                                
                ALU_CNT             = alu_add       ;
                CSR_CNT             = sys_idle      ;
                TYPE                = idle          ; 
            end
            iops    : 
            begin                 
                A_BUS_SEL           = a_bus_imm_sel ;
                B_BUS_SEL           = b_bus_rs1_sel ;
                CSR_CNT             = sys_idle      ;
                TYPE                = alu           ;
                case({((INS[14:12]==srli)& INS[15]),INS[14:12]})
                    {1'b0,addi }    : ALU_CNT = alu_add ;
                    {1'b0,slli }    : ALU_CNT = alu_sll ;
                    {1'b0,slti }    : ALU_CNT = alu_slt ; 
                    {1'b0,sltiu}    : ALU_CNT = alu_sltu;
                    {1'b0,xori }    : ALU_CNT = alu_xor ;
                    {1'b0,srli }    : ALU_CNT = alu_srl ;
                    {1'b1,srai }    : ALU_CNT = alu_sra ;
                    {1'b0,ori  }    : ALU_CNT = alu_or  ;
                    {1'b0,andi }    : ALU_CNT = alu_and ;
                    default         : 
                    begin
                        undefined= 1'b1     ;
                        ALU_CNT = alu_idle  ;                                            
                    end
                endcase
            end         
            rops    : 
            begin   
                A_BUS_SEL           = a_bus_rs2_sel ;
                B_BUS_SEL           = b_bus_rs1_sel ;
                CSR_CNT             = sys_idle      ;
                TYPE                = alu           ;
                case({INS[16],(((INS[14:12]==srlr) ||(INS[14:12]==addr))& INS[15]),INS[14:12]})
                    {2'b00,addr   }     : ALU_CNT = alu_add     ;
                    {2'b01,subr   }     : ALU_CNT = alu_sub     ;
                    {2'b00,sllr   }     : ALU_CNT = alu_sll     ;
                    {2'b00,sltr   }     : ALU_CNT = alu_slt     ;   
                    {2'b00,sltur  }     : ALU_CNT = alu_sltu    ;
                    {2'b00,xorr   }     : ALU_CNT = alu_xor     ;
                    {2'b00,srlr   }     : ALU_CNT = alu_srl     ;
                    {2'b01,srai   }     : ALU_CNT = alu_sra     ;
                    {2'b00,orr    }     : ALU_CNT = alu_or      ;
                    {2'b00,andr   }     : ALU_CNT = alu_and     ;
                    {2'b10,mul    }     : ALU_CNT = alu_mstd    ;
                    {2'b10,mulh   }     : ALU_CNT = alu_mstd    ;
                    {2'b10,mulhsu }     : ALU_CNT = alu_mstd    ;    
                    {2'b10,mulhu  }     : ALU_CNT = alu_mstd    ;
                    {2'b10,div    }     : ALU_CNT = alu_mstd    ;
                    {2'b10,divu   }     : ALU_CNT = alu_mstd    ;
                    {2'b10,rem    }     : ALU_CNT = alu_mstd    ;
                    {2'b10,remu   }     : ALU_CNT = alu_mstd    ;
                    default         :
                    begin
                        undefined= 1'b1    ;
                        ALU_CNT = alu_idle ;
                    end
                endcase
            end
            system  :   
            begin
                A_BUS_SEL           = a_bus_imm_sel ;
                B_BUS_SEL           = b_bus_pc_sel  ;
                ALU_CNT             = alu_a         ;
                case({(((INS[14:12]==ecall) ||(INS[14:12]==ebreak))& INS[17]),INS[14:12]})
                    {1'b0,ecall  }   : 
                    begin
                        CSR_CNT = sys_ecall   ;
                        TYPE    = idle        ;
                    end
                    {1'b1,ebreak }   : 
                    begin
                        CSR_CNT = sys_ebreak  ;
                        TYPE    = idle        ;
                    end
                    {1'b0,csrrw  }   : 
                    begin
                        CSR_CNT = sys_csrrw   ;
                        TYPE    = idle        ;//need to check and add others
                    end
                    default             :
                    begin
                        undefined   = 1'b1      ;
                        CSR_CNT     = sys_idle  ;
                    end
                endcase
            end
            default :
            begin
                A_BUS_SEL           = a_bus_imm_sel ;
                B_BUS_SEL           = b_bus_pc_sel  ;
                ALU_CNT             = alu_idle      ;
                CSR_CNT             = sys_idle      ;
                TYPE                = idle          ;
                undefined=INS!=32'd0;
            end          
//            mops    :   TYPE=rtype;
//            fence   :   TYPE=ntype;
//            amos    :   TYPE=ntype;
//            default :   TYPE=ntype;
        endcase
    end
endmodule
