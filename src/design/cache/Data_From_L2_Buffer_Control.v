`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/30/2016 07:31:47 PM
// Design Name: 
// Module Name: Data_From_L2_Buffer_Control
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


module Data_From_L2_Buffer_Control #(
        // Primary parameters
        parameter L2_BUS_WIDTH = 64,
        parameter BUFFER_WIDTH = 128
    ) (
        input CLK,
        input ENB,
        
        input DATA_FROM_L2_VALID,
        output DATA_FROM_L2_READY,
        
        input DATA_FROM_L2_BUFFER_READY,
        output DATA_FROM_L2_BUFFER_VALID,
        
        output [(BUFFER_WIDTH / L2_BUS_WIDTH) - 1 : 0] DATA_FROM_L2_BUFFER_ENB
    );
    
    reg [(BUFFER_WIDTH / L2_BUS_WIDTH) - 1 : 0] state;
    
    assign DATA_FROM_L2_BUFFER_ENB = (state == 0)? ((DATA_FROM_L2_BUFFER_READY & DATA_FROM_L2_VALID)? 1 : 0) : state;
    assign DATA_FROM_L2_BUFFER_VALID = (state == 0);
    assign DATA_FROM_L2_READY = ENB & ((state == 0) ? DATA_FROM_L2_BUFFER_READY : 1'b1);
    
    always @(posedge CLK) begin
        if (ENB) begin
            if (state == 0) begin
                if (DATA_FROM_L2_BUFFER_READY) begin
                    if (DATA_FROM_L2_VALID)
                        state <= 2;
                    else 
                        state <= 1;    
                end             
            end else begin 
                if (DATA_FROM_L2_VALID) begin
                    state <= state << 1;
                end
            end
        end
    end
    
    initial begin
        state = 1;
    end
    
endmodule

/*
Data_From_L2_Buffer_Control #(
    .L2_BUS_WIDTH(),
    .BUFFER_WIDTH()
) data_from_L2_buffer_control (
    .CLK(CLK),
    .DATA_FROM_L2_READY(),
    .DATA_FROM_L2_VALID(),
    .DATA_FROM_L2_BUFFER_READY(),
    .DATA_FROM_L2_BUFFER_VALID(),
    .DATA_FROM_L2_BUFFER_ENB(),
    .ONGOING_QUEUE_RD_ENB()
);
*/