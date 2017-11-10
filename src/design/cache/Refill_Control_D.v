`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/29/2016 01:18:53 PM
// Design Name: 
// Module Name: Refill_Control_D
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


module Refill_Control_D #(
        // Fixed parameters
        localparam ADDR_WIDTH       = 32,
        
        // Primary parameters
        parameter S                 = 17, 
        parameter B                 = 9, 
        parameter a                 = 1,
        parameter T                 = 1,
        parameter V                 = 2,
        
        // Derived parameters
        localparam TAG_WIDTH        = ADDR_WIDTH + 3 + a - S,
        localparam TAG_ADDR_WIDTH   = S - a - B,
        localparam BLOCK_SECTIONS   = 1 << T,
        localparam ASSOCIATIVITY    = 1 << a,
        localparam LINE_ADDR_WIDTH  = S - a - B + T    
    ) (
        input                                CLK,
        
        // Current request at IF3
        input                                CACHE_HIT,                      // Whether the L1 cache hits or misses 
        input                                VICTIM_HIT,                     // Whether the victim cache has hit
        input      [V + T           - 1 : 0] VICTIM_HIT_ADDRESS,             // Hit position in the victim cache
        input      [2               - 1 : 0] CONTROL,                        // Control portion of request at DM2 
        
        input      [TAG_WIDTH       - 1 : 0] REFILL_REQ_TAG,                 // Tag portion of the ADDR at DM3
        input      [TAG_ADDR_WIDTH  - 1 : 0] REFILL_REQ_LINE,                // Line portion of the ADDR at DM3
        input      [T               - 1 : 0] REFILL_REQ_SECT,                // Section portion of the ADDR at DM3
        input      [TAG_WIDTH       - 1 : 0] REFILL_REQ_VTAG,                // Tag coming out of tag memory delayed to DM3
        input      [a               - 1 : 0] REFILL_REQ_DST_SET,             // Destination set for the refill
        input                                REFILL_REQ_DIRTY,               // Dirty bit coming out of tag memory delayed to DM3
        input                                REFILL_REQ_VALID,               // Valid bit coming out of tag memory delayed to DM3
        input      [2               - 1 : 0] REFILL_REQ_CTRL,                // Instruction at DM3 
         
        // From the Victim cache
        input                                VICTIM_CACHE_READY,            // From victim cache that it is ready to receive
        output                               VICTIM_CACHE_WRITE,            // To victim cache that it has to write the data from DM3
        output reg                           VICTIM_COMMIT,                 // To victim cache that it has hit and must send a burst of data
        output                               VICTIM_BYPASS,                 // Bypass the normal search routine of victim cache to directly insert a read address
        output     [V + T           - 1 : 0] VICTIM_BYPASS_ADDRESS,         // Read address of the victim cache
                        
        // To the L1 read ports
        output                               L1_RD_PORT_SELECT,             // Selects the inputs to the Read ports of L1 {0(from processor), 1(from evict control)}         
        output reg [TAG_WIDTH       - 1 : 0] EVICT_TAG,                     // Tag for read address at DM1 
        output reg [TAG_ADDR_WIDTH  - 1 : 0] EVICT_TAG_ADDR,                // Cache line for read address at DM1 
        output reg [T               - 1 : 0] EVICT_SECT,                    // Section for read address at DM1  
        
        // To the L1 write ports
        output reg [2               - 1 : 0] L1_WR_PORT_SELECT,             // Selects the inputs to the Write ports of L1 {0 or 1(for a L1 data write), 2(victim cache refill), 3 (for L2 refill)}
        output     [ASSOCIATIVITY   - 1 : 0] REFILL_DST,                    // Individual write enables for the line memories
        output     [TAG_WIDTH       - 1 : 0] REFILL_TAG,                    // Tag for the refill write
        output     [BLOCK_SECTIONS  - 1 : 0] REFILL_TAG_VALID,              // Which sections are valid currently, will be written to tag memory
        output     [TAG_ADDR_WIDTH  - 1 : 0] REFILL_TAG_ADDR,               // Tag address for the refill write
        output     [T               - 1 : 0] REFILL_SECT,                   // Section address for the refill write
                              
        // Outputs to the main processor pipeline		
        output reg                           CACHE_READY,                   // Signal from cache to processor that its pipeline is currently ready to work  
        
        // Related to Data from L2 buffer
        input                                DATA_FROM_L2_BUFFER_VALID,     // Ready signal for refill from L2
        output reg                           DATA_FROM_L2_BUFFER_READY,     // Valid signal for refill from L2
                
        // Related to Address to L2 buffers
        output                               SEND_RD_ADDR_TO_L2,            // Valid signal for the input of Addr_to_L2 section   
                
        // Related to controlling the pipeline
        output                               MAIN_PIPE_ENB,                 // Enable for main pipeline registers
        output CACHE_PIPE_ENB,                      // Enable for cache pipeline
        output reg                           ADDR_FROM_PROC_SEL             // addr_from_proc_sel = {0(addr_from_proc_del_2), 1 (ADDR_FROM_PROC)}   
    );
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Globally important figures                                                                  //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    reg  test_pass;                                  // Current DM3 request passes the clash and equal tests
    reg  main_pipe_enb_del_1, main_pipe_enb_del_2;   // Delayed processor pipeline enables
    reg  l1_rd_from_proc, l1_rd_from_proc_del_1;     // Delayed read port selects
    reg  l1_rd_from_main, l1_rd_from_main_del_1;
    
    reg  real_request;                               // Write request is valid and is not an IDLE
    reg  missable_request;                           // Write request is valid and is a WRITE or READ
    reg  admissible_request;                         // Write request is fresh from processor and is a WRITE or READ
    reg  flush_request;                              // Write request is valid and is a FLUSH
    
    reg  critical_ready;                             // The critical word currently being pushed into L1 and ready
    reg  critical_use;                               // Last critical word currently being used so next request can be started
    reg  critical_used;                              // Critical word is used
    
    always @(posedge CLK) begin
        l1_rd_from_proc       <= ADDR_FROM_PROC_SEL;
        l1_rd_from_proc_del_1 <= (L1_RD_PORT_SELECT == 0) & l1_rd_from_proc;
        
        l1_rd_from_main       <= (L1_RD_PORT_SELECT == 0);
        l1_rd_from_main_del_1 <= l1_rd_from_main;
        
        main_pipe_enb_del_1   <= MAIN_PIPE_ENB;
        main_pipe_enb_del_2   <= main_pipe_enb_del_1;
        
        admissible_request    <= main_pipe_enb_del_2 & l1_rd_from_proc_del_1 & !(CONTROL == 2'b00);
        real_request          <= main_pipe_enb_del_2 &                         !(CONTROL == 2'b00);
        missable_request      <= main_pipe_enb_del_2 & l1_rd_from_proc_del_1 &  (CONTROL == 2'b01 | CONTROL == 2'b10);
        flush_request         <= main_pipe_enb_del_2 &                          (CONTROL == 2'b11);
    end    
    
    wire                           refill_req_link;
    wire [TAG_WIDTH       - 1 : 0] refill_req_vtag; 
      
     
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Refill request queue management                                                              //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    
    // PCs of the currently being fetched requests are stored. Max number of requests is 4.
    // Three is for DM1, DM2 and DM3 and last is for early restart
    
    // Control signals for the queue    
    wire admit = (test_pass & admissible_request) | flush_request;         // Admit only if clash/equal tests pass, and is a valid (pipeline is enabled), non-IDLE request
    wire remove;                                                           // Whether to remove from the refill queue
    wire evict;                                                            // Indicates that the first eviction in the queue is complete
    
    
    // Number of elements in the queue
    reg [3 : 0] no_of_elements, no_of_elements_wire;
        
    always @(*) begin
        case ({admit, remove})
            2'b00 : no_of_elements_wire = no_of_elements;
            2'b01 : no_of_elements_wire = no_of_elements >> 1;
            2'b10 : no_of_elements_wire = (no_of_elements << 1) | 4'b0001;
            2'b11 : no_of_elements_wire = no_of_elements;
        endcase
    end
    
    always @(posedge CLK) begin
        no_of_elements <= no_of_elements_wire;
    end
            
        
    // Contents of the queue                    
    localparam REQ_LENGTH = TAG_WIDTH * 2 + TAG_ADDR_WIDTH + T + a + 5 + V + T;
        
    wire [TAG_WIDTH      - 1 : 0] cur_tag,  fir_tag,  sec_tag,  thr_tag;         // Tag for the L1 write
    wire [TAG_WIDTH      - 1 : 0] cur_vtag, fir_vtag, sec_vtag, thr_vtag;        // Tag for the victim cache
    wire [TAG_ADDR_WIDTH - 1 : 0] cur_line, fir_line, sec_line, thr_line;        // Cache block to write to (for L1 and victim)
    wire [T              - 1 : 0] cur_sect, fir_sect, sec_sect, thr_sect;        // Section within block to write first (for L1 and victim)
    
    wire [1              - 1 : 0] cur_src,  fir_src,  sec_src,  thr_src;         // Source = whether to refill from L2 (0) or from victim cache (1) 
    wire [V + T          - 1 : 0] cur_vhit, fir_vhit, sec_vhit, thr_vhit;        // If victim hit, the search address in victim cache, else garbage       
    wire [a              - 1 : 0] cur_set,  fir_set,  sec_set,  thr_set;         // Set = destination set of the request (in binary format)
    wire [1              - 1 : 0] cur_dirt, fir_dirt, sec_dirt, thr_dirt;        // Whether filling the victim cache is necessary
    wire [2              - 1 : 0] cur_ctrl, fir_ctrl, sec_ctrl, thr_ctrl;        // Control signals of the request (read, write, flush)
    wire [1              - 1 : 0] cur_link, fir_link, sec_link, thr_link;        // Whether the request has originated from a clash with forward requests        
    
    reg                           cur_evic, fir_evic, sec_evic, thr_evic;        // Indicates that the eviction line has to be saved
                
    reg  [REQ_LENGTH - 1 : 0] cur,      fir,      sec,      thr;
    reg  [REQ_LENGTH - 1 : 0] cur_wire, fir_wire, sec_wire, thr_wire;
    
    wire [REQ_LENGTH - 1 : 0] refill_req = {REFILL_REQ_TAG,  refill_req_vtag,    REFILL_REQ_LINE,    REFILL_REQ_SECT, 
                                            VICTIM_HIT,      VICTIM_HIT_ADDRESS, REFILL_REQ_DST_SET, REFILL_REQ_DIRTY, 
                                            REFILL_REQ_CTRL, refill_req_link};
                                            
    assign {cur_tag, cur_vtag, cur_line, cur_sect, cur_src, cur_vhit, cur_set, cur_dirt, cur_ctrl, cur_link} = cur;
    assign {fir_tag, fir_vtag, fir_line, fir_sect, fir_src, fir_vhit, fir_set, fir_dirt, fir_ctrl, fir_link} = fir;
    assign {sec_tag, sec_vtag, sec_line, sec_sect, sec_src, sec_vhit, sec_set, sec_dirt, sec_ctrl, sec_link} = sec;
    assign {thr_tag, thr_vtag, thr_line, thr_sect, thr_src, thr_vhit, thr_set, thr_dirt, thr_ctrl, thr_link} = thr;
       
    wire cur_link_wire = cur_wire[0];   
    wire fir_link_wire = fir_wire[0];   
    wire sec_link_wire = sec_wire[0];   
    wire thr_link_wire = thr_wire[0];   
                                            
    // A queue storing missed requests (also each element is accessible to the outside, to run the tests)
    always @(*) begin
        case ({admit, remove}) 
            2'b10 : begin
                cur_wire = (no_of_elements == 4'b0000)? refill_req : cur;
                fir_wire = (no_of_elements == 4'b0001)? refill_req : fir;
                sec_wire = (no_of_elements == 4'b0011)? refill_req : sec;
                thr_wire = (no_of_elements == 4'b0111)? refill_req : thr;
            end
            2'b01 : begin
                cur_wire = fir;
                fir_wire = sec;
                sec_wire = thr;
                thr_wire = 0;
            end
            2'b11 : begin
                cur_wire = (no_of_elements == 4'b0001)? refill_req : fir;
                fir_wire = (no_of_elements == 4'b0011)? refill_req : sec;
                sec_wire = (no_of_elements == 4'b0111)? refill_req : thr;
                thr_wire = (no_of_elements == 4'b1111)? refill_req : 0;
            end
            2'b00 : begin
                cur_wire = cur;
                fir_wire = fir;
                sec_wire = sec;
                thr_wire = thr;
            end
        endcase
    end
    
    always @(posedge CLK) begin
        cur <= cur_wire;
        fir <= fir_wire;
        sec <= sec_wire;
        thr <= thr_wire;
    end    
    
    
    // Eviction information has to be handled specially since it is possible to zero them while inside the queue
    reg cur_evic_wire, fir_evic_wire, sec_evic_wire, thr_evic_wire;
    
    // Stores which 'still unevicted request' is at the head of the queue
    reg [3 : 0] compl_evic;    
    always @(*) begin
        case ({thr_evic, sec_evic, fir_evic, cur_evic})
            4'b0000 : compl_evic = 4'b0000;
            4'b0001 : compl_evic = 4'b0001;
            4'b0010 : compl_evic = 4'b0010;
            4'b0011 : compl_evic = 4'b0001;
            
            4'b0100 : compl_evic = 4'b0100;
            4'b0101 : compl_evic = 4'b0001;
            4'b0110 : compl_evic = 4'b0010;
            4'b0111 : compl_evic = 4'b0001;
            
            4'b1000 : compl_evic = 4'b1000;
            4'b1001 : compl_evic = 4'b0001;
            4'b1010 : compl_evic = 4'b0010;
            4'b1011 : compl_evic = 4'b0001;
            
            4'b1100 : compl_evic = 4'b0100;
            4'b1101 : compl_evic = 4'b0001;
            4'b1110 : compl_evic = 4'b0010;
            4'b1111 : compl_evic = 4'b0001;
        endcase
    end
    
    // Part of the request queue for storing whether eviction is complete
    always @(*) begin
        case ({admit, remove, evict}) 
            3'b100 : begin
                cur_evic_wire = (no_of_elements == 4'b0000)? REFILL_REQ_VALID : cur_evic;
                fir_evic_wire = (no_of_elements == 4'b0001)? REFILL_REQ_VALID : fir_evic;
                sec_evic_wire = (no_of_elements == 4'b0011)? REFILL_REQ_VALID : sec_evic;
                thr_evic_wire = (no_of_elements == 4'b0111)? REFILL_REQ_VALID : thr_evic;
            end
            3'b010 : begin
                cur_evic_wire = fir_evic;
                fir_evic_wire = sec_evic;
                sec_evic_wire = thr_evic;
                thr_evic_wire = 0;
            end
            3'b110 : begin
                cur_evic_wire = (no_of_elements == 4'b0001)? REFILL_REQ_VALID : fir_tag;
                fir_evic_wire = (no_of_elements == 4'b0011)? REFILL_REQ_VALID : sec_tag;
                sec_evic_wire = (no_of_elements == 4'b0111)? REFILL_REQ_VALID : thr_tag;
                thr_evic_wire = (no_of_elements == 4'b1111)? REFILL_REQ_VALID : 0;
            end
            3'b000 : begin
                cur_evic_wire = cur_evic;
                fir_evic_wire = fir_evic;
                sec_evic_wire = sec_evic;
                thr_evic_wire = thr_evic;
            end
            3'b101 : begin
                cur_evic_wire = (no_of_elements == 4'b0000)? REFILL_REQ_VALID : cur_evic & !compl_evic[0];
                fir_evic_wire = (no_of_elements == 4'b0001)? REFILL_REQ_VALID : fir_evic & !compl_evic[1];
                sec_evic_wire = (no_of_elements == 4'b0011)? REFILL_REQ_VALID : sec_evic & !compl_evic[2];
                thr_evic_wire = (no_of_elements == 4'b0111)? REFILL_REQ_VALID : thr_evic & !compl_evic[3];
            end
            3'b011 : begin
                cur_evic_wire = fir_evic & !compl_evic[1];
                fir_evic_wire = sec_evic & !compl_evic[2];
                sec_evic_wire = thr_evic & !compl_evic[3];
                thr_evic_wire = 0;
            end
            3'b111 : begin
                cur_evic_wire = (no_of_elements == 4'b0001)? REFILL_REQ_VALID : fir_tag & !compl_evic[1];
                fir_evic_wire = (no_of_elements == 4'b0011)? REFILL_REQ_VALID : sec_tag & !compl_evic[2];
                sec_evic_wire = (no_of_elements == 4'b0111)? REFILL_REQ_VALID : thr_tag & !compl_evic[3];
                thr_evic_wire = (no_of_elements == 4'b1111)? REFILL_REQ_VALID : 0;
            end
            3'b001 : begin
                cur_evic_wire = cur_evic & !compl_evic[0];
                fir_evic_wire = fir_evic & !compl_evic[1];
                sec_evic_wire = sec_evic & !compl_evic[2];
                thr_evic_wire = thr_evic & !compl_evic[3];
            end
        endcase
    end
    
    // Registering the eviction information at end of clock cycle
    always @(posedge CLK) begin
        cur_evic <= cur_evic_wire;
        fir_evic <= fir_evic_wire;
        sec_evic <= sec_evic_wire;
        thr_evic <= thr_evic_wire;
    end
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Tests to decide whether to include the IF3 request in to the queue                           //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    
    wire clash_n0 = (REFILL_REQ_LINE == cur_line) & no_of_elements[0] & ( ((REFILL_REQ_DST_SET == cur_set) & !CACHE_HIT) | (REFILL_REQ_DST_SET == cur_set) );  
    wire clash_n1 = (REFILL_REQ_LINE == fir_line) & no_of_elements[1] & ( ((REFILL_REQ_DST_SET == fir_set) & !CACHE_HIT) | (REFILL_REQ_DST_SET == fir_set) );  
    wire clash_n2 = (REFILL_REQ_LINE == sec_line) & no_of_elements[2] & ( ((REFILL_REQ_DST_SET == sec_set) & !CACHE_HIT) | (REFILL_REQ_DST_SET == sec_set) );  
    
    wire equal_n0 = (REFILL_REQ_LINE == cur_line) & (REFILL_REQ_TAG == cur_tag) & no_of_elements[0];	
    wire equal_n1 = (REFILL_REQ_LINE == fir_line) & (REFILL_REQ_TAG == fir_tag) & no_of_elements[1];	
    wire equal_n2 = (REFILL_REQ_LINE == sec_line) & (REFILL_REQ_TAG == sec_tag) & no_of_elements[2];	
    
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
    
    assign refill_req_link = clash_n2 | clash_n1 | clash_n0;
    assign refill_req_vtag = (clash_n2) ?  sec_tag : 
                             (clash_n1) ?  fir_tag :
                             (clash_n0) ?  cur_tag :
                             REFILL_REQ_VTAG;
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // FSM for saving eviction victims                                                              //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    
    wire evic_empty_wire = !(|{cur_evic_wire, fir_evic_wire, sec_evic_wire, thr_evic_wire});
    
    wire next_evic_ready = cur_evic_wire | (fir_evic_wire & !fir_link_wire) | (sec_evic_wire & !sec_link_wire) | (thr_evic_wire & !thr_link_wire);
    
    localparam E_HITTING  = 1;                                      // When there are no requests in the refill queue (no_of_elements == 0)
    localparam E_WAITING  = 2;                                      // Waiting for refill to finish since there is a link in the current request
    localparam E_IDLE1    = 4;                                      // Wait two cycles till last request exits the queue
    localparam E_IDLE2    = 8;                                      // Wait two cycles till last request exits the queue
    localparam E_EVIC_STA = 16;                                     // Starting an eviction from start
    localparam E_EVIC_FIN = {1'b1, {(3 + BLOCK_SECTIONS){1'b0}}};   // Finished an eviction
        
    reg [4 + BLOCK_SECTIONS - 1 : 0] evic_state, evic_state_del_1, evic_state_del_2;
    reg [T                  - 1 : 0] evic_no;
    
    assign evict              = (evic_state == E_EVIC_FIN);
    
    assign VICTIM_CACHE_WRITE = (evic_state == E_HITTING & admit & REFILL_REQ_VALID & !refill_req_link) | |(evic_state_del_2[4 + BLOCK_SECTIONS - 1  : 4]);
    assign L1_RD_PORT_SELECT  = !((evic_state == E_HITTING) | (evic_state == E_WAITING) | (evic_state == E_IDLE1) | (evic_state == E_IDLE2));
            
    always @(posedge CLK) begin
        if (VICTIM_CACHE_READY) begin
            case (evic_state)
                E_HITTING  : begin
                    if (admit & REFILL_REQ_VALID) begin
                        if (refill_req_link) begin
                            evic_state <= E_WAITING;
                            evic_no    <= 0;
                        end else begin
                            evic_state <= E_IDLE2 << 2;
                            evic_no    <= 1;
                        end
                    end    
                end 
                E_WAITING  : begin
                    evic_state <= (cur_evic_wire)? E_IDLE2 << 1 : E_WAITING;  
                    evic_no    <= (cur_evic_wire)? 0            : 0;  
                end
                E_EVIC_FIN : begin
                    evic_state <= E_IDLE1;
                    evic_no    <= 0;
                end    
                E_IDLE1   : begin
                    evic_state <= E_IDLE2;
                    evic_no    <= 0;
                end
                E_IDLE2   : begin
                    case ({evic_empty_wire, next_evic_ready})
                        2'b00   : begin
                            evic_state <= E_WAITING;
                            evic_no    <= 0;
                        end
                        2'b01   : begin
                            evic_state <= E_EVIC_STA;
                            evic_no    <= 0;
                        end
                        default : begin
                            evic_state <= E_HITTING;
                            evic_no    <= 0;
                        end
                    endcase
                end
                default   : begin
                    evic_state <= evic_state << 1;
                    evic_no    <= evic_no + 1;
                end
            endcase
        end
    end
    
    always @(posedge CLK) begin
        evic_state_del_1 <= evic_state;
        evic_state_del_2 <= evic_state_del_1;
    end    
      
    always @(*) begin
        case (compl_evic)
            4'b0001  : begin
                EVICT_TAG      = cur_vtag;
                EVICT_TAG_ADDR = cur_line;
                EVICT_SECT     = cur_sect + evic_no;
            end
            4'b0010  : begin
                EVICT_TAG      = fir_vtag;
                EVICT_TAG_ADDR = fir_line;
                EVICT_SECT     = fir_sect + evic_no;
            end
            4'b0100  : begin
                EVICT_TAG      = sec_vtag;
                EVICT_TAG_ADDR = sec_line;
                EVICT_SECT     = sec_sect + evic_no;
            end
            4'b1000  : begin
                EVICT_TAG      = thr_vtag;
                EVICT_TAG_ADDR = thr_line;
                EVICT_SECT     = thr_sect + evic_no;
            end
            default  : begin
                EVICT_TAG      = REFILL_REQ_VTAG;
                EVICT_TAG_ADDR = REFILL_REQ_LINE;
                EVICT_SECT     = REFILL_REQ_SECT + evic_no;
            end
        endcase
    end       
          
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for Address to L2 modules                                                       //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    // Address sent to L2 only if its admitted to queue and its not a stream hit
    assign SEND_RD_ADDR_TO_L2 = admit & !VICTIM_HIT & missable_request;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // FSM for refill control                                                                       //
    //////////////////////////////////////////////////////////////////////////////////////////////////
                
    localparam IDLE          = 1;
    localparam TRANSITION    = 2;
    localparam WRITING_VIC   = 4;                 
    localparam WRITING_L2    = 8;
    localparam FLUSHING      = 16;
    localparam WAITING_CRIT  = 32;
    
    reg [6              - 1 : 0] refill_state,      refill_state_wire;
    reg [T              - 1 : 0] no_completed,      no_completed_wire;
    reg [BLOCK_SECTIONS - 1 : 0] commited_sections, commited_sections_wire;
    
    integer i;
        
    always @(*) begin
        case (refill_state)
            IDLE : begin
                case ({CACHE_HIT, VICTIM_HIT})
                    2'b00 :  begin
                        if (missable_request) begin
                            refill_state_wire = WRITING_L2;
                            no_completed_wire = 0;
                            commited_sections_wire = 0;
                        end else begin
                            refill_state_wire = IDLE;
                            no_completed_wire = 0;
                            commited_sections_wire = 0;
                        end
                    end
                    2'b01 :  begin
                        if (missable_request) begin
                            refill_state_wire = WRITING_VIC;
                            no_completed_wire = 1;
                            for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                commited_sections_wire[i] = (i[T - 1 : 0] == REFILL_REQ_SECT);
                        end else begin
                            refill_state_wire = IDLE;
                            no_completed_wire = 0;
                            commited_sections_wire = 0;
                        end
                    end
                    default :  begin
                        if (flush_request) begin
                            refill_state_wire = FLUSHING;
                            no_completed_wire = 0;
                            commited_sections_wire = 0;
                        end else begin
                            refill_state_wire = IDLE;
                            no_completed_wire = 0;
                            commited_sections_wire = 0;
                        end
                    end 
                endcase              
            end
            
            WRITING_VIC : begin
                case (no_completed) 
                    0         : begin
                        if (cur_evic == 0) begin
                            refill_state_wire = refill_state;    
                            no_completed_wire = no_completed + 1;    
                            for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                        end else begin
                            no_completed_wire = no_completed;
                            refill_state_wire = refill_state;
                            commited_sections_wire = commited_sections;
                        end
                    end
                    {T{1'b1}} : begin
                        if (critical_used == 0) begin
                            refill_state_wire = WAITING_CRIT;
                            no_completed_wire = 0;
                            for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                        end else begin
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
                        end
                    end
                    1         : begin
                        if (cur_evic) begin
                            no_completed_wire = no_completed;
                            refill_state_wire = refill_state;
                            commited_sections_wire = commited_sections;
                        end else begin
                            refill_state_wire = refill_state;    
                            no_completed_wire = no_completed + 1;    
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
                    0         : begin
                        if (DATA_FROM_L2_BUFFER_VALID & (cur_evic == 0)) begin
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
                    {T{1'b1}} : begin
                        if (DATA_FROM_L2_BUFFER_VALID) begin
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
                    1         : begin
                        if (DATA_FROM_L2_BUFFER_VALID & (cur_evic == 0)) begin
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
                    default   : begin
                        if (DATA_FROM_L2_BUFFER_VALID) begin
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
            
            WAITING_CRIT : begin
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
                        
            TRANSITION : begin
                // If current request is a flush command
                if (cur_ctrl == 2'b11) begin
                    refill_state_wire = FLUSHING;
                    no_completed_wire = 0;
                    commited_sections_wire = 0;
                end else begin
                    if (cur_src == 0) begin
                        if (DATA_FROM_L2_BUFFER_VALID & (cur_evic == 0)) begin
                            refill_state_wire = WRITING_L2;
                            no_completed_wire = 1;
                            for (i = 0; i < BLOCK_SECTIONS; i = i + 1)
                                commited_sections_wire[i] = (i[T - 1 : 0] == cur_sect + no_completed) ? 1 : commited_sections[i];
                        end else begin
                            refill_state_wire = WRITING_L2;
                            no_completed_wire = 0;
                            commited_sections_wire = 0;
                        end
                    end else begin
                        if (cur_evic == 0) begin
                            refill_state_wire = WRITING_VIC;
                            no_completed_wire = 0;
                            commited_sections_wire = 0;
                        end else begin
                            refill_state_wire = TRANSITION;
                            no_completed_wire = 0;
                            commited_sections_wire = 0;
                        end
                    end
                end                
            end
                        
            default : begin
                // Case of flushing                        
                if (cur_evic == 0) begin
                    if (no_completed == {T{1'b1}}) begin
                        if (no_of_elements == 4'b0001 & !admit) begin
                            refill_state_wire = IDLE;
                            no_completed_wire = no_completed + 1;  
                            commited_sections_wire = 0;
                        end else begin
                            refill_state_wire = TRANSITION;
                            no_completed_wire = no_completed + 1;  
                            commited_sections_wire = 0;
                        end  
                    end else begin
                        refill_state_wire = refill_state;
                        no_completed_wire = no_completed + 1;  
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
        no_completed      <= no_completed_wire;
        refill_state      <= refill_state_wire;
        commited_sections <= commited_sections_wire;
    end

    assign remove = ((refill_state == WRITING_L2  ) & no_completed == {T{1'b1}} & (critical_used | critical_use) & DATA_FROM_L2_BUFFER_VALID ) |
                    ((refill_state == WRITING_VIC ) & no_completed == {T{1'b1}} & (critical_used | critical_use)) |
                    ((refill_state == WAITING_CRIT) &                             (critical_used | critical_use)) |
                    ((refill_state == FLUSHING    ) & no_completed == {T{1'b1}});
    
    
    assign VICTIM_BYPASS = (refill_state == TRANSITION & cur_ctrl != 2'b11 & cur_src != 0 & cur_evic == 0);
    assign VICTIM_BYPASS_ADDRESS = cur_vhit;                            
        
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for writing to tag memory and line memory                                       //
    //////////////////////////////////////////////////////////////////////////////////////////////////
            
    // Port select
    always @(*) begin
        case (refill_state)
            IDLE         : L1_WR_PORT_SELECT = (!CACHE_HIT & VICTIM_HIT & missable_request) ? 2'b10 : 2'b00;
            TRANSITION   :  
                case ({cur_ctrl == 2'b11, cur_src == 0})
                    2'b01   : L1_WR_PORT_SELECT = (DATA_FROM_L2_BUFFER_VALID & (cur_evic == 0)) ? 2'b11 : 2'b00; 
                    2'b00   : L1_WR_PORT_SELECT = 2'b00; 
                    default : L1_WR_PORT_SELECT = 2'b00;
                endcase
            WRITING_L2   : 
                case (no_completed) 
                    0         : L1_WR_PORT_SELECT = (DATA_FROM_L2_BUFFER_VALID & cur_evic      == 0) ? 2'b11 : 2'b00;    
                    {T{1'b1}} : L1_WR_PORT_SELECT = (DATA_FROM_L2_BUFFER_VALID                     ) ? 2'b11 : 2'b00;    
                    1         : L1_WR_PORT_SELECT = (DATA_FROM_L2_BUFFER_VALID & cur_evic      == 0) ? 2'b11 : 2'b00; 
                    default   : L1_WR_PORT_SELECT = (DATA_FROM_L2_BUFFER_VALID                     ) ? 2'b11 : 2'b00; 
                endcase  
            WRITING_VIC  : 
                case (no_completed) 
                    0         : L1_WR_PORT_SELECT = (cur_evic      == 0) ? 2'b10 : 2'b00;    
                    {T{1'b1}} : L1_WR_PORT_SELECT = 2'b10;    
                    1         : L1_WR_PORT_SELECT = (cur_evic      == 0) ? 2'b10 : 2'b00; 
                    default   : L1_WR_PORT_SELECT = 2'b10; 
                endcase     
            WAITING_CRIT : L1_WR_PORT_SELECT = 2'b00;
            default      : L1_WR_PORT_SELECT = 2'b00;
        endcase
    end 
    
    // Addresses
    assign REFILL_TAG_ADDR   = (no_of_elements == 0) ? REFILL_REQ_LINE : cur_line;
    assign REFILL_SECT       = (no_of_elements == 0) ? REFILL_REQ_SECT : (cur_sect + no_completed);
       
    // Data
    assign REFILL_TAG_VALID  = commited_sections_wire;  
    assign REFILL_TAG        = (no_of_elements == 0) ? REFILL_REQ_TAG : cur_tag;
    
    // Write enables
    reg write_test;
    always @(*) begin
        case (refill_state) 
            IDLE         : write_test = (!CACHE_HIT & missable_request & VICTIM_HIT);
            TRANSITION   :  
                case ({cur_ctrl == 2'b11, cur_src == 0})
                    2'b01   : write_test = (DATA_FROM_L2_BUFFER_VALID & (cur_evic == 0)); 
                    2'b00   : write_test = 0; 
                    default : write_test = 0;
                endcase
            WRITING_L2   :
                case (no_completed) 
                    0         : write_test = (DATA_FROM_L2_BUFFER_VALID & (cur_evic == 0));   
                    {T{1'b1}} : write_test =  DATA_FROM_L2_BUFFER_VALID;
                    1         : write_test = (DATA_FROM_L2_BUFFER_VALID & (cur_evic == 0));   
                    default   : write_test =  DATA_FROM_L2_BUFFER_VALID;  
                endcase  
            WRITING_VIC  : 
                case (no_completed) 
                    0         : write_test = (cur_evic == 0);   
                    {T{1'b1}} : write_test = 1;
                    1         : write_test = (cur_evic == 0);   
                    default   : write_test = 1;  
                endcase               
            WAITING_CRIT : write_test = 0;
            default      : write_test = 0;
        endcase
    end    
    
    genvar j;
    generate 
        for (j = 0; j < ASSOCIATIVITY; j = j + 1) begin : REFILL_DST_LOOP
            wire [a - 1 : 0] temp = ((no_of_elements == 0)? REFILL_REQ_DST_SET : cur_set);
            assign REFILL_DST[j] = (temp == j) & write_test;
        end
    endgenerate
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for Victim cache                                                                //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    always @(*) begin
        case (refill_state) 
            IDLE         : VICTIM_COMMIT = (!CACHE_HIT & missable_request & VICTIM_HIT);
            TRANSITION   : VICTIM_COMMIT = 0;
            WRITING_L2   : VICTIM_COMMIT = 0;                
            WRITING_VIC  : 
                case (no_completed) 
                    0         : VICTIM_COMMIT = (cur_evic == 0);   
                    default   : VICTIM_COMMIT = 0;  
                endcase               
            WAITING_CRIT : VICTIM_COMMIT = 0;
            default      : VICTIM_COMMIT = 0;
        endcase
    end     
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for Data from L2                                                                //
    //////////////////////////////////////////////////////////////////////////////////////////////////
     
    always @(*) begin
        if (refill_state == WRITING_L2)
            case (no_completed)
                0         : DATA_FROM_L2_BUFFER_READY = (cur_evic == 0);   
                {T{1'b1}} : DATA_FROM_L2_BUFFER_READY =  1;
                1         : DATA_FROM_L2_BUFFER_READY = (cur_evic == 0);   
                default   : DATA_FROM_L2_BUFFER_READY =  1; 
            endcase
        else if (refill_state == TRANSITION)
            if (cur_src == 0 & DATA_FROM_L2_BUFFER_VALID & cur_evic == 0)
                DATA_FROM_L2_BUFFER_READY = 1;
            else 
                DATA_FROM_L2_BUFFER_READY = 0;
        else
            DATA_FROM_L2_BUFFER_READY = 0;
    end
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Instructions for main pipeline and PC select                                                 //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    
    localparam HITTING = 0;
    localparam WAIT = 1;
    localparam SHIFT0 = 2;
    localparam SHIFT1 = 3;
    localparam SHIFT2 = 4;
    localparam TRANSIT = 5;
    
    reg [2 : 0] pc_state;
    
    always @(*) begin
        // For critical ready
        case (refill_state) 
            IDLE         : critical_ready = !CACHE_HIT & VICTIM_HIT & missable_request;
            TRANSITION   : critical_ready = (cur_ctrl != 2'b11) & ((cur_src == 0) & (cur_evic == 0) & DATA_FROM_L2_BUFFER_VALID);
            WRITING_L2   : critical_ready = (cur_evic == 0) & (no_completed == 0) & DATA_FROM_L2_BUFFER_VALID;
            WRITING_VIC  : critical_ready = (cur_evic == 0) & (no_completed == 0);
            WAITING_CRIT : critical_ready = 0;
            default      : critical_ready = 0;
        endcase
        
        // For critical use
        case (pc_state)
            SHIFT2    :
                case (REFILL_REQ_CTRL)
                    2'b00 : critical_use = 1;                       // This should never happen
                    2'b10 : critical_use = CACHE_HIT & !L1_WR_PORT_SELECT[1];
                    2'b01 : critical_use = CACHE_HIT;
                    2'b11 : critical_use = 1; 
                endcase
            TRANSIT  : 
                case (REFILL_REQ_CTRL)
                    2'b00 : critical_use = 0;                  
                    2'b10 : critical_use = CACHE_HIT & equal_n0 & !L1_WR_PORT_SELECT[1];
                    2'b01 : critical_use = CACHE_HIT & equal_n0;
                    2'b11 : critical_use = 1; 
                endcase
            default  : critical_use = 0;
        endcase
    end
    
    always @(posedge CLK) begin
        case ({critical_ready, critical_use})
            2'b00 : critical_used <= critical_used;
            2'b10 : critical_used <= 1'b0; 
            2'b01 : critical_used <= 1'b1; 
            2'b11 : critical_used <= critical_used;            // Not supposed to occur ever 
        endcase
    end
        
    always @(posedge CLK) begin
        case (pc_state) 
            HITTING : 
                case (REFILL_REQ_CTRL)
                    2'b00 : pc_state <= HITTING;
                    2'b01 : if (CACHE_HIT)
                                if (real_request)
                                    pc_state <= HITTING;
                                else 
                                    pc_state <= SHIFT0;    
                            else
                                if (admissible_request)
                                    if (VICTIM_HIT)
                                        pc_state <= SHIFT0;
                                    else 
                                        pc_state <= WAIT;
                                else 
                                    pc_state <= SHIFT0;     
                    2'b10 : if (CACHE_HIT)
                                if (real_request & !L1_WR_PORT_SELECT[1])
                                    pc_state <= HITTING;
                                else 
                                    pc_state <= SHIFT0;    
                            else
                                if (admissible_request)
                                    if (VICTIM_HIT)
                                        pc_state <= SHIFT0;
                                    else 
                                        pc_state <= WAIT;
                                else 
                                    pc_state <= SHIFT0;     
                    2'b11 : pc_state <= HITTING;
                endcase
                
//                if (admissible_request)
//                    case ({VICTIM_HIT, CACHE_HIT})
//                        2'b00 : pc_state <= WAIT;
//                        2'b01 : pc_state <= HITTING;
//                        2'b10 : pc_state <= SHIFT0;
//                        2'b11 : pc_state <= HITTING;
//                    endcase
//                else if ((real_request & !CACHE_HIT) | (real_request & !l1_rd_from_main_del_1)) 
//                    pc_state <= SHIFT0;
//                else 
//                    pc_state <= HITTING;
            WAIT    :
                if (critical_used == 0 | critical_ready)  //Maybe | (CACHE_HIT & pc_state_del_2 == WAIT) is also needed here
                    pc_state <= SHIFT0;
            
            SHIFT0  : 
                if (L1_RD_PORT_SELECT == 0)
                    pc_state <= SHIFT1;
                    
            SHIFT1  : pc_state <= SHIFT2;
            
            SHIFT2  : 
                case (REFILL_REQ_CTRL)
                    2'b00 : pc_state <= ((no_of_elements == 1)? HITTING : TRANSIT);                       // This should never happen
                    2'b10 : pc_state <= (CACHE_HIT & !L1_WR_PORT_SELECT[1])?
                                                 (((no_of_elements == 1 & remove) | no_of_elements == 0)? HITTING : TRANSIT) : 
                                                 SHIFT0;
                    2'b01 : pc_state <= (CACHE_HIT)?
                                                 (((no_of_elements == 1 & remove) | no_of_elements == 0)? HITTING : TRANSIT) : 
                                                 SHIFT0;
                    2'b11 : pc_state <= ((no_of_elements == 1)? HITTING : TRANSIT); 
                endcase                
            TRANSIT :
                if (no_of_elements == 0) begin
                    case ({VICTIM_HIT, CACHE_HIT})
                        2'b00 : pc_state <= WAIT;
                        2'b01 : pc_state <= HITTING;
                        2'b10 : pc_state <= SHIFT0;
                        2'b11 : pc_state <= HITTING;
                    endcase
                end else begin 
                    case (REFILL_REQ_CTRL)
                        2'b00 : pc_state <= TRANSIT;                        // Let the request through
                        2'b10 : if (equal_n0)
                                    if (CACHE_HIT & !L1_WR_PORT_SELECT[1])
                                        pc_state <= TRANSIT;                // Let the request through
                                    else 
                                        if (cur_src == 0)
                                            if (critical_ready | critical_used == 0)
                                                pc_state <= SHIFT0;
                                            else
                                                pc_state <= WAIT;    
                                        else
                                            pc_state <= SHIFT0;
                                else
                                    if (CACHE_HIT & !L1_WR_PORT_SELECT[1])
                                        if (l1_rd_from_main_del_1)        
                                            pc_state <= TRANSIT;            // Let the request through
                                        else
                                            pc_state <= SHIFT0;
                                    else 
                                        pc_state <= SHIFT0;
                        2'b01 : if (equal_n0)
                                    if (CACHE_HIT)
                                        pc_state <= TRANSIT;                // Let the request through
                                    else 
                                        if (cur_src == 0)
                                            if (critical_ready | critical_used == 0)
                                                pc_state <= SHIFT0;
                                            else
                                                pc_state <= WAIT;    
                                        else
                                            pc_state <= SHIFT0;
                                else
                                    if (CACHE_HIT)
                                        if (l1_rd_from_main_del_1)        
                                            pc_state <= TRANSIT;            // Let the request through
                                        else
                                            pc_state <= SHIFT0;
                                    else 
                                        pc_state <= SHIFT0;
                        2'b11 : pc_state <= TRANSIT;
                    endcase                    
                end
        endcase
    end
                               
    always @(*) begin
        case (pc_state)
            HITTING : case (REFILL_REQ_CTRL)
                        2'b00 : ADDR_FROM_PROC_SEL = 1;
                        2'b01 : if (CACHE_HIT & real_request)
                                    ADDR_FROM_PROC_SEL = 1;
                                else
                                    ADDR_FROM_PROC_SEL = 0;
                        2'b10 : if (CACHE_HIT & real_request & !L1_WR_PORT_SELECT[1])
                                    ADDR_FROM_PROC_SEL = 1;
                                else
                                    ADDR_FROM_PROC_SEL = 0;
                        2'b11 : ADDR_FROM_PROC_SEL = 1;
                      endcase
            WAIT    : ADDR_FROM_PROC_SEL = 0;
            SHIFT0  : ADDR_FROM_PROC_SEL = 0;
            SHIFT1  : ADDR_FROM_PROC_SEL = 0;
            SHIFT2  : case (REFILL_REQ_CTRL)
                        2'b00 : ADDR_FROM_PROC_SEL = 1;                       
                        2'b10 : ADDR_FROM_PROC_SEL = (CACHE_HIT & !L1_WR_PORT_SELECT[1])? 1 : 0;
                        2'b01 : ADDR_FROM_PROC_SEL = (CACHE_HIT)? 1 : 0;
                        2'b11 : ADDR_FROM_PROC_SEL = 1; 
                     endcase    
            TRANSIT : if (no_of_elements == 0) begin
                         case (REFILL_REQ_CTRL)
                            2'b00 : ADDR_FROM_PROC_SEL = 1;
                            2'b01 : if (CACHE_HIT & real_request)
                                        ADDR_FROM_PROC_SEL = 1;
                                    else
                                        ADDR_FROM_PROC_SEL = 0;
                            2'b10 : if (CACHE_HIT & real_request & !L1_WR_PORT_SELECT[1])
                                        ADDR_FROM_PROC_SEL = 1;
                                    else
                                        ADDR_FROM_PROC_SEL = 0;
                            2'b11 : ADDR_FROM_PROC_SEL = 1;
                          endcase
                     end else begin 
                         case (REFILL_REQ_CTRL)
                             2'b00 : ADDR_FROM_PROC_SEL = 1;                     // Let the request through
                             2'b10 : if (equal_n0)
                                         if (CACHE_HIT & !L1_WR_PORT_SELECT[1])
                                             ADDR_FROM_PROC_SEL = 1;             // Let the request through
                                         else 
                                             ADDR_FROM_PROC_SEL = 0; 
                                     else
                                         if (CACHE_HIT & !L1_WR_PORT_SELECT[1] & l1_rd_from_main_del_1)        
                                             ADDR_FROM_PROC_SEL = 1; 
                                         else 
                                             ADDR_FROM_PROC_SEL = 0; 
                             2'b01 : if (equal_n0)
                                         if (CACHE_HIT)
                                             ADDR_FROM_PROC_SEL = 1;             // Let the request through
                                         else 
                                             ADDR_FROM_PROC_SEL = 0; 
                                     else
                                         if (CACHE_HIT & l1_rd_from_main_del_1)        
                                             ADDR_FROM_PROC_SEL = 1;             // Let the request through
                                         else 
                                             ADDR_FROM_PROC_SEL = 0; 
                             2'b11 : ADDR_FROM_PROC_SEL = 1; 
                         endcase                    
                     end
            default : ADDR_FROM_PROC_SEL = 0;
        endcase
                                      
        case (pc_state)
            HITTING : case (REFILL_REQ_CTRL)
                        2'b00 : CACHE_READY = 1;
                        2'b01 : if (CACHE_HIT & real_request)
                                    CACHE_READY = 1;
                                else
                                    CACHE_READY = 0; 
                        2'b10 : if (CACHE_HIT & real_request & !L1_WR_PORT_SELECT[1])
                                    CACHE_READY = 1;  
                                else
                                    CACHE_READY = 0;     
                        2'b11 : CACHE_READY = 1;
                      endcase
            WAIT    : CACHE_READY = 0;
            SHIFT0  : CACHE_READY = 0;
            SHIFT1  : CACHE_READY = 0;
            SHIFT2  : case (REFILL_REQ_CTRL)
                        2'b00 : CACHE_READY = 1;                       // This should never happen
                        2'b10 : CACHE_READY = (CACHE_HIT & !L1_WR_PORT_SELECT[1])? 1 : 0;
                        2'b01 : CACHE_READY = (CACHE_HIT)? 1 : 0;
                        2'b11 : CACHE_READY = 1; 
                      endcase         
            TRANSIT : if (no_of_elements == 0) begin
                          case (REFILL_REQ_CTRL)
                            2'b00 : CACHE_READY = 1;
                            2'b01 : if (CACHE_HIT & real_request)
                                        CACHE_READY = 1;
                                    else
                                        CACHE_READY = 0; 
                            2'b10 : if (CACHE_HIT & real_request & !L1_WR_PORT_SELECT[1])
                                        CACHE_READY = 1;  
                                    else
                                        CACHE_READY = 0;     
                            2'b11 : CACHE_READY = 1;
                          endcase
                      end else begin 
                          case (REFILL_REQ_CTRL)
                              2'b00 : CACHE_READY = 1;                        // Let the request through
                              2'b10 : if (equal_n0)
                                          if (CACHE_HIT & !L1_WR_PORT_SELECT[1])
                                              CACHE_READY = 1;                // Let the request through
                                          else 
                                              CACHE_READY = 0;
                                      else
                                          if (CACHE_HIT & !L1_WR_PORT_SELECT[1] & l1_rd_from_main_del_1)        
                                              CACHE_READY = 1;                // Let the request through
                                          else 
                                              CACHE_READY = 0;
                              2'b01 : if (equal_n0)
                                          if (CACHE_HIT)
                                              CACHE_READY = 1;               // Let the request through
                                          else 
                                              CACHE_READY = 0;
                                      else
                                          if (CACHE_HIT & l1_rd_from_main_del_1)        
                                              CACHE_READY = 1;            // Let the request through
                                          else 
                                              CACHE_READY = 0;
                              2'b11 : CACHE_READY = 1;
                          endcase                    
                      end
            default : CACHE_READY = 0;
        endcase
    end
    
    assign MAIN_PIPE_ENB      = (pc_state != WAIT) & !(pc_state == SHIFT0 & L1_RD_PORT_SELECT != 0);
    
       
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Initial values                                                                               //
    //////////////////////////////////////////////////////////////////////////////////////////////////
        
    initial begin
        no_of_elements = 0;
       
        main_pipe_enb_del_2 = 1;
        main_pipe_enb_del_1 = 1;
        
        real_request        = 0;
        missable_request    = 0;
        flush_request       = 0;
        admissible_request  = 0;
        
        l1_rd_from_main       = 0;
        l1_rd_from_main_del_1 = 0;
        
        l1_rd_from_proc       = 1;
        l1_rd_from_proc_del_1 = 1;
        
        evic_state     = E_HITTING;
        evic_no        = 0;
        
        cur_evic = 0;
        fir_evic = 0;
        sec_evic = 0;
        thr_evic = 0;
        
        refill_state = 1;   
        pc_state = HITTING;      
        
        critical_used = 1; 
    end
         
    // Temporary stuff
    assign CACHE_PIPE_ENB = VICTIM_CACHE_READY;
         
    // Log value calculation
    function integer logb2;
       input integer depth;
       for (logb2 = 0; depth > 1; logb2 = logb2 + 1)
           depth = depth >> 1;
    endfunction

    
endmodule
