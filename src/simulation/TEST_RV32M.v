`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/09/2017 06:49:36 PM
// Design Name: 
// Module Name: TEST_RV32M
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


module TEST_RV32M();

        parameter INPUT_WIDTH   = 32                                                    ;
        localparam MUL          = 3'b000                                                ;
        localparam MULH         = 3'b001                                                ;
        localparam MULHSU       = 3'b010                                                ;
        localparam MULHU        = 3'b011                                                ;
        localparam DIV          = 3'b100                                                ;
        localparam DIVU         = 3'b101                                                ;
        localparam REM          = 3'b110                                                ;
        localparam REMU         = 3'b111                                                ;

        reg                                         clk                                 ;
        reg                                         start                               ;
        reg     [2                          :0]     m_cnt                               ;
        reg     [INPUT_WIDTH - 1            :0]     rs1                                 ;
        reg     [INPUT_WIDTH - 1            :0]     rs2                                 ;
        
        wire    [INPUT_WIDTH - 1            :0]     out                                 ;
        wire                                        ready                               ;
        
        RV32M #(
            .INPUT_WIDTH(INPUT_WIDTH)
        ) uut(
            .CLK(clk),
            .START(start),
            .M_CNT(m_cnt),
            .RS1(rs1),
            .RS2(rs2),
            .OUT(out),
            .READY(ready)
            );
            
        initial 
        begin
        
            start   = 1     ;
            m_cnt   = MUL   ;
            rs1     = 8     ;
            rs2     = 8     ;//0100 ok
            #150;
           
            m_cnt   = MULH  ;
            rs1     = 8     ;
            rs2     = 8     ;//0000 ok
            #150;
          /*
            m_cnt   = 2     ;
            rs1     = 14    ;
            rs2     = 15    ;//1111 ok
            #120;
            
            m_cnt   = 3     ;
            rs1     = 15    ;
            rs2     = 15    ;//1110 ok
            #250;
           */
            m_cnt   = DIV   ;
            rs1     = 20    ;
            rs2     = 15    ;//1110 ok
            #500;
         /*
            m_cnt   = 5     ;
            rs1     = 15     ;
            rs2     = 1    ;//0 ok
            #500;
          
            m_cnt   = 6     ;
            rs1     = 5     ;
            rs2     = 14    ;//1111 ok
            #500;
            
            m_cnt   = 6     ;
            rs1     = 2     ;
            rs2     = 15    ;//0 ok
            #500;
           
            m_cnt   = 7     ;
            rs1     = 2     ;
            rs2     = 15    ;//2 ok
            #500;
            */
            
        end
        
        initial
        begin
            clk     = 0     ;
            forever 
            begin
                #5 clk=~clk;
            end
        end
        
endmodule
