`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: H.A.R.T Wijesekara
// 
// Create Date: 07/29/2016 12:45:35 PM
// Design Name: 
// Module Name: Test_Ins_Cache
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

module Test_Pipeline ();
    // Fixed parameters
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    
    // Primary parameters
    parameter S = 17;                    // Size of the cache will be 2^S bits
    parameter B = 9;                     // Size of a block will be 2^B bits
    parameter a = 1;                     // Associativity of the cache would be 2^a
    parameter T = 1;                     // Width to depth translation amount
    parameter W = 7;                     // Width of the L2-L1 bus would be 2^W
    parameter L2_DELAY = 7;
    parameter RAM_ADDR_WIDTH = 13;
    parameter RAM_DEPTH = 1 << RAM_ADDR_WIDTH;
    
    // Calculated parameters
    localparam L2_BUS_WIDTH = 1 << W;
    localparam L2_BURST = 1 << (B - W);
        
    // Constants
    reg TRUE = 1;
    reg FALSE = 0;    
        
    reg CLK;
    reg RSTN;
    
   // reg [ADDR_WIDTH - 1 : 0] BRANCH_ADDR_IN;
   // reg BRANCH;
    wire BRANCH_TAKEN;
    wire [ADDR_WIDTH - 1 : 0] BRANCH_ADDRESS;
    wire [DATA_WIDTH - 1 : 0] DATA_TO_PROC;
    wire [ADDR_WIDTH - 1 : 0] PC_TO_PROC;
    wire PROC_READY;
    wire CACHE_READY;
        
    wire [ADDR_WIDTH - 3 : 0] ADDR_TO_L2;
    wire ADDR_TO_L2_READY;
    wire ADDR_TO_L2_VALID;
        
    reg [L2_BUS_WIDTH - 1 : 0] DATA_FROM_L2;
//    reg PROC_READY_1;
    reg DATA_FROM_L2_VALID;
    wire DATA_FROM_L2_READY;
        
    Ins_Cache # (
        .S(S),
        .B(B),
        .a(a),
        .T(T),
        .W(W),
        .L2_DELAY(L2_DELAY)
    ) uut (
        .CLK(CLK),
        .RSTN(RSTN),
        
        .BRANCH_ADDR_IN(BRANCH_ADDRESS),
        .BRANCH(BRANCH_TAKEN),
        .DATA_TO_PROC(DATA_TO_PROC),
        .PC_TO_PROC(PC_TO_PROC),
        .CACHE_READY(CACHE_READY),
        .PROC_READY(PROC_READY),
                
        .ADDR_TO_L2(ADDR_TO_L2),
        .ADDR_TO_L2_READY(ADDR_TO_L2_READY),
        .ADDR_TO_L2_VALID(ADDR_TO_L2_VALID),
        
        .DATA_FROM_L2(DATA_FROM_L2),
        .DATA_FROM_L2_VALID(DATA_FROM_L2_VALID),
        .DATA_FROM_L2_READY(DATA_FROM_L2_READY)
    );
    
    reg [DATA_WIDTH - 1 : 0] ins_memory [0: RAM_DEPTH - 1];  
        
    integer fileTrace, readTrace;
    integer fileResult, writeResult;
    integer i, j, k, l;
    integer PC_no;
    
    
    reg read_address;
    initial begin
        CLK = 0;
        RSTN = 1;
        read_address = 0;
        //PROC_READY = 0;
        //BRANCH = 0;
        PC_no = 0;
        l2_ready = 1;
        fileTrace = $fopen("E:/University/GrandFinale/Project/Simulation_Traces/Pipeline/trace.txt", "r");
        fileResult = $fopen("E:/University/GrandFinale/Project/Simulation_Traces/Pipeline/result.txt", "w");
        $readmemh("E:/University/GrandFinale/Project/Simulation_Traces/Pipeline/Ins_Memory2.txt", ins_memory);
    //    $readmemh("E:/University/GrandFinale/Project/Simulation_Traces/TestPrograms/Reordered.txt", ins_memory);
                     
                     
        #106;
        RSTN = 1;
        //PROC_READY = 1;
        //BRANCH = 1;
        //readTrace = $fscanf(fileTrace, "%x ", BRANCH_ADDR_IN);
        #10;
        for (i = 0; i > -1; i = i + 1) begin
            if (read_address) begin
              // readTrace = $fscanf(fileTrace, "%x ", BRANCH_ADDR_IN);
                fileResult = $fopen("E:/University/GrandFinale/Project/Simulation_Traces/Pipeline/result.txt", "a");                        
                $fwrite(fileResult,"%x\n",DATA_TO_PROC);
                $fclose(fileResult);
                PC_no = PC_no + 1;
            end
            #10;
        end 
        
    end
    
    always @(posedge CLK ) begin
        read_address <= CACHE_READY & PROC_READY;
    end
    
    reg [L2_BURST - 1 : 0] l2_input_state;
    
    wire fifo_empty;    
    reg mem_requests [0 : L2_DELAY - 3];
    reg [ADDR_WIDTH - 3 : 0] mem_addresses [0 : L2_DELAY - 3];
        
    reg [ADDR_WIDTH - 1 : 0] output_addr_reg = 0;
    reg [L2_BURST - 1 : 0] output_data_state = 0;
    reg l2_ready;
        
    assign ADDR_TO_L2_READY = l2_ready & DATA_FROM_L2_READY;    
    
    always @(posedge CLK) begin
        if (DATA_FROM_L2_READY) begin
            mem_requests[0] <= ADDR_TO_L2_VALID && ADDR_TO_L2_READY;
            mem_addresses[0] <= ADDR_TO_L2;
            for (j = 1; j < L2_DELAY; j = j + 1) begin
                mem_requests[j] <= mem_requests[j - 1];
                mem_addresses[j] <= mem_addresses[j - 1];
            end
        
            if (ADDR_TO_L2_VALID && ADDR_TO_L2_READY) begin
                l2_ready <= 0;
                l2_input_state <= 1;           
            end else if (l2_input_state != 0) begin
                l2_input_state <= l2_input_state << 1;
            end
            
            if(l2_input_state[L2_BURST - 2]) begin
                l2_ready <= 1;
            end
            
            if (mem_requests[L2_DELAY - 3]) begin
                output_addr_reg <= {mem_addresses[L2_DELAY - 3], 2'b00};
                output_data_state <= 1;
            end else if (output_data_state != 0) begin
                output_data_state <= output_data_state << 1;
            end
            
            if (output_data_state != 0) begin            
                DATA_FROM_L2_VALID <= 1;
            end else begin
                DATA_FROM_L2_VALID <= 0;
            end
            
            for (k = 0; k < L2_BURST; k = k + 1) begin
                if (output_data_state[k] == 1) begin
                    for (l = 0; l < (1 << W - 5); l = l + 1) begin
                        DATA_FROM_L2[l * DATA_WIDTH +: DATA_WIDTH] <= ins_memory[{output_addr_reg[RAM_ADDR_WIDTH - 1 : 2 + B - W - T], {(B - W - T){1'b0}}} + {k, {(W - 5){1'b0}}}  + l];
                    end
                end
            end
        end      
    end
    
    always begin
        #5;
        CLK = !CLK;
    end
    
//    always@(PROC_READY)
//    begin
//        PROC_READY_1 = PROC_READY == 1'b1;
//    end
    // PIpeline 
    
    wire [31:0] ALU_OUT;
    wire COMPARE;
    
    
    PIPELINE uut2(
        .CLK(CLK),
        .PC_IF_ID(PC_TO_PROC), //IF out to ID in
        .INS_IF_ID(DATA_TO_PROC),
        .BRANCH_TAKEN(BRANCH_TAKEN),
        .BRANCH_ADDRESS(BRANCH_ADDRESS),
        .ALU(ALU_OUT),
        .COMPAR(COMPARE),
        .PIPELINE_STALL(PROC_READY)
        );
    
endmodule