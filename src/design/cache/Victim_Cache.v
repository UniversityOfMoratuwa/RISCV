`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2017 02:16:43 PM
// Design Name: 
// Module Name: Victim_Cache
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

(* ram_style = "distributed" *)

module Victim_Cache #(
        // Fixed parameters
        localparam ADDR_WIDTH           = 32,
        localparam DATA_WIDTH           = 32,
        
        // Primary parameters
        parameter S                     = 17,                    // Size of the cache will be 2^S bits
        parameter B                     = 9,                     // Size of a block will be 2^B bits
        parameter a                     = 1,                     // Associativity of the cache would be 2^a
        parameter T                     = 1,                     // Width to depth translation amount
        parameter V                     = 2,                     // Size of the victim cache will be 2^V cache lines
        parameter W                     = 7,                     // Width of the L2-L1 bus would be 2^W
                
        // Calculated parameters
        localparam WORDS_PER_SECT       = B - T - 5,
        localparam L2_BUS_WIDTH         = 1 << W,
        localparam LINE_RAM_WIDTH       = 1 << (B - T),
        localparam VICTIM_CACHE_DEPTH   = 1 << V,
        
        localparam TAG_WIDTH            = ADDR_WIDTH + 3 + a - S,
        localparam TAG_ADDR_WIDTH       = S - a - B, 
        
        localparam SEARCH_ADDR_WIDTH    = TAG_WIDTH + TAG_ADDR_WIDTH + T,
        localparam ADDR_MEMORY_WIDTH    = TAG_WIDTH + TAG_ADDR_WIDTH,
        
        localparam BLOCK_SECTIONS   = 1 << T                
    ) (
        input                                  CLK,
        
        // Write port from L1 cache
        input      [LINE_RAM_WIDTH    - 1 : 0] DATA_FROM_L1,
        input      [SEARCH_ADDR_WIDTH - 1 : 0] ADDR_FROM_L1,
        input                                  DIRTY_FROM_L1,
        input                                  CONTROL_FROM_L1,
        input                                  WR_FROM_L1_VALID,
        output                                 WR_FROM_L1_READY,
        
        // Search port from L1 cache
        input      [SEARCH_ADDR_WIDTH - 1 : 0] SEARCH_ADDR,
        
        // Other specialized ports from L1
        input                                  VICTIM_COMMIT,               // Start sending a burst of data to L1, search disabled for the duration
        input                                  BYPASS,                      // Bypass the normal search procedure
        input      [V + T             - 1 : 0] BYPASS_ADDRESS,              // Next cycle's data out would be the values at bypass address
        
        // Ports back to L1 cache
        output reg                             VICTIM_HIT,
        output reg [V + T             - 1 : 0] HIT_ADDRESS,
        output reg [LINE_RAM_WIDTH    - 1 : 0] DATA_TO_L1,
        
        // Write port to L2
        input                                  WR_TO_L2_READY,
        output                                 WR_TO_L2_VALID,
        output reg [ADDR_WIDTH    - 2 - 1 : 0] WR_ADDR_TO_L2,
        output reg [L2_BUS_WIDTH      - 1 : 0] DATA_TO_L2,
        output reg                             WR_CONTROL_TO_L2,
        input                                  WR_COMPLETE
                
    );
    
    //////////////////////////////////////////////////////////////////////////////
    // Memories of the victim cache                                             //
    //////////////////////////////////////////////////////////////////////////////
        
    reg [LINE_RAM_WIDTH      - 1 : 0] data_memory [0 : VICTIM_CACHE_DEPTH * BLOCK_SECTIONS - 1];
    reg [ADDR_MEMORY_WIDTH   - 1 : 0] addr_memory [0 : VICTIM_CACHE_DEPTH                  - 1];
    reg                               ctrl_memory [0 : VICTIM_CACHE_DEPTH                  - 1];
        
    reg [VICTIM_CACHE_DEPTH  - 1 : 0] dirty;
    reg [VICTIM_CACHE_DEPTH  - 1 : 0] valid;
    reg [VICTIM_CACHE_DEPTH  - 1 : 0] valid_wire;
    
    wire                             victim_cache_empty;
    wire                             victim_cache_full;
    
    //////////////////////////////////////////////////////////////////////////////
    // Searching whether an address has hit                                     //
    //////////////////////////////////////////////////////////////////////////////
            
    // Check equality with the provided SEARCH_ADDR
    reg [VICTIM_CACHE_DEPTH - 1 : 0] equality; 
    
    integer i;
    always @(posedge CLK) begin
        for (i = 0; i < VICTIM_CACHE_DEPTH; i = i + 1) begin
            equality[i] <= (addr_memory[i] == SEARCH_ADDR[SEARCH_ADDR_WIDTH - 1 : T]) & valid_wire[i];
        end
    end
    
    // Delay the section address of the SEARCH_ADDR
    reg [T - 1 : 0] sect_address;  
    
    always @(posedge CLK) begin
        sect_address <= SEARCH_ADDR[0 +: T];
    end
        
    // Convert the one-hot type encoding of equality to binary
    reg [V - 1 : 0] hit_address;
    //reg [V - 1 : 0] temp;
    
    integer j;
    always @(*) begin
        case (victim_wr_pos)
            2'b00 : case (equality)
                        4'b0000 : hit_address = 0;
                        4'b0001 : hit_address = 0;
                        4'b0010 : hit_address = 1;
                        4'b0011 : hit_address = 0;
                        4'b0100 : hit_address = 2;
                        4'b0101 : hit_address = 0;
                        4'b0110 : hit_address = 2;
                        4'b0111 : hit_address = 0;
                        4'b1000 : hit_address = 3;
                        4'b1001 : hit_address = 0;
                        4'b1010 : hit_address = 3;
                        4'b1011 : hit_address = 0;
                        4'b1100 : hit_address = 3;
                        4'b1101 : hit_address = 0;
                        4'b1110 : hit_address = 3;
                        4'b1111 : hit_address = 0;
                    endcase      
            2'b01 : case (equality)
                        4'b0000 : hit_address = 0;
                        4'b0001 : hit_address = 0;
                        4'b0010 : hit_address = 1;
                        4'b0011 : hit_address = 1;
                        4'b0100 : hit_address = 2;
                        4'b0101 : hit_address = 0;
                        4'b0110 : hit_address = 1;
                        4'b0111 : hit_address = 1;
                        4'b1000 : hit_address = 3;
                        4'b1001 : hit_address = 0;
                        4'b1010 : hit_address = 1;
                        4'b1011 : hit_address = 1;
                        4'b1100 : hit_address = 3;
                        4'b1101 : hit_address = 0;
                        4'b1110 : hit_address = 1;
                        4'b1111 : hit_address = 1;
                    endcase      
            2'b10 : case (equality)
                        4'b0000 : hit_address = 0;
                        4'b0001 : hit_address = 0;
                        4'b0010 : hit_address = 1;
                        4'b0011 : hit_address = 1;
                        4'b0100 : hit_address = 2;
                        4'b0101 : hit_address = 2;
                        4'b0110 : hit_address = 2;
                        4'b0111 : hit_address = 2;
                        4'b1000 : hit_address = 3;
                        4'b1001 : hit_address = 0;
                        4'b1010 : hit_address = 1;
                        4'b1011 : hit_address = 1;
                        4'b1100 : hit_address = 2;
                        4'b1101 : hit_address = 2;
                        4'b1110 : hit_address = 2;
                        4'b1111 : hit_address = 2;
                    endcase      
            2'b11 : case (equality)
                        4'b0000 : hit_address = 0;
                        4'b0001 : hit_address = 0;
                        4'b0010 : hit_address = 1;
                        4'b0011 : hit_address = 1;
                        4'b0100 : hit_address = 2;
                        4'b0101 : hit_address = 2;
                        4'b0110 : hit_address = 2;
                        4'b0111 : hit_address = 2;
                        4'b1000 : hit_address = 3;
                        4'b1001 : hit_address = 3;
                        4'b1010 : hit_address = 3;
                        4'b1011 : hit_address = 3;
                        4'b1100 : hit_address = 3;
                        4'b1101 : hit_address = 3;
                        4'b1110 : hit_address = 3;
                        4'b1111 : hit_address = 3;
                    endcase              
        endcase
        /*        
        if (|equality)
            for (j = 0; j < VICTIM_CACHE_DEPTH; j = j + 1) begin
                temp = victim_wr_pos + j + 1;
                if (equality[temp]) begin
                    hit_address = temp;
                end else begin
                    hit_address = hit_address;
                end
            end
        else begin
            hit_address = 0;
        end*/
    end
    
    // Victim hit if any of the entries are equal to the SEARCH_ADDR
    wire victim_hit = |(equality);
    
    always @(posedge CLK) begin
        VICTIM_HIT  <= victim_hit;
        HIT_ADDRESS <= {hit_address, sect_address};
    end
    
    // States for sending data burst to L1
    reg [T - 1 : 0] burst_state;
    
    always @(posedge CLK) begin
        if (VICTIM_COMMIT) begin
            burst_state <= 2;            
        end else begin
            if (burst_state != 0) begin
                burst_state <= burst_state + 1;
            end 
        end
    end
    
    // If hit, DATA_TO_L1 register should be filled from the data_memory
    reg [T - 1 : 0] sect_sel_del_1;
    reg [V - 1 : 0] hit_addr_del_1;
    
    reg [T - 1 : 0] sect_sel_in_burst;
    reg [V - 1 : 0] hit_addr_in_burst;
    
    wire [T     - 1 : 0] sect_addr_in_commit = sect_sel_del_1 + 1;
    wire [T     - 1 : 0] sect_addr_in_burst  = sect_address   + burst_state;
      
    wire [V + T - 1 : 0] data_sel            = {hit_address, sect_address}; 
    wire [V + T - 1 : 0] data_sel_in_commit  = {hit_addr_del_1, sect_addr_in_commit}; 
    wire [V + T - 1 : 0] data_sel_in_burst   = {hit_addr_in_burst, sect_sel_in_burst}; 
             
    always @(posedge CLK) begin
        {hit_addr_del_1, sect_sel_del_1} <= (BYPASS) ? BYPASS_ADDRESS : {hit_address, sect_address};
        
        if (VICTIM_COMMIT) begin
            {hit_addr_in_burst, sect_sel_in_burst} <= {hit_addr_del_1, sect_sel_del_1};
        end
        
        if (BYPASS) 
            DATA_TO_L1 <= data_memory[BYPASS_ADDRESS];
        else
            case ({VICTIM_COMMIT, victim_hit, burst_state != 0})
                3'b000  : DATA_TO_L1 <= DATA_TO_L1;           
                3'b001  : DATA_TO_L1 <= data_memory[data_sel_in_burst];   
                3'b010  : DATA_TO_L1 <= data_memory[data_sel]; 
                3'b011  : DATA_TO_L1 <= data_memory[data_sel_in_burst]; 
                  
                default : DATA_TO_L1 <= data_memory[data_sel_in_commit]; 
            endcase  
    end
    
    //////////////////////////////////////////////////////////////////////////////
    // Writing data to victim cache                                             //
    //////////////////////////////////////////////////////////////////////////////
     
    reg  [V - 1 : 0] victim_wr_pos;
    reg              victim_wr_pos_msb;
    reg  [T - 1 : 0] victim_wr_state;
    
    wire [V - 1 : 0] victim_wr_pos_plus_2 = victim_wr_pos + 2;
    
    // READY means that it is ready to take on a cache block section
    assign WR_FROM_L1_READY = !victim_cache_full;
    
    // A write operation takes 2^T clock cycles
    always @(posedge CLK) begin
        if (WR_FROM_L1_VALID & WR_FROM_L1_READY) begin
            victim_wr_state <= victim_wr_state + 1;
        end
    end
    
    // The data is written according to victim_wr_addr and victim_wr_state
    always @(posedge CLK) begin
        if (WR_FROM_L1_VALID & WR_FROM_L1_READY) begin
            // Updates the tag memories at the first stage (dirty bit written further below in code)
            if (victim_wr_state == 0) begin
                addr_memory[victim_wr_pos] <= ADDR_FROM_L1[SEARCH_ADDR_WIDTH - 1  : T];
                ctrl_memory[victim_wr_pos] <= CONTROL_FROM_L1;
                
                // Valid bit is turned off for the next write position and turned on for the current
                valid[victim_wr_pos_plus_2] <= 1'b0;
                valid[victim_wr_pos]        <= 1'b1;                                
            end
            
            // Last part (section address) is taken directly from ADDR_FROM_L1
            data_memory[{victim_wr_pos, ADDR_FROM_L1[0 +: T]}] <= DATA_FROM_L1;
            
            // At the last stage of the write 
            if (victim_wr_state == {T{1'b1}}) begin
                // Write position shifts to the next value
                {victim_wr_pos_msb, victim_wr_pos} <= {victim_wr_pos_msb, victim_wr_pos} + 1;
            end
        end
    end
    
    integer k;
    always @(*) begin
        if (WR_FROM_L1_VALID & WR_FROM_L1_READY & victim_wr_state == 0) begin
            for (k = 0; k < VICTIM_CACHE_DEPTH; k = k + 1) begin
                // Valid bit is turned off for the next write position and turned on for the current
                if (k == victim_wr_pos) 
                    valid_wire[k] = 1'b1;
                else if (k == victim_wr_pos_plus_2)
                    valid_wire[k] = 1'b0;
                else 
                    valid_wire[k] = valid[k];
            end
        end else begin
            valid_wire = valid;
        end
    end
        
    //////////////////////////////////////////////////////////////////////////////
    // Writing data to L2 cache                                                 //
    //////////////////////////////////////////////////////////////////////////////
    
    reg [V                  - 1 : 0] victim_rd_pos;
    reg                              victim_rd_pos_msb;
    
    // A write operation takes 2^(B - W) clock cycles
    reg [B - W              - 1 : 0] victim_rd_state;
    
    // Buffers for storing the write request to L2, status and control signals
    reg                              L2_wr_buf_full;
    wire                             L2_wr_buf_ready; 
    wire                             L2_wr_buf_valid; 
           
        
    // Starting and finishing a read
    localparam IDLE    = 0;
    localparam READING = 1;
    localparam WAITING = 2;
    
    reg [1 : 0] rd_overall_state;
    
    // Write state management
    always @(posedge CLK) begin
        case (rd_overall_state)
            IDLE    : if (!victim_cache_empty & dirty[victim_rd_pos])
                         rd_overall_state <= READING;
            READING : if (victim_rd_state == {(B - W){1'b1}} & L2_wr_buf_ready & L2_wr_buf_valid)
                         rd_overall_state <= WAITING;
            WAITING : if (WR_COMPLETE)
                         rd_overall_state <= IDLE;
        endcase
        
        if (L2_wr_buf_ready & L2_wr_buf_valid) begin
            victim_rd_state <= victim_rd_state + 1;
        end
        
        if ((!victim_cache_empty & !dirty[victim_rd_pos]) | WR_COMPLETE) begin
            // Read position shifts to the next value
            {victim_rd_pos_msb, victim_rd_pos} <= {victim_rd_pos_msb, victim_rd_pos} + 1;
        end
    end
    
    assign L2_wr_buf_valid = !victim_cache_empty & dirty[victim_rd_pos] & !(rd_overall_state == WAITING);
    assign L2_wr_buf_ready = !L2_wr_buf_full | WR_TO_L2_READY; 
    assign WR_TO_L2_VALID  = L2_wr_buf_full;
         
    
    // Wires for the L2 write request
    wire                             control_to_L2;
    wire [ADDR_WIDTH    - 2 - 1 : 0] wr_addr_to_L2;
    wire [L2_BUS_WIDTH      - 1 : 0] data_to_L2;
            
    assign wr_addr_to_L2 = {addr_memory[victim_rd_pos], {(ADDR_WIDTH - 2 - ADDR_MEMORY_WIDTH){1'b0}}};
    assign control_to_L2 = ctrl_memory[victim_rd_pos];
    
    assign data_to_L2 = data_memory[{victim_rd_pos, victim_rd_state[B - W - 1 -: T]}][L2_BUS_WIDTH * victim_rd_state[B - W - T - 1 : 0] +: L2_BUS_WIDTH];
            
    always @(posedge CLK) begin
        // Write data, control and data registers for the L2 cache
        if ((L2_wr_buf_valid & WR_TO_L2_READY) | (!L2_wr_buf_full & L2_wr_buf_valid)) begin
            WR_ADDR_TO_L2 <= wr_addr_to_L2;
            WR_CONTROL_TO_L2 <= control_to_L2;
            
            DATA_TO_L2 <= data_to_L2;            
        end
        
        // Full state management
        if (L2_wr_buf_valid) begin
            L2_wr_buf_full <= 1;
        end else if (WR_TO_L2_READY) begin 
            L2_wr_buf_full <= 0;
        end
    end
    
    
    //////////////////////////////////////////////////////////////////////////////
    // Managing dirty bits, empty and full status                               //
    //////////////////////////////////////////////////////////////////////////////
    
    // Full is when read counter and write counter differs by V
    assign victim_cache_full  = (victim_rd_pos == victim_wr_pos) & (victim_rd_pos_msb != victim_wr_pos_msb);
    // Empty is when read counter and write counter is equal
    assign victim_cache_empty = (victim_rd_pos == victim_wr_pos) & (victim_rd_pos_msb == victim_wr_pos_msb);
    
    always @(posedge CLK) begin
        // Dirty status is put up when starting being written 
        if (WR_FROM_L1_VALID & WR_FROM_L1_READY & victim_wr_state == 0) begin
            dirty[victim_wr_pos] <= DIRTY_FROM_L1;
        end 
        
        // Dirty status is put down when L2 cache has completed recieving the block  
        else if (WR_COMPLETE) begin
           dirty[victim_rd_pos] <= 1'b0;           
        end
    end
    
    
    //////////////////////////////////////////////////////////////////////////////
    // Initial values                                                           //
    //////////////////////////////////////////////////////////////////////////////
    
    initial begin
        
        VICTIM_HIT        = 0;
        victim_wr_state   = 0;
        victim_wr_pos     = 0;
        victim_wr_pos_msb = 0;
        
        burst_state       = 0;
        
        rd_overall_state  = 0;
        victim_rd_state   = 0;
        victim_rd_pos     = 0;
        victim_rd_pos_msb = 0;
        
        L2_wr_buf_full    = 0;
        
        for (i = 0; i < VICTIM_CACHE_DEPTH * BLOCK_SECTIONS; i = i + 1) begin
            data_memory[i] = 0;
        end
        
       for (i = 0; i < VICTIM_CACHE_DEPTH; i = i + 1) begin 
            addr_memory[i] = 0;
            ctrl_memory[i] = 0;
            valid[i]       = 0;
            dirty[i]       = 0;
            equality[i]    = 0;
        end    
        
    end   
endmodule
