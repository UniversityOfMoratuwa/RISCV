`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2016 10:35:43 PM
// Design Name: 
// Module Name: LRU
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


module LRU #(
        parameter N = 3                 // Number of units
    ) (
        input CLK,
        input ENB,
        input [0 : N - 1] USE,
        output reg [N - 1 : 0] LRU
    );
    
    reg [0 : N - 1] memory [0 : N - 1];
    
    integer i;
    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            LRU[N - 1 - i] = !(|(memory[i]));
        end
    end
    
    integer row, col;
    always @(posedge CLK) begin
        if (ENB) begin
            for (row = 0; row < N; row = row + 1) begin
                for (col = 0; col < N; col = col + 1) begin
                    case ({USE[row], USE[col]})
                        2'b00 : memory[row][col] <= memory[row][col];
                        2'b01 : memory[row][col] <= 1'b0;
                        2'b10 : memory[row][col] <= 1'b1;
                        2'b11 : memory[row][col] <= 1'b0;
                    endcase
                end
            end
        end
    end
    
    initial begin
        for (row = 0; row < N; row = row + 1) begin
            for (col = 0; col < N; col = col + 1) begin
                memory[row][col] = (row < col)? 1 : 0;
            end
        end
    end
endmodule

/*
LRU #(
    .N()
) your_instance (
    .CLK(),
    .USE(),
    .LRU()
);
*/    
