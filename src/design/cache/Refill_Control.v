`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/27/2016 12:24:16 PM
// Design Name: 
// Module Name: Refill_Control
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


module Refill_Control_I #(
        // Fixed parameters
        localparam ADDR_WIDTH       = 32,
        
        // Primary parameters
        parameter S                 = 17, 
        parameter B                 = 9, 
        parameter a                 = 1,
        parameter N                 = 3,
        parameter T                 = 1,
        
        // Derived parameters
        localparam TAG_WIDTH        = ADDR_WIDTH + 3 + a - S,
        localparam TAG_ADDR_WIDTH   = S - a - B,
        localparam STREAM_SEL_BITS  = logb2(N + 1),
        localparam BLOCK_SECTIONS   = 1 << T,
        localparam ASSOCIATIVITY    = 1 << a,
        localparam LINE_ADDR_WIDTH  = S - a - B + T
    ) (
        input                           CLK,
        input                           ENB,
                
        // Outputs to the main processor pipeline		
        output CACHE_READY,                                             // Signal from cache to processor that its pipeline is currently ready to work     
        
        // Current request at IF3
        input                           CACHE_HIT,                      // Whether the L1 cache hits or misses 
        input                           STREAM_HIT,                     // Whether any of the stream buffers hit
        input [ASSOCIATIVITY   - 1 : 0] CACHE_SRC,                      // Which set is hitting, garbage if it doesn't
        input [STREAM_SEL_BITS - 1 : 0] STREAM_SRC,                     // Which stream buffer is hitting, garbage if it doesn't
        input [TAG_WIDTH       - 1 : 0] REFILL_REQ_TAG,                 // Tag portion of the PC at IF3
        input [TAG_ADDR_WIDTH  - 1 : 0] REFILL_REQ_LINE,                // Line portion of the PC at IF3
        input [T               - 1 : 0] REFILL_REQ_SECT,                // Section portion of the PC at IF3
        
        // Current request at IF2
        input [TAG_WIDTH       - 1 : 0] REFILL_REQ_TAG_PREV,            // Tag portion of the PC at IF2
        input [TAG_ADDR_WIDTH  - 1 : 0] REFILL_REQ_LINE_PREV,           // Line portion of the PC at IF2
        
        // Signals coming from outside the cache
        input                           BRANCH,                         // Branch command from EXE stage
                
        // Command fetch queue to send current IF3 address to L2
        output                          SEND_ADDR_TO_L2,
        
        // Data coming back from L2
        input [STREAM_SEL_BITS - 1 : 0] DATA_FROM_L2_SRC,
        input                           DATA_FROM_L2_BUFFER_VALID,
        output                          DATA_FROM_L2_BUFFER_READY,
        output                          ONGOING_QUEUE_RD_ENB,
        
        // Prefetch controller
        output                          SECTION_COMMIT,
        
        // Tag memories and line memories
        output [ASSOCIATIVITY   - 1 : 0] TAG_MEM_WR_ENB,                // Individual write enables for the tag memories
        output [TAG_ADDR_WIDTH  - 1 : 0] TAG_MEM_WR_ADDR,               // Common write address for the the tag memories 
        output [TAG_WIDTH       - 1 : 0] TAG_MEM_TAG_IN,                // Common data in for the tag memories    
        output [BLOCK_SECTIONS  - 1 : 0] TAG_MEM_TAG_VALID_IN,          // Common data in for the tag memories   
        output [ASSOCIATIVITY   - 1 : 0] LIN_MEM_WR_ENB,                // Individual write enables for the line memories
        output [LINE_ADDR_WIDTH - 1 : 0] LIN_MEM_WR_ADDR,               // Common write address for the line memories                  
        output [STREAM_SEL_BITS - 1 : 0] LIN_MEM_DATA_IN_SEL,           // 0 for L2 requests, buffer number for others
         
        // Enable and PC select for the PC (main processor) pipeline
        output                           PC_PIPE_ENB,                   // Enable for the main pipeline 
        output [1                   : 0] PC_SEL                         // Mux select for PC [pc_sel = {0(PC + 4), 1(Branch path), 2 or 3(PC delay 2)}]  
    );
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Globally important figures                                                                  //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    
    reg  critical_ready;                             // The critical word currently being pushed into L1 and ready
    wire critical_use;                               // Last critical word currently being used so next request can be started
    reg  critical_used;                              // Critical word is used
    
    // If the stream buffers doesn't hit, it means a priority address request to L2 (src == 00)
    wire [STREAM_SEL_BITS - 1 : 0] refill_req_src = (STREAM_HIT)? STREAM_SRC : 0;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Calculating the destination of the refill request                                            //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Temporary - cycle destinations among the available sets
    reg [ASSOCIATIVITY - 1 : 0] refill_req_dst = 2, refill_req_dst_del_1 = 1;
    always @(posedge CLK) begin             
        if (ENB) begin
            if (admit) begin
                if (refill_req_dst [ASSOCIATIVITY - 1])
                    refill_req_dst <= 1;
                else
                    refill_req_dst <= refill_req_dst << 1;    
                refill_req_dst_del_1 <= refill_req_dst;
            end
        end
    end         
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Refill request queue management                                                              //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    // PCs of the currently being fetched requests are stored. Max number of requests is 4.
    // Three is for IF1, IF2, IF3 and last is for early restart
    reg [TAG_WIDTH      - 1 : 0] cur_tag,  fir_tag,  sec_tag,  thr_tag;
    reg [TAG_ADDR_WIDTH - 1 : 0] cur_line, fir_line, sec_line, thr_line;
    reg [T              - 1 : 0] cur_sect, fir_sect, sec_sect, thr_sect;
    
    reg [TAG_WIDTH      - 1 : 0] cur_tag_wire,  fir_tag_wire,  sec_tag_wire,  thr_tag_wire;
    reg [TAG_ADDR_WIDTH - 1 : 0] cur_line_wire, fir_line_wire, sec_line_wire, thr_line_wire;
    reg [T              - 1 : 0] cur_sect_wire, fir_sect_wire, sec_sect_wire, thr_sect_wire;
    
    // Set = destination set of the request, Source = which stream buffer (or L2) the request is coming from
    reg [STREAM_SEL_BITS - 1 : 0] cur_src,  fir_src,  sec_src,  thr_src;
    reg [ASSOCIATIVITY   - 1 : 0] cur_set,  fir_set,  sec_set,  thr_set;
    
    reg [STREAM_SEL_BITS - 1 : 0] cur_src_wire,  fir_src_wire,  sec_src_wire,  thr_src_wire;
    reg [ASSOCIATIVITY   - 1 : 0] cur_set_wire,  fir_set_wire,  sec_set_wire,  thr_set_wire;
    
    // To get admitted to the refill queue, several tests must be passed, and also it mustn't readmit a completed refill
    // (L2 misses, PC pipe disables, IF pipe saturated with PC value, L2 completes and removes from queue, but still IF pipe
    // saturated, this causes a miss, and readmit)
    
    // Solution - Admission only if the IF3 request came from a valid PC on the PC pipeline
    reg         pc_pipe_enb_del_1;
    reg [1 : 0] pc_sel_del_1;
    reg [1 : 0] pc_sel_del_2;
    reg         pc_admissible;
    
    always @(posedge CLK) begin
        if (ENB) begin
            pc_pipe_enb_del_1 <= PC_PIPE_ENB;
            pc_sel_del_1      <= PC_SEL;
            pc_sel_del_2      <= pc_sel_del_1;
            pc_admissible     <= pc_pipe_enb_del_1 & (pc_sel_del_2 == 2'b00 | pc_sel_del_2 == 2'b01);
        end
    end    
    
    // Whether to admit to or remove from the refill queue
    wire admit, remove;
    reg test_pass;
    assign admit = test_pass & pc_admissible;
    
    // Number of elements in the queue
    reg [3 : 0] no_of_elements, no_of_elements_wire;
    
    always @(posedge CLK) begin
        if (ENB) begin
            no_of_elements <= no_of_elements_wire;
        end
    end
    
    always @(*) begin
        case ({admit, remove})
            2'b00 : no_of_elements_wire = no_of_elements;
            2'b01 : no_of_elements_wire = no_of_elements >> 1;
            2'b10 : no_of_elements_wire = (no_of_elements << 1) | 4'b0001;
            2'b11 : no_of_elements_wire = no_of_elements;
        endcase
    end
    
    // Basically a queue, but each element is accessible to the outside, to run the tests
    always @(*) begin
        case ({admit, remove})
            2'b10 : begin
                cur_tag_wire  = (no_of_elements == 4'b0000)? REFILL_REQ_TAG  : cur_tag;
                cur_line_wire = (no_of_elements == 4'b0000)? REFILL_REQ_LINE : cur_line;
                cur_sect_wire = (no_of_elements == 4'b0000)? REFILL_REQ_SECT : cur_sect;
                cur_src_wire  = (no_of_elements == 4'b0000)? refill_req_src  : cur_src;
                cur_set_wire  = (no_of_elements == 4'b0000)? refill_req_dst_del_1  : cur_set;
                
                fir_tag_wire  = (no_of_elements == 4'b0001)? REFILL_REQ_TAG  : fir_tag;
                fir_line_wire = (no_of_elements == 4'b0001)? REFILL_REQ_LINE : fir_line;
                fir_sect_wire = (no_of_elements == 4'b0001)? REFILL_REQ_SECT : fir_sect;
                fir_src_wire  = (no_of_elements == 4'b0001)? refill_req_src  : fir_src;
                fir_set_wire  = (no_of_elements == 4'b0001)? refill_req_dst_del_1  : fir_set;
                
                sec_tag_wire  = (no_of_elements == 4'b0011)? REFILL_REQ_TAG  : sec_tag;
                sec_line_wire = (no_of_elements == 4'b0011)? REFILL_REQ_LINE : sec_line;
                sec_sect_wire = (no_of_elements == 4'b0011)? REFILL_REQ_SECT : sec_sect;
                sec_src_wire  = (no_of_elements == 4'b0011)? refill_req_src  : sec_src;
                sec_set_wire  = (no_of_elements == 4'b0011)? refill_req_dst_del_1  : sec_set;
                
                thr_tag_wire  = (no_of_elements == 4'b0111)? REFILL_REQ_TAG  : thr_tag;
                thr_line_wire = (no_of_elements == 4'b0111)? REFILL_REQ_LINE : thr_line;
                thr_sect_wire = (no_of_elements == 4'b0111)? REFILL_REQ_SECT : thr_sect;
                thr_src_wire  = (no_of_elements == 4'b0111)? refill_req_src  : thr_src;
                thr_set_wire  = (no_of_elements == 4'b0111)? refill_req_dst_del_1  : thr_set;
            end
            2'b01 : begin
                cur_tag_wire  = fir_tag;
                cur_line_wire = fir_line;
                cur_sect_wire = fir_sect;
                cur_src_wire  = fir_src;
                cur_set_wire  = fir_set;
                
                fir_tag_wire  = sec_tag;
                fir_line_wire = sec_line;
                fir_sect_wire = sec_sect;
                fir_src_wire  = sec_src;
                fir_set_wire  = sec_set;
                
                sec_tag_wire  = thr_tag;
                sec_line_wire = thr_line;
                sec_sect_wire = thr_sect;
                sec_src_wire  = thr_src;
                sec_set_wire  = thr_set;
                
                thr_tag_wire  = 0;
                thr_line_wire = 0;
                thr_sect_wire = 0;
                thr_src_wire  = 0;
                thr_set_wire  = 0;
            end
            2'b11 : begin
                cur_tag_wire  = (no_of_elements == 4'b0001)? REFILL_REQ_TAG  : fir_tag;
                cur_line_wire = (no_of_elements == 4'b0001)? REFILL_REQ_LINE : fir_line;
                cur_sect_wire = (no_of_elements == 4'b0001)? REFILL_REQ_SECT : fir_sect;
                cur_src_wire  = (no_of_elements == 4'b0001)? refill_req_src  : fir_src;
                cur_set_wire  = (no_of_elements == 4'b0001)? refill_req_dst_del_1  : fir_set;
                
                fir_tag_wire  = (no_of_elements == 4'b0011)? REFILL_REQ_TAG  : sec_tag;
                fir_line_wire = (no_of_elements == 4'b0011)? REFILL_REQ_LINE : sec_line;
                fir_sect_wire = (no_of_elements == 4'b0011)? REFILL_REQ_SECT : sec_sect;
                fir_src_wire  = (no_of_elements == 4'b0011)? refill_req_src  : sec_src;
                fir_set_wire  = (no_of_elements == 4'b0011)? refill_req_dst_del_1  : sec_set;
                
                sec_tag_wire  = (no_of_elements == 4'b0111)? REFILL_REQ_TAG  : thr_tag;
                sec_line_wire = (no_of_elements == 4'b0111)? REFILL_REQ_LINE : thr_line;
                sec_sect_wire = (no_of_elements == 4'b0111)? REFILL_REQ_SECT : thr_sect;
                sec_src_wire  = (no_of_elements == 4'b0111)? refill_req_src  : thr_src;
                sec_set_wire  = (no_of_elements == 4'b0111)? refill_req_dst_del_1  : thr_set;
                
                thr_tag_wire  = (no_of_elements == 4'b1111)? REFILL_REQ_TAG  : 0;
                thr_line_wire = (no_of_elements == 4'b1111)? REFILL_REQ_LINE : 0;
                thr_sect_wire = (no_of_elements == 4'b1111)? REFILL_REQ_SECT : 0;
                thr_src_wire  = (no_of_elements == 4'b1111)? refill_req_src  : 0;
                thr_set_wire  = (no_of_elements == 4'b1111)? refill_req_dst_del_1  : 0;
            end
            2'b00 : begin
                cur_tag_wire  = cur_tag;
                cur_line_wire = cur_line;
                cur_sect_wire = cur_sect;
                cur_src_wire  = cur_src;
                cur_set_wire  = cur_set;
                
                fir_tag_wire  = fir_tag;
                fir_line_wire = fir_line;
                fir_sect_wire = fir_sect;
                fir_src_wire  = fir_src;
                fir_set_wire  = fir_set;
                
                sec_tag_wire  = sec_tag;
                sec_line_wire = sec_line;
                sec_sect_wire = sec_sect;
                sec_src_wire  = sec_src;
                sec_set_wire  = sec_set;
                
                thr_tag_wire  = thr_tag;
                thr_line_wire = thr_line;
                thr_sect_wire = thr_sect;
                thr_src_wire  = thr_src;
                thr_set_wire  = thr_set;
            end
        endcase
    end
    
    always @(posedge CLK) begin
        if (ENB) begin
            cur_tag  <= cur_tag_wire;
            cur_line <= cur_line_wire;
            cur_sect <= cur_sect_wire;
            cur_src  <= cur_src_wire;
            cur_set  <= cur_set_wire;
            
            fir_tag  <= fir_tag_wire;
            fir_line <= fir_line_wire;
            fir_sect <= fir_sect_wire;
            fir_src  <= fir_src_wire;
            fir_set  <= fir_set_wire;
            
            sec_tag  <= sec_tag_wire;
            sec_line <= sec_line_wire;
            sec_sect <= sec_sect_wire;
            sec_src  <= sec_src_wire;
            sec_set  <= sec_set_wire;
            
            thr_tag  <= thr_tag_wire;
            thr_line <= thr_line_wire;
            thr_sect <= thr_sect_wire;
            thr_src  <= thr_src_wire;
            thr_set  <= thr_set_wire;
        end
    end
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Tests to decide whether to include the IF3 request in to the queue                           //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    
    ////////////// This is the wanted behavior of the unit, but won't pass timing ////////////////////
    //    // Tests
    //    wire clash_n0 = (CACHE_HIT)?      (REFILL_REQ_LINE == cur_line) & (refill_req_dst_del_1 == cur_set) & no_of_elements[0] & (CACHE_SRC == cur_set)    
    //                                      : (REFILL_REQ_LINE == cur_line) & (refill_req_dst_del_1 == cur_set) & no_of_elements[0];		
    // Simplifies to
    //    wire clash_n0 = (REFILL_REQ_LINE == cur_line) & no_of_elements[0] & ( ((refill_req_dst_del_1 == cur_set) & !CACHE_HIT) | (CACHE_SRC == cur_set) );  
    //    wire clash_n1 = (REFILL_REQ_LINE == fir_line) & no_of_elements[1] & ( ((refill_req_dst_del_1 == fir_set) & !CACHE_HIT) | (CACHE_SRC == fir_set) );  
    //    wire clash_n2 = (REFILL_REQ_LINE == sec_line) & no_of_elements[2] & ( ((refill_req_dst_del_1 == sec_set) & !CACHE_HIT) | (CACHE_SRC == sec_set) );  
    //    
    //    wire equal_n0 = (REFILL_REQ_LINE == cur_line) & (REFILL_REQ_TAG == cur_tag) & no_of_elements[0];	
    //    wire equal_n1 = (REFILL_REQ_LINE == fir_line) & (REFILL_REQ_TAG == fir_tag) & no_of_elements[1];    
    //    wire equal_n2 = (REFILL_REQ_LINE == sec_line) & (REFILL_REQ_TAG == sec_tag) & no_of_elements[2];
    
    
    ////////////// Take some tests to the previous clock cycle, timing even worse ///////////////////
    //    // Tests - Clash with nth request
    //    wire clash_n0_wire = (REFILL_REQ_LINE_PREV == cur_line_wire) & (refill_req_dst == cur_set_wire) & no_of_elements_wire[0];
    //    wire clash_n1_wire = (REFILL_REQ_LINE_PREV == fir_line_wire) & (refill_req_dst == fir_set_wire) & no_of_elements_wire[1];
    //    wire clash_n2_wire = (REFILL_REQ_LINE_PREV == sec_line_wire) & (refill_req_dst == sec_set_wire) & no_of_elements_wire[2];
        
    //    // Tests - Equal with nth request
    //    wire equal_n0_wire = (REFILL_REQ_LINE_PREV == cur_line_wire) & (REFILL_REQ_TAG_PREV == cur_tag_wire) & no_of_elements_wire[0];
    //    wire equal_n1_wire = (REFILL_REQ_LINE_PREV == fir_line_wire) & (REFILL_REQ_TAG_PREV == fir_tag_wire) & no_of_elements_wire[1];
    //    wire equal_n2_wire = (REFILL_REQ_LINE_PREV == sec_line_wire) & (REFILL_REQ_TAG_PREV == sec_tag_wire) & no_of_elements_wire[2];
        
    //    reg clash_n0, clash_n1, clash_n2, equal_n0, equal_n1, equal_n2;
    //    always @(posedge CLK) begin
    //        clash_n0 <= clash_n0_wire;
    //        clash_n1 <= clash_n1_wire;
    //        clash_n2 <= clash_n2_wire;
    //        equal_n0 <= equal_n0_wire;
    //        equal_n1 <= equal_n1_wire;
    //        equal_n2 <= equal_n2_wire;
    //    end   
    
    /////////////////// Change the way the tests are begin done, good timing ////////////////////////
    //    reg clash_p0, clash_p1, clash_p2, clash_p3, clash_p4;
    //    reg equal_p0, equal_p1, equal_p2, equal_p3, equal_p4;
    //    reg admit_p, remove_p;
    //    reg element0_p, element1_p, element2_p, element3_p, element4_p; 
          
    //    always @(posedge CLK) begin
    //        clash_p0 <= (REFILL_REQ_LINE_PREV == cur_line)        & (refill_req_dst == cur_set);
    //        clash_p1 <= (REFILL_REQ_LINE_PREV == fir_line)        & (refill_req_dst == fir_set);
    //        clash_p2 <= (REFILL_REQ_LINE_PREV == sec_line)        & (refill_req_dst == sec_set);
    //        clash_p3 <= (REFILL_REQ_LINE_PREV == thr_line)        & (refill_req_dst == thr_set);
    //        clash_p4 <= (REFILL_REQ_LINE_PREV == REFILL_REQ_LINE) & (refill_req_dst == refill_req_dst_del_1);
          
    //        equal_p0 <= (REFILL_REQ_LINE_PREV == cur_line)        & (REFILL_REQ_TAG_PREV == cur_tag);
    //        equal_p1 <= (REFILL_REQ_LINE_PREV == fir_line)        & (REFILL_REQ_TAG_PREV == fir_tag);
    //        equal_p2 <= (REFILL_REQ_LINE_PREV == sec_line)        & (REFILL_REQ_TAG_PREV == sec_tag);
    //        equal_p3 <= (REFILL_REQ_LINE_PREV == thr_line)        & (REFILL_REQ_TAG_PREV == thr_tag);
    //        equal_p4 <= (REFILL_REQ_LINE_PREV == REFILL_REQ_LINE) & (REFILL_REQ_TAG_PREV == REFILL_REQ_TAG);
          
    //        admit_p <= admit;
    //        remove_p <= remove;
          
    //        element0_p <= no_of_elements == 4'b0000;
    //        element1_p <= no_of_elements == 4'b0001;
    //        element2_p <= no_of_elements == 4'b0011;
    //        element3_p <= no_of_elements == 4'b0111;
    //        element4_p <= no_of_elements == 4'b1111;
    //    end
      
    //    reg clash_n0, clash_n1, clash_n2;
    //    reg equal_n0, equal_n1, equal_n2;
    //    always @(*) begin
    //        case ({admit_p, remove_p})
    //            2'b10 : begin
    //                clash_n0 = no_of_elements[0] & ((element0_p)? clash_p4 : clash_p0);
    //                clash_n1 = no_of_elements[1] & ((element1_p)? clash_p4 : clash_p1);
    //                clash_n2 = no_of_elements[2] & ((element2_p)? clash_p4 : clash_p2);
                  
    //                equal_n0 = no_of_elements[0] & ((element0_p)? equal_p4 : equal_p0);
    //                equal_n1 = no_of_elements[1] & ((element1_p)? equal_p4 : equal_p1);
    //                equal_n2 = no_of_elements[2] & ((element2_p)? equal_p4 : equal_p2);                
    //            end
    //            2'b01 : begin
    //                clash_n0 = no_of_elements[0] & clash_p1;
    //                clash_n1 = no_of_elements[1] & clash_p2;
    //                clash_n2 = no_of_elements[2] & clash_p3;
                  
    //                equal_n0 = no_of_elements[0] & equal_p1;
    //                equal_n1 = no_of_elements[1] & equal_p2;
    //                equal_n2 = no_of_elements[2] & equal_p3;
    //            end
    //            2'b11 : begin
    //                clash_n0 = no_of_elements[0] & ((element1_p)? clash_p4 : clash_p1);
    //                clash_n1 = no_of_elements[1] & ((element2_p)? clash_p4 : clash_p2);
    //                clash_n2 = no_of_elements[2] & ((element3_p)? clash_p4 : clash_p3);
                  
    //                equal_n0 = no_of_elements[0] & ((element1_p)? equal_p4 : equal_p1);
    //                equal_n1 = no_of_elements[1] & ((element2_p)? equal_p4 : equal_p2);
    //                equal_n2 = no_of_elements[2] & ((element3_p)? equal_p4 : equal_p3);
    //            end
    //            2'b00 : begin 
    //                clash_n0 = no_of_elements[0] & clash_p0;
    //                clash_n1 = no_of_elements[1] & clash_p1;
    //                clash_n2 = no_of_elements[2] & clash_p2;
                  
    //                equal_n0 = no_of_elements[0] & equal_p0;
    //                equal_n1 = no_of_elements[1] & equal_p1;
    //                equal_n2 = no_of_elements[2] & equal_p2;
    //            end
    //        endcase    
    //    end   
           

    //////////// Take some more logic to the previous clock cycle, even better timing ///////////////
    reg line_eq_cur, line_eq_fir, line_eq_sec, line_eq_thr, line_eq_pcs;
    reg dst_eq_cur,  dst_eq_fir,  dst_eq_sec,  dst_eq_thr,  dst_eq_pcs;
    
    reg equal_cur, equal_fir, equal_sec, equal_thr, equal_pcs;
    
    always @(*) begin
        line_eq_cur = (REFILL_REQ_LINE_PREV == cur_line);
        line_eq_fir = (REFILL_REQ_LINE_PREV == fir_line);
        line_eq_sec = (REFILL_REQ_LINE_PREV == sec_line);
        line_eq_thr = (REFILL_REQ_LINE_PREV == thr_line);
        line_eq_pcs = (REFILL_REQ_LINE_PREV == REFILL_REQ_LINE);
        
        dst_eq_cur = (refill_req_dst == cur_set);
        dst_eq_fir = (refill_req_dst == fir_set);
        dst_eq_sec = (refill_req_dst == sec_set);
        dst_eq_thr = (refill_req_dst == thr_set);
        dst_eq_pcs = (refill_req_dst == refill_req_dst_del_1);
        
        equal_cur = (REFILL_REQ_LINE_PREV == cur_line)        & (REFILL_REQ_TAG_PREV == cur_tag);
        equal_fir = (REFILL_REQ_LINE_PREV == fir_line)        & (REFILL_REQ_TAG_PREV == fir_tag);
        equal_sec = (REFILL_REQ_LINE_PREV == sec_line)        & (REFILL_REQ_TAG_PREV == sec_tag);
        equal_thr = (REFILL_REQ_LINE_PREV == thr_line)        & (REFILL_REQ_TAG_PREV == thr_tag);
        equal_pcs = (REFILL_REQ_LINE_PREV == REFILL_REQ_LINE) & (REFILL_REQ_TAG_PREV == REFILL_REQ_TAG);
    end
    
    reg line_eq_n0, line_eq_n1, line_eq_n2;
    reg dst_eq_n0,  dst_eq_n1,  dst_eq_n2;
    
    reg equal_n0, equal_n1, equal_n2;
    
    always @(posedge CLK) begin
        if (ENB) begin
            case ({admit, remove})
                2'b10 : begin
                    line_eq_n0 <= no_of_elements_wire[0] & ((no_of_elements == 4'b0000)? line_eq_pcs : line_eq_cur);
                    line_eq_n1 <= no_of_elements_wire[1] & ((no_of_elements == 4'b0001)? line_eq_pcs : line_eq_fir);
                    line_eq_n2 <= no_of_elements_wire[2] & ((no_of_elements == 4'b0011)? line_eq_pcs : line_eq_sec);
                    
                    dst_eq_n0 <= no_of_elements_wire[0] & ((no_of_elements == 4'b0000)? dst_eq_pcs : dst_eq_cur);
                    dst_eq_n1 <= no_of_elements_wire[1] & ((no_of_elements == 4'b0001)? dst_eq_pcs : dst_eq_fir);
                    dst_eq_n2 <= no_of_elements_wire[2] & ((no_of_elements == 4'b0011)? dst_eq_pcs : dst_eq_sec);
                    
                    equal_n0 <= no_of_elements_wire[0] & ((no_of_elements == 4'b0000)? equal_pcs : equal_cur);
                    equal_n1 <= no_of_elements_wire[1] & ((no_of_elements == 4'b0001)? equal_pcs : equal_fir);
                    equal_n2 <= no_of_elements_wire[2] & ((no_of_elements == 4'b0011)? equal_pcs : equal_sec);                
                end
                2'b01 : begin
                    line_eq_n0 <= no_of_elements_wire[0] & line_eq_fir;
                    line_eq_n1 <= no_of_elements_wire[1] & line_eq_sec;
                    line_eq_n2 <= no_of_elements_wire[2] & line_eq_thr;
                    
                    dst_eq_n0 <= no_of_elements_wire[0] & dst_eq_fir;
                    dst_eq_n1 <= no_of_elements_wire[1] & dst_eq_sec;
                    dst_eq_n2 <= no_of_elements_wire[2] & dst_eq_thr;
                    
                    equal_n0 <= no_of_elements_wire[0] & equal_fir;
                    equal_n1 <= no_of_elements_wire[1] & equal_sec;
                    equal_n2 <= no_of_elements_wire[2] & equal_thr;
                end
                2'b11 : begin
                    line_eq_n0 <= no_of_elements_wire[0] & ((no_of_elements == 4'b0001)? line_eq_pcs : line_eq_fir);
                    line_eq_n1 <= no_of_elements_wire[1] & ((no_of_elements == 4'b0011)? line_eq_pcs : line_eq_sec);
                    line_eq_n2 <= no_of_elements_wire[2] & ((no_of_elements == 4'b0111)? line_eq_pcs : line_eq_thr);
                    
                    dst_eq_n0 <= no_of_elements_wire[0] & ((no_of_elements == 4'b0001)? dst_eq_pcs : dst_eq_fir);
                    dst_eq_n1 <= no_of_elements_wire[1] & ((no_of_elements == 4'b0011)? dst_eq_pcs : dst_eq_sec);
                    dst_eq_n2 <= no_of_elements_wire[2] & ((no_of_elements == 4'b0111)? dst_eq_pcs : dst_eq_thr);
                    
                    equal_n0 <= no_of_elements_wire[0] & ((no_of_elements == 4'b0001)? equal_pcs : equal_fir);
                    equal_n1 <= no_of_elements_wire[1] & ((no_of_elements == 4'b0011)? equal_pcs : equal_sec);
                    equal_n2 <= no_of_elements_wire[2] & ((no_of_elements == 4'b0111)? equal_pcs : equal_thr);
                end
                2'b00 : begin 
                    line_eq_n0 <= no_of_elements_wire[0] & line_eq_cur;
                    line_eq_n1 <= no_of_elements_wire[1] & line_eq_fir;
                    line_eq_n2 <= no_of_elements_wire[2] & line_eq_sec;
                    
                    dst_eq_n0 <= no_of_elements_wire[0] & dst_eq_cur;
                    dst_eq_n1 <= no_of_elements_wire[1] & dst_eq_fir;
                    dst_eq_n2 <= no_of_elements_wire[2] & dst_eq_sec;
                    
                    equal_n0 <= no_of_elements_wire[0] & equal_cur;
                    equal_n1 <= no_of_elements_wire[1] & equal_fir;
                    equal_n2 <= no_of_elements_wire[2] & equal_sec;
                end
            endcase
        end
    end   
    
    wire clash_n0, clash_n1, clash_n2;
  
    assign clash_n0 = line_eq_n0 & ((!CACHE_HIT & dst_eq_n0) | (CACHE_SRC == cur_set));
    assign clash_n1 = line_eq_n1 & ((!CACHE_HIT & dst_eq_n1) | (CACHE_SRC == fir_set));
    assign clash_n2 = line_eq_n2 & ((!CACHE_HIT & dst_eq_n2) | (CACHE_SRC == sec_set));
  
    // Whether to pass or fail the tests
    always @(*) begin
        if (equal_n2) begin
            test_pass = 0;
        end else if (clash_n2) begin
            test_pass = 1;
        end else if (equal_n1) begin
            test_pass = 0;    
        end else if (clash_n1) begin
            test_pass = 1;    
        end else if (equal_n0) begin
            test_pass = 0;    
        end else if (clash_n0) begin
            test_pass = 1;    
        end else begin
            test_pass = !CACHE_HIT;
        end    
    end
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // FSM for refill control                                                                       //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    
    localparam IDLE         = 1;
    localparam TRANSITION   = 2;
    localparam WRITING_SB   = 4;
    localparam WRITING_L2   = 8;
    localparam WAITING_CRIT = 16;
    
    reg [5              - 1 : 0] refill_state,      refill_state_wire;
    reg [T              - 1 : 0] no_completed,      no_completed_wire;
    reg [BLOCK_SECTIONS - 1 : 0] commited_sections, commited_sections_wire;
    
    integer i;
    
    always @(*) begin
        case (refill_state)
            IDLE : begin
                case ({CACHE_HIT, STREAM_HIT})
                    2'b00 :  begin
                        refill_state_wire = WRITING_L2;
                        no_completed_wire = 0;
                        commited_sections_wire = 0;
                    end
                    2'b01 :  begin
                        refill_state_wire = WRITING_SB;
                        no_completed_wire = 1;
                        for (i = 0; i < BLOCK_SECTIONS; i = i + 1) begin
                            commited_sections_wire[i] = (i[T - 1 : 0] == REFILL_REQ_SECT);
                        end
                    end
                    2'b10 :  begin
                        refill_state_wire = IDLE;
                        no_completed_wire = 0;
                        commited_sections_wire = 0;
                    end 
                    2'b11 :  begin
                        refill_state_wire = IDLE;
                        no_completed_wire = 0;
                        commited_sections_wire = 0;
                    end
                endcase              
            end
            
            TRANSITION : begin
                if (cur_src != 0) begin
                    refill_state_wire = WRITING_SB;
                    no_completed_wire = 1;
                    for (i = 0; i < BLOCK_SECTIONS; i = i + 1) begin
                        commited_sections_wire[i] = (i[T - 1 : 0] == REFILL_REQ_SECT);
                    end
                end else begin
                    if (DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY & DATA_FROM_L2_SRC == 0) begin
                        refill_state_wire = WRITING_L2;
                        no_completed_wire = 1;
                        for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                            commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                    end else begin
                        refill_state_wire = WRITING_L2;
                        no_completed_wire = 0;
                        commited_sections_wire = 0;
                    end
                end
            end
            
            WRITING_SB : begin
                case (no_completed)
                    {T{1'b1}} : begin
                        if (critical_used | critical_use) begin
                            if (no_of_elements == 4'b0001 & !admit) begin
                                refill_state_wire = IDLE;
                                no_completed_wire = 0;
                                for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                    commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                            end else begin
                                refill_state_wire = TRANSITION;
                                no_completed_wire = 0;
                                for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                    commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                            end 
                        end else begin
                            refill_state_wire = WAITING_CRIT;
                            no_completed_wire = 0;
                            for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                        end           
                    end
                    default   : begin
                        refill_state_wire = refill_state; 
                        no_completed_wire = no_completed + 1;
                        for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                            commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];      
                    end
                endcase
            end
            
            WRITING_L2 : begin
                case (no_completed) 
                    {T{1'b1}} : begin
                        if (DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY & (DATA_FROM_L2_SRC == 0)) begin
                            if (critical_used | critical_use) begin
                                if (no_of_elements == 4'b0001 & !admit) begin
                                    refill_state_wire = IDLE;
                                    no_completed_wire = 0;
                                    for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                        commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                                end else begin
                                    refill_state_wire = TRANSITION;
                                    no_completed_wire = 0;
                                    for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                        commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                                end  
                            end else begin
                                refill_state_wire = WAITING_CRIT;
                                no_completed_wire = 0;
                                for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                    commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                            end
                        end else begin
                            refill_state_wire = refill_state;
                            no_completed_wire = no_completed;
                            commited_sections_wire = commited_sections;
                        end
                    end
                    default   : begin
                        if (DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY & (DATA_FROM_L2_SRC == 0)) begin
                            refill_state_wire = refill_state;
                            no_completed_wire = no_completed + 1;
                            for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                        end else begin
                            refill_state_wire = refill_state;
                            no_completed_wire = no_completed;
                            commited_sections_wire = commited_sections;
                        end
                    end
                endcase
            end
            
            default : begin
                if (critical_used | critical_use) begin
                    if (no_of_elements == 4'b0001 & !admit) begin
                        refill_state_wire = IDLE;
                        no_completed_wire = 0;
                        commited_sections_wire = 0;
                    end else begin
                        refill_state_wire = TRANSITION;
                        no_completed_wire = 0;
                        commited_sections_wire = 0;
                    end
                end else begin
                    refill_state_wire = refill_state;
                    no_completed_wire = no_completed;
                    commited_sections_wire = commited_sections;
                end  
            end
        endcase
    end
    
    always @(posedge CLK) begin
        if (ENB) begin
            no_completed      <= no_completed_wire;
            refill_state      <= refill_state_wire;
            commited_sections <= commited_sections_wire;
        end
    end
    
    assign remove = ((refill_state == WRITING_SB  ) & (no_completed == {T{1'b1}}) & (critical_used | critical_use)) |
                    ((refill_state == WAITING_CRIT)                               & (critical_used | critical_use)) |
                    ((refill_state == WRITING_L2  ) & (no_completed == {T{1'b1}}) & (critical_used | critical_use)  
                            & DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY & (DATA_FROM_L2_SRC == 0));
        
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for writing to tag memory and line memory                                       //
    //////////////////////////////////////////////////////////////////////////////////////////////////
         
    // Addresses        
    assign TAG_MEM_WR_ADDR      = (no_of_elements == 0)? REFILL_REQ_LINE                      : cur_line;
    assign LIN_MEM_WR_ADDR      = (no_of_elements == 0)? ({REFILL_REQ_LINE, REFILL_REQ_SECT}) : ({cur_line, (cur_sect + no_completed)});
    
    // Data
    assign TAG_MEM_TAG_IN       = (no_of_elements == 0)? REFILL_REQ_TAG : cur_tag;
    assign LIN_MEM_DATA_IN_SEL  = (no_of_elements == 0)? refill_req_src : cur_src;
    assign TAG_MEM_TAG_VALID_IN = commited_sections_wire;
        
    // Write enables
    reg write_test;
    always @(*) begin
        case (refill_state) 
            IDLE        :   write_test = !CACHE_HIT & STREAM_HIT;
            TRANSITION  :   write_test = (cur_src != 0) | (DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY & DATA_FROM_L2_SRC == 0);
            WRITING_SB  :   write_test = 1'b1;
            WRITING_L2  :   write_test = DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY & (DATA_FROM_L2_SRC == 0);
            default     :   write_test = 0;
        endcase
    end
    
    assign TAG_MEM_WR_ENB       = ((no_of_elements == 0)? refill_req_dst_del_1 : cur_set) & {ASSOCIATIVITY{write_test}};
    assign LIN_MEM_WR_ENB       = ((no_of_elements == 0)? refill_req_dst_del_1 : cur_set) & {ASSOCIATIVITY{write_test}};
       
       
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for Data from L2 and prefetch control unit                                      //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    assign SECTION_COMMIT = (refill_state == WRITING_SB) | 
                            (refill_state == IDLE       & !CACHE_HIT & STREAM_HIT) | 
                            (refill_state == TRANSITION & (cur_src != 0));
    
    assign DATA_FROM_L2_BUFFER_READY = (refill_state == WRITING_L2) | 
                                       (refill_state == TRANSITION & cur_src == 0);
                                       
    assign ONGOING_QUEUE_RD_ENB = (refill_state == WRITING_L2) & DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY 
                                        & (DATA_FROM_L2_SRC == 0) & (no_completed == {T{1'b1}});   
            
        
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for Address to L2 modules                                                       //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    // Address sent to L2 only if its admitted to queue and its not a stream hit
    assign SEND_ADDR_TO_L2 = admit & !STREAM_HIT;
        
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for main pipeline and PC select                                                 //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    localparam HITTING = 0;
    localparam WAIT = 1;
    localparam PC0 = 2;
    localparam PC1 = 3;
    localparam PC2 = 4;
    localparam TRANSIT = 5;
    
    // FSM for enabling the PC pipeline
    reg [2 : 0] pc_state, pc_state_del_1, pc_state_del_2;
            
    always @(*) begin
        case (refill_state)
            IDLE        :   critical_ready = !CACHE_HIT & STREAM_HIT;
            TRANSITION  :   critical_ready = (cur_src != 0) | (DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY & DATA_FROM_L2_SRC == 0);
            WRITING_SB  :   critical_ready = 0;
            WRITING_L2  :   critical_ready = (no_completed_wire == 1) & DATA_FROM_L2_BUFFER_VALID & DATA_FROM_L2_BUFFER_READY & (DATA_FROM_L2_SRC == 0);
            default     :   critical_ready = 0;
        endcase
    end
            
    // Finding whether critical use
    assign critical_use = equal_n0 & CACHE_HIT & pc_state == PC2;        
            
    always @(posedge CLK) begin
        if (ENB) begin
            case ({critical_ready, critical_use}) 
                2'b00 : critical_used <= critical_used;
                2'b01 : critical_used <= 1'b1;
                2'b10 : critical_used <= 1'b0;
                2'b11 : critical_used <= critical_used;
            endcase
        end
    end 
    
    always @(posedge CLK) begin
        if (ENB) begin
            case (pc_state) 
                HITTING : begin
                    case ({STREAM_HIT, CACHE_HIT})
                        2'b00 : pc_state <= PC0;
                        2'b01 : pc_state <= HITTING;
                        2'b10 : pc_state <= PC0;
                        2'b11 : pc_state <= HITTING;
                    endcase
                end
                
                WAIT : begin
                    if (critical_ready | critical_used == 0)  // | (CACHE_HIT & pc_state_del_2 == WAIT)
                        pc_state <= PC0;
                end
                
                PC0 : pc_state <= PC1;
                PC1 : pc_state <= PC2;
                
                PC2 : begin
                    if (CACHE_HIT)        
                        if (no_of_elements == 1) 
                            pc_state <= HITTING;
                        else 
                            pc_state <= TRANSIT;
                    else
                        pc_state <= PC0; 
                end
                
                TRANSIT : begin
                    if (no_of_elements == 0) begin
                        case ({STREAM_HIT, CACHE_HIT})
                            2'b00 : pc_state <= WAIT;
                            2'b01 : pc_state <= HITTING;
                            2'b10 : pc_state <= PC0;
                            2'b11 : pc_state <= HITTING;
                        endcase
                    end else begin 
                        case ({STREAM_HIT, CACHE_HIT})
                            2'b00 : pc_state <= (critical_used != 0 | critical_ready)? PC0 : WAIT;
                            2'b01 : pc_state <= TRANSIT;
                            2'b10 : pc_state <= (critical_used != 0 | critical_ready)? PC0 : WAIT;
                            2'b11 : pc_state <= TRANSIT;
                        endcase
                    end
                end
            endcase
        end
    end 
    
    always @(posedge CLK) begin
        if (ENB) begin
            pc_state_del_1 <= pc_state;
            pc_state_del_2 <= pc_state_del_1;
        end
    end
        
    // Enabling the PC pipeline 
    assign PC_PIPE_ENB = (pc_state != WAIT);
    assign PC_SEL = {(   pc_state == PC0
                      |  pc_state == PC1
                      | (pc_state == PC2     & !CACHE_HIT)
                      | (pc_state == HITTING & !CACHE_HIT)
                      |  pc_state == WAIT
                      | (pc_state == TRANSIT & !CACHE_HIT)), 
                                                             BRANCH};
    
    assign CACHE_READY = (pc_state == HITTING | 
                          pc_state == TRANSIT | 
                          pc_state == PC2)       & CACHE_HIT;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Initial conditions - for simulation                                                          //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    initial begin
        no_of_elements = 0;
        refill_state = 1;   
        
        pc_state = HITTING; 
        pc_state_del_1 = HITTING; 
        pc_state_del_2 = HITTING; 
        
        pc_pipe_enb_del_1 = 1;
        pc_admissible     = 1;
        pc_sel_del_1      = 0;
        pc_sel_del_2      = 0;
        
        critical_used = 1; 
//        clash_n0 = 0;
//        clash_n1 = 0;
//        clash_n2 = 0;
//        equal_n0 = 0;
//        equal_n1 = 0;
//        equal_n2 = 0;        
    end
    
    
    
   // Log value calculation
   function integer logb2;
       input integer depth;
       for (logb2 = 0; depth > 1; logb2 = logb2 + 1)
           depth = depth >> 1;
   endfunction
  
endmodule
