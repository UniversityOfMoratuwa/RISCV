`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/03/2016 07:31:38 PM
// Design Name: 
// Module Name: Stream_Buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: This doesn't behave exactly like a FIFO. It always sends
//                      out the memory at rd_pointer. Thus it takes two clock cycles
//                      to become valid. So to get the value at time T, send rd_enb at T-2
//                      and section_address at T-1
//////////////////////////////////////////////////////////////////////////////////

(* ram_style = "distributed" *)

module Stream_Buffer #(
        // Primary parameters
        parameter WIDTH = 128,               // Width of an entry in the stream buffer
        parameter DEPTH = 4,                 // Number of cache blocks that can be stored within the buffer
        parameter T     = 1,                 // 2^T is the number of stream buffer lines per cache block
        
        // Calculated parameters
        localparam ADDR_WIDTH     = logb2(DEPTH),
        localparam BLOCK_SECTIONS = 1 << T
    ) (
        input                      CLK,
        input                      ENB,
        input                      RESET,
        input      [T     - 1 : 0] SECTION_SEL,
        input                      RD_ENB,
        input                      WR_ENB,
        input      [WIDTH - 1 : 0] DATA_IN,
        output reg [WIDTH - 1 : 0] DATA_OUT,
        output                     EMPTY,
        output                     FULL
    );
    
    reg [WIDTH - 1 : 0] memory [0 : DEPTH * BLOCK_SECTIONS - 1];
    
    reg [ADDR_WIDTH     - 1 : 0] rd_counter;
    reg                          rd_counter_msb;
    reg [ADDR_WIDTH + T - 1 : 0] wr_counter;
    reg                          wr_counter_msb;
     
    assign FULL =  (rd_counter_msb != wr_counter_msb) & ({rd_counter, {T{1'b0}}} == wr_counter);
    assign EMPTY = ({rd_counter_msb, rd_counter, {T{1'b0}}} == {wr_counter_msb, wr_counter});
    
    always @(posedge CLK) begin
        if (RESET) begin
            rd_counter     <= 0;
            rd_counter_msb <= 0;
            wr_counter     <= 0;
            wr_counter_msb <= 0;
            
            DATA_OUT       <= 0;
        end else begin
            if (ENB) begin
                if (RD_ENB & !EMPTY) begin
                    {rd_counter_msb, rd_counter} <= {rd_counter_msb, rd_counter} + 1;
                end
                
                DATA_OUT <= memory[{rd_counter, SECTION_SEL}];
                
                if (WR_ENB & !FULL) begin
                    {wr_counter_msb, wr_counter} <= {wr_counter_msb, wr_counter} + 1;
                    memory[wr_counter] <= DATA_IN;
                end
            end
        end
    end
    
    initial begin
        rd_counter     = 0;
        rd_counter_msb = 0;
        wr_counter     = 0;
        wr_counter_msb = 0;
        
        DATA_OUT       = 0;
    end
    
    // Log value calculation
    function integer logb2;
        input integer depth;
        for (logb2 = 0; depth > 1; logb2 = logb2 + 1)
            depth = depth >> 1;
    endfunction
endmodule

/*
Stream_Buffer #(
    .DEPTH(),
    .WIDTH(),
    .T()
) stream_buffer (
    .CLK(),
    .RESET(),
    .SECTION_SEL(),
    .WR_ENB(),
    .RD_ENB(),
    .FULL(),
    .EMPTY(),
    .DATA_IN(),
    .DATA_OUT()
);
*/