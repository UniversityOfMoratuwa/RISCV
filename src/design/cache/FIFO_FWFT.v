`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/30/2016 08:09:27 PM
// Design Name: 
// Module Name: FIFO_FWFT
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


module FIFO_FWFT #(
        // Primary parameters
        parameter WIDTH = 8,
        parameter DEPTH = 8        
    ) ( 
        input CLK,
        input RSTN,
        input RD_ENB,
        input WR_ENB,
        input [WIDTH - 1 : 0] DATA_IN,
        (* mark_debug *) output [WIDTH - 1 : 0] DATA_OUT,
        output EMPTY,
        output FULL
    );
    
    reg fifo_valid;
    wire fifo_rd_enb, fifo_empty;
    
    assign fifo_rd_enb = !fifo_empty & (RD_ENB | !fifo_valid);
    assign EMPTY = !fifo_valid;
    
    FIFO #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH)
    ) fifo (
        .CLK(CLK),
        .RSTN(RSTN),
        .WR_ENB(WR_ENB),
        .RD_ENB(fifo_rd_enb),
        .FULL(FULL),
        .EMPTY(fifo_empty),
        .DATA_IN(DATA_IN),
        .DATA_OUT(DATA_OUT)
    );
    
    always @(posedge CLK) begin
        if (!RSTN) begin
            fifo_valid <= 0;
        end else begin
            if (fifo_rd_enb) begin
                fifo_valid <= 1;
            end else if (RD_ENB) begin
                fifo_valid <= 0;
            end  
        end
    end
    
    initial begin
        fifo_valid = 0;
    end
    
endmodule

/*
FIFO_FWFT #(
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