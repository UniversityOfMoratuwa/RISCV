`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Moratuwa
// Engineer: Ravi Tharaka
// 
// Create Date: 09/11/2016 01:32:05 PM
// Design Name: 
// Module Name: Fetch_Queue
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A three register state machine to emulate a 1 clock latency
//              FWFT FIFO for storing the PC values to be sent to L2 cache
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Fetch_Queue #(
        // Primary parameters
        parameter WIDTH = 32
    ) (
        input CLK,
        input TOP_VALID,
        input BOT_READY,
        input [WIDTH - 1 : 0] DATA_IN,
        
        output EMPTY,
        output [WIDTH - 1 : 0] DATA_OUT
    );
    
    reg [WIDTH - 1 : 0] memory [0 : 2];
    reg [1 : 0] count;
    
    wire enb0, enb1, enb2, sel0, sel1;
    
    assign DATA_OUT = memory[0];
    assign EMPTY = (count == 2'b0);
    
    initial begin
        memory[0] = {WIDTH{1'b0}};
        memory[1] = {WIDTH{1'b0}};
        memory[2] = {WIDTH{1'b0}};
        count = 2'd0; 
    end
    
    // Managing the count (state variable)
    always @(posedge CLK) begin
        if ((TOP_VALID & !BOT_READY) & !(count == 2'd3)) begin
            count <= count + 1;
        end else if ((!TOP_VALID & BOT_READY) & !(count == 2'd0)) begin
            count <= count - 1;
        end
    end
    
    // Control
    assign enb0 = BOT_READY | (count == 2'b00);
    assign enb1 = BOT_READY | (count == 2'b01);
    assign enb2 = (BOT_READY & TOP_VALID) | (count == 2'b10);
    assign sel0 = (count == 2'b00) | (count == 2'b01);
    assign sel1 = (count == 2'b01) | (count == 2'b10);
    
    // Datapath
    always @(posedge CLK) begin
        if (enb0) begin
            if (sel0) 
                memory[0] <= DATA_IN;
            else
                memory[0] <= memory[1];
        end
        
        if (enb1) begin
            if (sel1) 
                memory[1] <= DATA_IN;
            else
                memory[1] <= memory[2];
        end
                
        if (enb2) begin
            memory[2] <= DATA_IN;           
        end                        
    end    
endmodule

//Fetch_Queue #(
//    .WIDTH()
//) your_instance (
//    .CLK(),
//    .TOP_VALID(),
//    .BOT_READY(),
//    .DATA_IN(),
//    .DATA_OUT(),
//    .EMPTY()
//);