`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2016 09:30:54 PM
// Design Name: 
// Module Name: Stream_Buffer_Single_Control
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


module Stream_Buffer_Single_Control #(
        // Primary parameters
        parameter ADDR_WIDTH = 5,                                   // Width needed to address a cache line
        parameter p          = 2,                                   // Prefetch queue's depth is 2^p
        parameter n          = 1                                    // Depth of stream buffers would be 2^n    
    ) (
        input                           CLK,
        input                           ENB,
        // Stream buffer initializations
        input                           BUFFER_RESET,               // Reset the stream buffer
        input      [ADDR_WIDTH - 1 : 0] INIT_TOQ_VALUE,             // New stream the buffer is assigned to
        // Stream buffer output side
        input      [ADDR_WIDTH - 1 : 0] ADDR_IN,                    // Address of the needed data
        output reg                      STREAM_BUFFER_HIT,          // Stream buffer has the needed data
        input                           HIT_COMMIT,                 // Commit a hit on the stream buffer, increase TOQ address
        // Stream buffer refill side
        output                          PREFETCH_VALID,             // Prefetch buffer is not yet full, so keep requesting from L2
        input                           PREFETCH_REQUESTED,         // Prefetch request was sent to prefetch queue
        input                           PREFETCH_COMMITED,          // Prefetch request was fulfilled by L2 
        output                          REFILL_ENB,                 // Commit the next data coming from L2
        output reg [ADDR_WIDTH - 1 : 0] NEXT_REQ                    // Next request that is to be sent to L2
    );    
    
    reg [ADDR_WIDTH - 1 : 0] top_of_queue;
    
    reg [n              : 0] request_counter;                       // Number of prefetch requests sent to prefetch queue
    reg [p          + 2 : 0] commit_counter;                        // Number of requests which has finished arriving
                                                                    // Negative commit means arriving data will be discarded
                                                                    
    assign REFILL_ENB = !commit_counter[p + 2];
    
    // Hit miss status of the stream buffer
    always @(posedge CLK) begin
        if (ENB) begin
            STREAM_BUFFER_HIT <= (ADDR_IN == top_of_queue) & (!commit_counter[p + 1]) & (commit_counter != 0) & !BUFFER_RESET;
        end
    end    
    
    // Next request to be sent to L2 to fill the stream buffer
    always @(posedge CLK) begin
        if (ENB) begin
            if (BUFFER_RESET) begin
                NEXT_REQ <= INIT_TOQ_VALUE;
            end else begin
                NEXT_REQ <= request_counter + top_of_queue;
            end
        end
    end
    
    // Top of queue management
    always @(posedge CLK) begin
        if (ENB) begin
            if (BUFFER_RESET) begin
                top_of_queue <= INIT_TOQ_VALUE;
            end else if (HIT_COMMIT) begin
                top_of_queue <= top_of_queue + 1;
            end
        end
    end  
    
    // Prefetch only needs to be requested if request counter < depth of stream buffer 
    assign PREFETCH_VALID = (request_counter[n] != 1'b1);
    
    // Request counter management
    reg [n : 0] request_counter_wire;
    always @(*) begin
        case ({PREFETCH_REQUESTED, HIT_COMMIT})
            2'b00 : request_counter_wire = request_counter;    
            2'b10 : request_counter_wire = request_counter + 1;         // When this happens, ALWAYS request_counter < 2^n
            2'b01 : request_counter_wire = request_counter - 1;
            2'b11 : request_counter_wire = request_counter;
        endcase
    end
    
    always @(posedge CLK) begin
        if (ENB) begin
            if (BUFFER_RESET) begin
                request_counter <= 0;
            end else begin
                request_counter <= request_counter_wire;
            end
        end
    end
    
    // Commit counter management
    always @(posedge CLK) begin
        if (ENB) begin
            if (BUFFER_RESET) begin
                if (PREFETCH_COMMITED)
                    commit_counter <= commit_counter - {{(p + 2 - n){1'b0}}, request_counter_wire} + 1;
                else    
                    commit_counter <= commit_counter - {{(p + 2 - n){1'b0}}, request_counter_wire};
            end else begin
                case ({PREFETCH_COMMITED, HIT_COMMIT})
                    2'b00 : commit_counter <= commit_counter;    
                    2'b10 : commit_counter <= commit_counter + 1;
                    2'b01 : commit_counter <= commit_counter - 1;
                    2'b11 : commit_counter <= commit_counter;
                endcase
            end
        end
    end
    
    initial begin
        top_of_queue = 0;
        request_counter = {n{1'b1}} + 1;
        commit_counter  = {n{1'b1}} + 1;
        
        NEXT_REQ = 0;
        STREAM_BUFFER_HIT = 0;
    end
    
endmodule
