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

module Test_Ins_Cache ();
    // Fixed parameters
    localparam ADDR_WIDTH   = 32;
    localparam DATA_WIDTH   = 32;
    
    // Primary parameters
    parameter S             = 17;                    // Size of the cache will be 2^S bits
    parameter B             = 9;                     // Size of a block will be 2^B bits
    parameter a             = 1;                     // Associativity of the cache would be 2^a
    parameter T             = 1;                     // Width to depth translation amount
    parameter W             = 7;                     // Width of the L2-L1 bus would be 2^W
    parameter L2_DELAY      = 7;
    
    // Calculated parameters
    localparam L2_BUS_WIDTH = 1 << W;
    localparam L2_BURST     = 1 << (B - W);
        
    // Constants
    reg TRUE                = 1;
    reg FALSE               = 0;    
        
    reg                         CLK;
    reg                         RSTN;
    
    reg  [ADDR_WIDTH   - 1 : 0] BRANCH_ADDR_IN;
    reg                         BRANCH;
    wire [DATA_WIDTH   - 1 : 0] DATA_TO_PROC;
    reg                         PROC_READY;
    wire                        CACHE_READY;
        
    wire [ADDR_WIDTH   - 3 : 0] ADDR_TO_L2;
    wire                        ADDR_TO_L2_READY;
    wire                        ADDR_TO_L2_VALID;
        
    reg  [L2_BUS_WIDTH - 1 : 0] DATA_FROM_L2;
    reg                         DATA_FROM_L2_VALID;
    wire                        DATA_FROM_L2_READY;
        
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
        // Towards processor
        .BRANCH_ADDR_IN(BRANCH_ADDR_IN),
        .BRANCH(BRANCH),
        .DATA_TO_PROC(DATA_TO_PROC),
        .CACHE_READY(CACHE_READY),
        .PROC_READY(PROC_READY),
        // Address port to L2
        .ADDR_TO_L2(ADDR_TO_L2),
        .ADDR_TO_L2_READY(ADDR_TO_L2_READY),
        .ADDR_TO_L2_VALID(ADDR_TO_L2_VALID),
        // Data read port to L2
        .DATA_FROM_L2(DATA_FROM_L2),
        .DATA_FROM_L2_VALID(DATA_FROM_L2_VALID),
        .DATA_FROM_L2_READY(DATA_FROM_L2_READY)
    );
    
    integer fileTrace, readTrace;
    integer fileResult, writeResult;
    integer i, j, k, l;
    integer PC_no;
    
    reg read_address;
    
    initial begin
        CLK          = 0;
        RSTN         = 1;
        read_address = 0;
        PROC_READY   = 0;
        BRANCH       = 0;
        PC_no        = 0;
        l2_ready     = 1;
        
        fileTrace    = $fopen("E:/University/GrandFinale/Project/riscv_fpga/Simulation/Instruction_Cache/trace.txt", "r");
        fileResult   = $fopen("E:/University/GrandFinale/Project/riscv_fpga/Simulation/Instruction_Cache/result.txt", "w");
        #106;
        
        RSTN         = 1;
        PROC_READY   = 1;
        BRANCH       = 1;
        readTrace    = $fscanf(fileTrace, "%x ", BRANCH_ADDR_IN);
        #10;
        
        for (i = 0; i > -1; i = i + 1) begin
            if (read_address) begin
                readTrace  = $fscanf(fileTrace, "%x ", BRANCH_ADDR_IN);
                fileResult = $fopen("E:/University/GrandFinale/Project/riscv_fpga/Simulation/Instruction_Cache/result.txt", "a");                        
                $fwrite(fileResult,"%x\n",DATA_TO_PROC);
                $fclose(fileResult);
                
                PC_no      = PC_no + 1;
            end
            #10;
            if (i % 20 == 0) begin
                PROC_READY = 0;     
            end else begin
                PROC_READY = 1;
            end
        end 
        
    end
    
    always @(posedge CLK) begin
        read_address <= CACHE_READY & PROC_READY;
    end
    
    reg  [L2_BURST   - 1 : 0] l2_input_state;
    
    wire                      fifo_empty;    
    reg                       mem_requests  [0 : L2_DELAY - 3];
    reg  [ADDR_WIDTH - 3 : 0] mem_addresses [0 : L2_DELAY - 3];
        
    reg  [ADDR_WIDTH - 1 : 0] output_addr_reg   = 0;
    reg  [L2_BURST   - 1 : 0] output_data_state = 0;
    reg                       l2_ready;
        
    assign ADDR_TO_L2_READY = l2_ready & DATA_FROM_L2_READY;    
    
    always @(posedge CLK) begin
        if (DATA_FROM_L2_READY) begin
            mem_requests[0]  <= ADDR_TO_L2_VALID && ADDR_TO_L2_READY;
            mem_addresses[0] <= ADDR_TO_L2;
            for (j = 1; j < L2_DELAY; j = j + 1) begin
                mem_requests[j]  <= mem_requests[j - 1];
                mem_addresses[j] <= mem_addresses[j - 1];
            end
        
            if (ADDR_TO_L2_VALID && ADDR_TO_L2_READY) begin
                l2_ready       <= 0;
                l2_input_state <= 1;           
            end else if (l2_input_state != 0) begin
                l2_input_state <= l2_input_state << 1;
            end
            
            if(l2_input_state[L2_BURST - 2]) begin
                l2_ready       <= 1;
            end
            
            if (mem_requests[L2_DELAY - 3]) begin
                output_addr_reg   <= {mem_addresses[L2_DELAY - 3], 2'b00};
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
                        DATA_FROM_L2[l * DATA_WIDTH         +:                    2] <= 2'b00;
                        DATA_FROM_L2[l * DATA_WIDTH + 2     +:                W - 5] <= l;
                        DATA_FROM_L2[l * DATA_WIDTH + W - 3 +:                B - W] <= {output_addr_reg[2 + W + T - 5 +: B - W - T], {(B - W - T){1'b0}} }+ k;
                        DATA_FROM_L2[l * DATA_WIDTH + B - 3 +: (ADDR_WIDTH + 3 - B)] <= output_addr_reg[ADDR_WIDTH - 1 : B - 3];
                    end
                end
            end
            
        end      
    end
    
    always begin
        CLK = #5 !CLK;
    end
    
endmodule