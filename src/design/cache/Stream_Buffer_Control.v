`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2016 08:43:49 PM
// Design Name: 
// Module Name: Stream_Buffer_Control
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


module Stream_Buffer_Control #(
        // Primary parameters
        parameter N          = 3,                                            // Number of stream buffers
        parameter n          = 1,                                            // Depth of stream buffers would be 2^n 
        parameter ADDR_WIDTH = 26,                                           // Width needed to address a cache line
        parameter p          = 2,                                            // Prefetch queue's depth is 2^p
        parameter T          = 1,                                            // Width to depth translation amount for the Line Memory
        
        // Calculated parameters
        localparam STREAM_SEL_BITS  = logb2(N + 1)
                
    ) (
        input                                 CLK,
        input                                 ENB,
        
        // Data in for the stream buffers
        input      [STREAM_SEL_BITS  - 1 : 0] DATA_FROM_L2_SRC,           // From which source the current L2 data comes 
        output                                DATA_FROM_L2_BUFFER_READY,  // Infroms L2 data buffer that stream buffers are ready to sample the data
        input                                 DATA_FROM_L2_BUFFER_VALID,  // L2 data buffer informs that the data is ready for sampling
                    
        // Status and control of the stream buffers            
        output     [T                - 1 : 0] STREAM_BUF_SECTION_SEL,     // Which section in the stream buffer to read (common to all buffers)
        output     [N                - 1 : 0] STREAM_BUF_RESET,           // Resets each stream buffer (one per each buffer)
        output     [N                - 1 : 0] STREAM_BUF_WR_ENB,          // Write enable for the stream buffer (one per each buffer)
        output     [N                - 1 : 0] STREAM_BUF_RD_ENB,          // Read enable for the stream buffer (one per each buffer)
        input      [N                - 1 : 0] STREAM_BUF_FULL,            // Full signal from the stream buffer (one per each buffer)
        
        // Ongoing queue management
        output                                ONGOING_QUEUE_RD_ENB,       // Tells the ongoing queue that current data transfer was completed                        
                                   
        // Request queue management                           
        input                                 PREFETCH_QUEUE_FULL,        // Full signal from the prefetch queue
        output                                PREFETCH_QUEUE_WR_ENB,      // Write enable for the prefetch queue
        output     [ADDR_WIDTH       - 1 : 0] PREFETCH_QUEUE_ADDR,        // Request to be sent to L2
        output     [STREAM_SEL_BITS  - 1 : 0] PREFETCH_QUEUE_SRC,         // Which buffer is requesting (1,2,3,....N)
        
        // Main pipeline                     
        input      [ADDR_WIDTH + T   - 1 : 0] PC_IN,                      // PC to check whether it hits
        output reg                            HIT,                        // One of the stream buffers has hit
        output reg [STREAM_SEL_BITS  - 1 : 0] HIT_BUF_NO,                 // Which buffer has hit
        input                                 SECTION_COMMIT,             // For the current hit, a section was committed to LineRAM
        
        // Stream buffer allocation commands
        input                                 ALLOCATE,                   // Commands the stream buffers to allocate a new stream
        input      [ADDR_WIDTH       - 1 : 0] ALLOCATE_ADDR               // The address for the new allocation
    );
    
    //////////////////////////////////////////////////////////////////////////////
    // Sending data to the L1 cache                                             //
    //////////////////////////////////////////////////////////////////////////////
            
    // Hits if any of the stream buffers have a hit
    wire [N - 1 : 0] stream_buf_hit;  
    always @(posedge CLK) begin
        if (ENB) begin
            HIT <= |(stream_buf_hit & ~buffer_reset);
        end
    end
    
    // HIT_BUF_NO is the highest numbered buffer that has the required Cache Line
    integer j;
    always @(posedge CLK) begin
        if (ENB) begin
            for (j = 0; j < N; j = j + 1) begin
                if (stream_buf_hit[j]) begin
                    HIT_BUF_NO <= j + 1;
                end
            end
        end
    end     
    
    // FSM for stream buffer output
    reg [T - 1 : 0] output_state; 
    always @(posedge CLK) begin
        if (ENB) begin 
            if (SECTION_COMMIT) begin
                output_state <= output_state + 1;
            end
        end
    end
    
    // Which stream buffer is writing right now
    reg [N - 1 : 0] output_buffer;
    always @(posedge CLK) begin
        if (ENB) begin
            if (SECTION_COMMIT & output_state == 0) begin
                output_buffer <= stream_buf_hit;
            end
        end
    end
    
    // Delay the section address of PC one cycle
    reg [T - 1 : 0] section_delayed;
    always @(posedge CLK) begin
        if (ENB) begin
            section_delayed <= PC_IN[0 +: T];
        end
    end
    
    // Currently primed section
    wire current_section_enb = (output_state == 0 & !SECTION_COMMIT) | (output_state == N & SECTION_COMMIT);
    reg [T - 1 : 0] current_section;
    always @(posedge CLK) begin
        if (ENB) begin
            if (current_section_enb) begin
                current_section <= section_delayed;
            end 
        end
    end
    
    // Section select for the stream buffers
    assign STREAM_BUF_SECTION_SEL = (current_section_enb)? section_delayed : (current_section + SECTION_COMMIT + output_state);
    
    // Read enable for the stream buffers
    assign STREAM_BUF_RD_ENB = output_buffer & {N{SECTION_COMMIT & (output_state == {T{1'b1}})}};
    
    
    //////////////////////////////////////////////////////////////////////////////
    // Taking in data coming from L2 cache                                      //
    //////////////////////////////////////////////////////////////////////////////
    
    wire [N - 1 : 0] refill_enb;
    
    // Data from L2 buffer's ready signal
    assign DATA_FROM_L2_BUFFER_READY = (DATA_FROM_L2_SRC == 0)? 1'b0 : !STREAM_BUF_FULL[DATA_FROM_L2_SRC - 1];
    
    // FSM for stream buffer input
    reg [T - 1 : 0] refill_state;
    always @(posedge CLK) begin
        if (ENB) begin
            if (DATA_FROM_L2_BUFFER_READY & DATA_FROM_L2_BUFFER_VALID) begin
                refill_state <= refill_state + 1;   
            end
        end
    end
    
    // Once the data request cycle completes, (1) PREFETCH_COMMITED for one cycle (2) ONGOING_QUEUE_RD_ENB for one cycle
    wire [N - 1 : 0] prefetch_commited; 
    assign ONGOING_QUEUE_RD_ENB = (refill_state == {T{1'b1}}) & DATA_FROM_L2_BUFFER_READY & DATA_FROM_L2_BUFFER_VALID;
        
    // Tell the stream buffers to take in the data    
    genvar k;
    generate 
        for (k = 0; k < N; k = k + 1) begin
            assign STREAM_BUF_WR_ENB[k] = refill_enb[k] & DATA_FROM_L2_BUFFER_READY & DATA_FROM_L2_BUFFER_VALID & (k + 1 == DATA_FROM_L2_SRC);
        end
    endgenerate
    
    //////////////////////////////////////////////////////////////////////////////
    // Sending requests to prefetch queue                                       //
    //////////////////////////////////////////////////////////////////////////////
    
    wire [ADDR_WIDTH     - 1 : 0] next_request [0 : N - 1];
    wire [N              - 1 : 0] prefetch_requested;
    wire [N              - 1 : 0] prefetch_valid;
        
    reg [STREAM_SEL_BITS - 1 : 0] prefetch_state;
    
    always @(posedge CLK) begin
        if (ENB) begin
            if (prefetch_state == {STREAM_SEL_BITS{1'b1}}) begin
                prefetch_state <= 1;
            end else begin
                prefetch_state <= prefetch_state + 1;
            end
        end
    end
    
    assign PREFETCH_QUEUE_WR_ENB = !PREFETCH_QUEUE_FULL & prefetch_valid[prefetch_state - 1];
    assign PREFETCH_QUEUE_SRC    = prefetch_state;
    assign PREFETCH_QUEUE_ADDR   = next_request[prefetch_state - 1];
    
    //////////////////////////////////////////////////////////////////////////////
    // Allocating a stream buffer to new stream                                 //
    //////////////////////////////////////////////////////////////////////////////
            
    wire [N - 1 : 0] hit_commit;
    wire [N - 1 : 0] buffer_reset;
    wire [N - 1 : 0] lru;   
    wire [N - 1 : 0] used = hit_commit | buffer_reset;
    
    assign STREAM_BUF_RESET = buffer_reset;
       
    LRU #(
        .N(N)
    ) lru_unit (
        .CLK(CLK),
        .ENB(ENB),
        .USE(used),
        .LRU(lru)
    );
    
    genvar i;
    generate  
        for (i = 0; i < N; i = i + 1) begin : BUF_LOOP
            assign hit_commit[i]         = SECTION_COMMIT & (output_state == {T{1'b1}}) & output_buffer[i];
            assign buffer_reset[i]       = ALLOCATE & lru[i];
            assign prefetch_requested[i] = PREFETCH_QUEUE_WR_ENB & (i + 1 == prefetch_state);
            
            Stream_Buffer_Single_Control #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .p(p),
                .n(n)   
            ) stream_buffer_single_control (
                .CLK(CLK),
                .ENB(ENB),
                .BUFFER_RESET(buffer_reset[i]),
                .INIT_TOQ_VALUE(ALLOCATE_ADDR),
                .ADDR_IN(PC_IN[ADDR_WIDTH + T - 1 : T]),
                .STREAM_BUFFER_HIT(stream_buf_hit[i]),
                .HIT_COMMIT(hit_commit[i]),
                .PREFETCH_VALID(prefetch_valid[i]),
                .PREFETCH_REQUESTED(prefetch_requested[i]),
                .PREFETCH_COMMITED(refill_state == {T{1'b1}} & DATA_FROM_L2_BUFFER_READY & DATA_FROM_L2_BUFFER_VALID & (i + 1 == DATA_FROM_L2_SRC)),
                .REFILL_ENB(refill_enb[i]),
                .NEXT_REQ(next_request[i])
            );
        end
    endgenerate
    
    initial begin
        output_state = 0;
        HIT = 0;
        HIT_BUF_NO = 0;
        section_delayed = 0;
        current_section = 0;
        refill_state = 0;
        prefetch_state = 1;
    end
          
    // Log value calculation
    function integer logb2;
        input integer depth;
        for (logb2 = 0; depth > 1; logb2 = logb2 + 1)
            depth = depth >> 1;
    endfunction
   
endmodule
