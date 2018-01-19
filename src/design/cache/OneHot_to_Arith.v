`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2016 03:33:56 PM
// Design Name: 
// Module Name: OneHot_to_Arith
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:         This module converts a one hot encoding to a normal arithmatic encoding
//                        For example, 0001 -> 0
//                                     0010 -> 1
//                                     0100 -> 2
//                                     1000 -> 3
//                                     others -> invalid
//                      
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module OneHot_to_Bin #(
        // Primary parameters
        parameter ORDER = 0,
        
        // Derived parameters
        localparam WIDTH = 1 << ORDER
    ) (
        // Inputs
        input [WIDTH - 1 : 0] ONE_HOT,
        input [max(ORDER - 1, 0) : 0] DEFAULT,
        // Outputs
        output reg [max(ORDER - 1, 0) : 0] BIN
    );
              
    generate 
        if (ORDER == 0) begin
            always @(*) begin
                BIN = ONE_HOT;
            end
        end else if (ORDER == 1) begin
            always @(*) begin
                case (ONE_HOT) 
                    default         BIN = DEFAULT;
                    2'b01 :         BIN = 1'd0;   
                    2'b10 :         BIN = 1'd1;
                endcase
            end
        end else if (ORDER == 2) begin
            always @(*) begin
                case (ONE_HOT) 
                    default         BIN = DEFAULT;
                    4'b0001 :       BIN = 2'd0;   
                    4'b0010 :       BIN = 2'd1;
                    4'b0100 :       BIN = 2'd2;   
                    4'b1000 :       BIN = 2'd3;
                endcase
            end
        end else begin
            always @(*) begin
                case (ONE_HOT)
                    default         BIN = DEFAULT;
                    8'b00000001 :   BIN = 3'd0;   
                    8'b00000010 :   BIN = 3'd1;
                    8'b00000100 :   BIN = 3'd2;
                    8'b00001000 :   BIN = 3'd3;
                    8'b00010000 :   BIN = 3'd4;
                    8'b00100000 :   BIN = 3'd5;
                    8'b01000000 :   BIN = 3'd6;
                    8'b10000000 :   BIN = 3'd7;
                endcase
            end
        end
    endgenerate
    
    function integer max;
        input integer a, b;
        if (a > b) 
            max = a;
        else 
            max = b;    
    endfunction
endmodule
