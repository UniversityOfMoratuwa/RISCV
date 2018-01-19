`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/28/2016 12:03:06 PM
// Design Name: 
// Module Name: FIFO
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


module FIFO #(
        // Primary parameters
        parameter WIDTH = 8,
        parameter DEPTH = 8,
        
        // Calculated parameters
        localparam ADDR_WIDTH = logb2(DEPTH)
    ) (
        input CLK,
        input RSTN,
        input RD_ENB,
        input WR_ENB,
        input [WIDTH - 1 : 0] DATA_IN,
        output reg [WIDTH - 1 : 0] DATA_OUT,
        output EMPTY,
        output FULL
    );
    
    reg [ADDR_WIDTH - 1 : 0] ele_count;
    reg [ADDR_WIDTH - 1 : 0] rd_counter;
    reg [ADDR_WIDTH - 1 : 0] wr_counter;
        
    reg [WIDTH - 1 : 0] memory [0 : DEPTH - 1];
    
    assign FULL = (ele_count == DEPTH - 1);
    assign EMPTY = (ele_count == 0);
    
    always @(posedge CLK) begin
        if (!RSTN) begin
            rd_counter <= 0;
            wr_counter <= 0;
            DATA_OUT <= 0;
            ele_count <= 0;
        end else begin
            if (RD_ENB & !EMPTY) begin
                rd_counter <= rd_counter + 1;
                DATA_OUT <= memory[rd_counter];
            end
            
            if (WR_ENB & !FULL) begin
                wr_counter <= wr_counter + 1;
                memory[wr_counter] <= DATA_IN;
            end
            
            if (!(RD_ENB & !EMPTY) & (WR_ENB & !FULL)) begin
                ele_count <= ele_count + 1;
            end else if ((RD_ENB & !EMPTY) & !(WR_ENB & !FULL)) begin
                ele_count <= ele_count - 1;
            end
        end
    end
    
    initial begin
        rd_counter = 0;
        wr_counter = 0;
        DATA_OUT = 0;
        ele_count = 0;
    end
    
    //  The following function calculates the address width based on specified RAM depth
    function integer logb2;
        input integer depth;
        for (logb2 = 0; depth > 1; logb2 = logb2 + 1)
            depth = depth >> 1;
    endfunction
endmodule

/*
FIFO #(
    .DEPTH(),
    .WIDTH()
) your_instance_name (
    .CLK(),
    .RSTN(),
    .WR_ENB(),
    .RD_ENB(),
    .FULL(),
    .EMPTY(),
    .DATA_IN(),
    .DATA_OUT()
);
*/