`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/14/2017 03:41:54 PM
// Design Name: 
// Module Name: Replacement_Unit
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


module Replacement_Unit #(
        // Primary parameters
        parameter S                 = 17,                    // Size of the cache will be 2^S bits
        parameter B                 = 9,                     // Size of a block will be 2^B bits
        parameter a                 = 1,                     // Associativity of the cache would be 2^a
        
        // Calculated parameters
        localparam TAG_ADDR_WIDTH   = S - a - B                        
    ) (
        input                           CLK,
        //input  [TAG_ADDR_WIDTH - 1 : 0] BLOCK,
        output [a              - 1 : 0] REPLACE
    );
    
    assign REPLACE = replace;
    
    reg [a - 1 : 0] replace;
    
    always @(posedge CLK) begin
        replace <= replace;         // Temporary
    end
    
    initial begin
        replace = 0;
    end
    
endmodule
