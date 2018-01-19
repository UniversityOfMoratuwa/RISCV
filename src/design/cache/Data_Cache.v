
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Moratuwa
// Engineer: Ravi Tharaka
// 
// Create Date: 12/28/2016 12:30:04 PM
// Design Name: 
// Module Name: Data_Cache
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


module Data_Cache #(
        // Fixed parameters
        localparam ADDR_WIDTH       = 32,
        localparam DATA_WIDTH       = 32,
        
        // Primary parameters
        parameter S                 = 17,                    // Size of the cache will be 2^S bits
        parameter B                 = 9,                     // Size of a block will be 2^B bits
        parameter a                 = 1,                     // Associativity of the cache would be 2^a
        parameter T                 = 1,                     // Width to depth translation amount
        parameter W                 = 7,                     // Width of the L2-L1 bus would be 2^W
        parameter L2_DELAY_RD       = 7,                     // Read delay of the second level of cache
        parameter V                 = 2,                     // Size of the victim cache will be 2^V cache lines
        
        // Calculated parameters
        localparam BYTES_PER_WORD   = logb2(DATA_WIDTH/8),
        localparam WORDS_PER_BLOCK  = B - 5,
        localparam WORDS_PER_SECT   = B - T - 5,     
                
        localparam CACHE_SIZE       = 1 << S,
        localparam BLOCK_SIZE       = 1 << B,
        localparam ASSOCIATIVITY    = 1 << a,       
        
        localparam TAG_WIDTH        = ADDR_WIDTH + 3 + a - S,
        localparam LINE_ADDR_WIDTH  = S - a - B + T,
        localparam TAG_ADDR_WIDTH   = S - a - B, 
        
        localparam L2_BUS_WIDTH     = 1 << W,
        localparam BLOCK_SECTIONS   = 1 << T, 
        
        localparam SET_SIZE         = CACHE_SIZE / ASSOCIATIVITY,
        localparam LINE_RAM_WIDTH   = 1 << (B - T),
        localparam LINE_RAM_DEPTH   = 1 << LINE_ADDR_WIDTH,
        
        localparam TAG_RAM_WIDTH    = TAG_WIDTH + BLOCK_SECTIONS + 1,       // +1 for dirty bit
        localparam TAG_RAM_DEPTH    = 1 << TAG_ADDR_WIDTH,
        
        localparam L2_BURST         = 1 << (B - W)             
    ) (
        input CLK,
        
        // Ports towards the processor
        input      [4              - 1 : 0] BYTE_ENB_FROM_PROC,             // Four byte enable lines for cache writing
        input      [2              - 1 : 0] CONTROL_FROM_PROC,              // CONTROL_FROM_PROC = {00(idle), 01(read), 10(write), 11(flush address from cache)}
        input      [ADDR_WIDTH     - 1 : 0] ADDR_FROM_PROC,
        input      [DATA_WIDTH     - 1 : 0] DATA_FROM_PROC,
        output reg [DATA_WIDTH     - 1 : 0] DATA_TO_PROC=0,
        
        output                              CACHE_READY,
        
        // Ports towards the L2 cache
        input                               WR_TO_L2_READY,
        output                              WR_TO_L2_VALID,
        output     [ADDR_WIDTH - 2 - 1 : 0] WR_ADDR_TO_L2,
        output     [L2_BUS_WIDTH   - 1 : 0] DATA_TO_L2,
        output                              WR_CONTROL_TO_L2,
        input                               WR_COMPLETE,
        
        input                               RD_ADDR_TO_L2_READY,
        output                              RD_ADDR_TO_L2_VALID,
        output reg [ADDR_WIDTH - 2 - 1 : 0] RD_ADDR_TO_L2,
        
        input                               DATA_FROM_L2_VALID,
        output                              DATA_FROM_L2_READY,
        input      [L2_BUS_WIDTH   - 1 : 0] DATA_FROM_L2        
        
    );
    
    //////////////////////////////////////////////////////////////////////////////
    // Globally important wires and signals                                     //
    //////////////////////////////////////////////////////////////////////////////
            
    wire                      send_rd_addr_to_L2;        // Instructs the RD_ADDR_TO_L2 unit to send address to L2  
    
    wire                      refill_from_L2_ready;      // Instructs the DATA_FROM_L2 unit that the data it has is ready to be sampled
    wire                      refill_from_L2_valid;      // States the DATA_FROM_L2 unit has valid data 
      
    wire                      cache_pipe_enb;            // Enables the cache processes
    wire                      main_pipe_enb;             // Enables the main processor pipeline
    wire                      input_from_proc_sel;       // input_from_proc_sel = {0(addr_from_proc_del_2), 1 (ADDR_FROM_PROC)}, same for control and data from processor also
    
    wire                      cache_hit;                 // L1 cache has hit
    wire                      victim_hit;                // Victim cache has hit
    
    wire                      victim_cache_ready;        // Victim cache is ready to write
    wire                      victim_cache_valid;        // Victim cache write is valid
    
    wire [DATA_WIDTH - 1 : 0] data_to_proc;        // Data going back to the processor   
        
    //////////////////////////////////////////////////////////////////////////////
    // Cache data path - Decoding the read/write address                        //
    //////////////////////////////////////////////////////////////////////////////
    
    // Selecting whether the processor or cache itself (to evict data to victim cache) has access to the read port of L1
    wire                             rd_port_select;                     // Selects the inputs to the Read ports of L1 {0(from processor), 1(from evict control)}         
    wire [TAG_WIDTH       - 1 : 0]   evict_tag;
    wire [TAG_ADDR_WIDTH  - 1 : 0]   evict_tag_addr;
    wire [T               - 1 : 0]   evict_sect; 
    wire [LINE_ADDR_WIDTH - 1 : 0]   evict_line = {evict_tag_addr, evict_sect};  
    
    // Register for the previous stage
    reg  [ADDR_WIDTH      - 1 : 0]   addr_from_proc;
    reg  [DATA_WIDTH      - 1 : 0]   data_from_proc;
    reg  [2               - 1 : 0]   control_from_proc;
    reg  [4               - 1 : 0]   byte_enb_from_proc;
        
    wire [BYTES_PER_WORD  - 1 : 0]   byte_address        = (rd_port_select)? 0              : addr_from_proc[0                                  +: BYTES_PER_WORD   ];
    wire [WORDS_PER_SECT  - 1 : 0]   word_address        = (rd_port_select)? 0              : addr_from_proc[BYTES_PER_WORD                     +: WORDS_PER_SECT   ];
    wire [LINE_ADDR_WIDTH - 1 : 0]   line_address        = (rd_port_select)? evict_line     : addr_from_proc[(BYTES_PER_WORD + WORDS_PER_SECT)  +: LINE_ADDR_WIDTH  ];
    wire [TAG_ADDR_WIDTH  - 1 : 0]   tag_address         = (rd_port_select)? evict_tag_addr : addr_from_proc[(BYTES_PER_WORD + WORDS_PER_BLOCK) +: TAG_ADDR_WIDTH   ];
    wire [TAG_WIDTH       - 1 : 0]   tag                 = (rd_port_select)? evict_tag      : addr_from_proc[(ADDR_WIDTH - 1)                   -: TAG_WIDTH        ];
    wire [T               - 1 : 0]   section_address     = (rd_port_select)? evict_sect     : addr_from_proc[(BYTES_PER_WORD + WORDS_PER_SECT)  +: T                ];    
    
    // Cache pipeline registers
    reg  [WORDS_PER_SECT  - 1 : 0]   word_address_del_1,    word_address_del_2;
    reg  [TAG_ADDR_WIDTH  - 1 : 0]   tag_address_del_1,     tag_address_del_2;
    reg  [TAG_WIDTH       - 1 : 0]   tag_del_1,             tag_del_2,             tag_del_3;
    reg  [T               - 1 : 0]   section_address_del_1, section_address_del_2;
    
    reg  [2               - 1 : 0]   control_del_1,         control_del_2;
    reg  [4               - 1 : 0]   byte_enb_del_1,        byte_enb_del_2;
    reg  [DATA_WIDTH      - 1 : 0]   data_del_1,            data_del_2;
    
    // Main pipeline registers
    reg  [ADDR_WIDTH      - 1 : 0]   addr_from_proc_del_1,     addr_from_proc_del_2;
    reg  [DATA_WIDTH      - 1 : 0]   data_from_proc_del_1,     data_from_proc_del_2;
    reg  [2               - 1 : 0]   control_from_proc_del_1,  control_from_proc_del_2;
    reg  [4               - 1 : 0]   byte_enb_from_proc_del_1, byte_enb_from_proc_del_2;
        
    
    always @(posedge CLK) begin
        // Pipeline for internal address requests (cache level addresses)
        if (cache_pipe_enb) begin
            tag_del_1             <= tag;
            section_address_del_1 <= section_address;
            word_address_del_1    <= word_address;
            tag_address_del_1     <= tag_address;
            
            control_del_1         <= control_from_proc;
            byte_enb_del_1        <= byte_enb_from_proc;
            data_del_1            <= data_from_proc;
                                    
            tag_del_2             <= tag_del_1;
            section_address_del_2 <= section_address_del_1;
            word_address_del_2    <= word_address_del_1;
            tag_address_del_2     <= tag_address_del_1;
            
            control_del_2         <= control_del_1;
            byte_enb_del_2        <= byte_enb_del_1;
            data_del_2            <= data_del_1; 
            
            tag_del_3             <= tag_del_2;
        end    
        
        // Pipeline for the main processor
        if (main_pipe_enb) begin
            if (addr_from_proc_sel) begin
                addr_from_proc     <= ADDR_FROM_PROC;
                data_from_proc     <= DATA_FROM_PROC;
                control_from_proc  <= CONTROL_FROM_PROC;
                byte_enb_from_proc <= BYTE_ENB_FROM_PROC;
            end else begin
                addr_from_proc     <= addr_from_proc_del_2;
                data_from_proc     <= data_from_proc_del_2;
                control_from_proc  <= control_from_proc_del_2;
                byte_enb_from_proc <= byte_enb_from_proc_del_2;
            end
        
            addr_from_proc_del_1     <= addr_from_proc;
            data_from_proc_del_1     <= data_from_proc;
            control_from_proc_del_1  <= control_from_proc;
            byte_enb_from_proc_del_1 <= byte_enb_from_proc;
            
            addr_from_proc_del_2     <= addr_from_proc_del_1;
            data_from_proc_del_2     <= data_from_proc_del_1;
            control_from_proc_del_2  <= control_from_proc_del_1;
            byte_enb_from_proc_del_2 <= byte_enb_from_proc_del_1;
        end            
    end
    
    //////////////////////////////////////////////////////////////////////////////
    // Cache data path - Memories and muxes                                     //
    //////////////////////////////////////////////////////////////////////////////
    
    // Wires for the tag memories
    wire [ASSOCIATIVITY   - 1 : 0] tag_mem_wr_enb;     
    wire [ASSOCIATIVITY   - 1 : 0] dirty_mem_wr_enb;     
    wire [TAG_ADDR_WIDTH  - 1 : 0] tag_mem_wr_addr; 
    wire [TAG_WIDTH       - 1 : 0] tag_to_ram;
    wire [BLOCK_SECTIONS  - 1 : 0] tag_valid_to_ram;
    wire                           dirty_to_ram;
         
    wire                           tag_mem_rd_enb;
    wire [TAG_WIDTH       - 1 : 0] tag_from_ram             [0 : ASSOCIATIVITY - 1];
    wire [BLOCK_SECTIONS  - 1 : 0] tag_valid_from_ram       [0 : ASSOCIATIVITY - 1];
    wire                           dirty_from_ram           [0 : ASSOCIATIVITY - 1];
    
    assign tag_mem_rd_enb = cache_pipe_enb;
    
    // Wires for the line memories
    wire [ASSOCIATIVITY   - 1 : 0] lin_mem_wr_enb;     
    wire [LINE_ADDR_WIDTH - 1 : 0] lin_mem_wr_addr;   
    wire [LINE_RAM_WIDTH  - 1 : 0] lin_mem_data_in;    
                    
    wire                           lin_mem_rd_enb;
    wire [LINE_RAM_WIDTH  - 1 : 0] lin_data_out             [0 : ASSOCIATIVITY - 1];
    
    assign lin_mem_rd_enb = cache_pipe_enb;
                  
    // Tag comparison and validness checking 
    wire [ASSOCIATIVITY   - 1 : 0] tag_valid_wire;                     // Whether the tag is valid for the given section of the cache block (DM2)
    reg  [ASSOCIATIVITY   - 1 : 0] tag_match;                          // Tag matches in a one-hot encoding (DM3)
    reg  [ASSOCIATIVITY   - 1 : 0] tag_valid;                          // Whether the tag is valid for the given section of the cache block (DM3)
    wire [ASSOCIATIVITY   - 1 : 0] hit_set_wire;                       // Whether tag matches and is valid
    reg  [ASSOCIATIVITY   - 1 : 0] tag_equal_n0, tag_equal_n1;         // To pre-calculate whether eviction is corrupted due to closeby writes
        
    assign hit_set_wire  = (tag_valid & tag_match);
    assign cache_hit     = |hit_set_wire;    
               
    // Set multiplexer wires    
    wire [a                              - 1 : 0] set_select;          // Tag matches in a binary encoding  
    
    wire [ASSOCIATIVITY * LINE_RAM_WIDTH - 1 : 0] lin_ram_out_dearray; 
    reg  [ASSOCIATIVITY * TAG_WIDTH      - 1 : 0] tag_ram_out_dearray; 
    reg  [ASSOCIATIVITY * 1              - 1 : 0] dirty_ram_out_dearray; 
    reg  [ASSOCIATIVITY * 1              - 1 : 0] valid_ram_out_dearray; 
    
    wire [LINE_RAM_WIDTH                 - 1 : 0] data_set_mux_out;    // Data after selecting the proper set
    wire [TAG_WIDTH                      - 1 : 0] tag_set_mux_out;     // Tag after selecting the proper set
    wire                                          dirty_set_mux_out;   // Dirty after selecting the proper set
    wire                                          valid_set_mux_out;   // Valid after selecting the proper set
                           
    genvar i;
    generate
        for (i = 0; i < ASSOCIATIVITY; i = i + 1) begin : ASSOC_LOOP
            Mem_Simple_Dual_Port #(
                .RAM_WIDTH(TAG_RAM_WIDTH - 1),              // Specify RAM data width
                .RAM_DEPTH(TAG_RAM_DEPTH),                  // Specify RAM depth (number of entries)
                .RAM_PERFORMANCE("LOW_LATENCY"),            // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
                .INIT_FILE("")                              // Specify name/location of RAM initialization file if using one (leave blank if not)
            ) tag_memory (
                .CLK(CLK),                                                                  // Clock
                .WR_ENB(tag_mem_wr_enb[i]),                                                 // Write enable
                .ADDR_W(tag_mem_wr_addr),                                                   // Write address bus, width determined from RAM_DEPTH
                .DATA_IN({tag_valid_to_ram, tag_to_ram}),                                   // RAM input data, width determined from RAM_WIDTH
                .ADDR_R(tag_address),                                                       // Read address bus, width determined from RAM_DEPTH
                .RD_ENB(tag_mem_rd_enb),                                                    // Read Enable, for additional power savings, disable when not in use
                .DATA_OUT({tag_valid_from_ram[i], tag_from_ram[i]}),     // RAM output data, width determined from RAM_WIDTH
                .OUT_RST(1'b0),                                                             // Output reset (does not affect memory contents)
                .OUT_ENB(tag_mem_rd_enb)                                                    // Output register enable                
            );
            
            Mem_Simple_Dual_Port #(
                .RAM_WIDTH(1),                              // Specify RAM data width
                .RAM_DEPTH(TAG_RAM_DEPTH),                  // Specify RAM depth (number of entries)
                .RAM_PERFORMANCE("LOW_LATENCY"),            // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
                .INIT_FILE("")                              // Specify name/location of RAM initialization file if using one (leave blank if not)
            ) dirty_memory (
                .CLK(CLK),                                                                  // Clock
                .WR_ENB(dirty_mem_wr_enb[i]),                                               // Write enable
                .ADDR_W(tag_mem_wr_addr),                                                   // Write address bus, width determined from RAM_DEPTH
                .DATA_IN(dirty_to_ram),                                                     // RAM input data, width determined from RAM_WIDTH
                .ADDR_R(tag_address),                                                       // Read address bus, width determined from RAM_DEPTH
                .RD_ENB(tag_mem_rd_enb),                                                    // Read Enable, for additional power savings, disable when not in use
                .DATA_OUT(dirty_from_ram[i]),                                               // RAM output data, width determined from RAM_WIDTH
                .OUT_RST(1'b0),                                                             // Output reset (does not affect memory contents)
                .OUT_ENB(tag_mem_rd_enb)                                                    // Output register enable                
            );
            
            // Tag comparison and validness checking
            Multiplexer #(
                .ORDER(T),
                .WIDTH(1)
            ) tag_valid_mux (
                .SELECT(section_address_del_1),
                .IN(tag_valid_from_ram[i]),
                .OUT(tag_valid_wire[i])
            );
            
            always @(posedge CLK) begin
                if (cache_pipe_enb) begin
                    tag_match[i] <= (tag_del_1 == tag_from_ram[i]);
                    tag_valid[i] <= tag_valid_wire[i];
                    
                    tag_equal_n0[i] <= (tag_del_2 == tag_from_ram[i]);
                    tag_equal_n1[i] <= (tag_del_3 == tag_from_ram[i]);
                    
                    tag_ram_out_dearray[TAG_WIDTH * i +: TAG_WIDTH] <= tag_from_ram[i];
                    dirty_ram_out_dearray[i] <= dirty_from_ram[i];
                    valid_ram_out_dearray[i] <= tag_valid_wire[i];
                end
            end
            
            Mem_Simple_Dual_Port #(
                .RAM_WIDTH(LINE_RAM_WIDTH),             // Specify RAM data width
                .RAM_DEPTH(LINE_RAM_DEPTH),             // Specify RAM depth (number of entries)
                .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
                .INIT_FILE("")                          // Specify name/location of RAM initialization file if using one (leave blank if not)
            ) line_memory (
                .CLK(CLK),                         // Clock
                .WR_ENB(lin_mem_wr_enb[i]),        // Write enable
                .ADDR_W(lin_mem_wr_addr),          // Write address bus, width determined from RAM_DEPTH
                .DATA_IN(lin_mem_data_in),         // RAM input data, width determined from RAM_WIDTH
                .RD_ENB(lin_mem_rd_enb),           // Read Enable, for additional power savings, disable when not in use
                .ADDR_R(line_address),             // Read address bus, width determined from RAM_DEPTH
                .DATA_OUT(lin_data_out[i]),        // RAM output data, width determined from RAM_WIDTH
                .OUT_RST(1'b0),                    // Output reset (does not affect memory contents)
                .OUT_ENB(lin_mem_rd_enb)           // Output register enable
            );
            
            // De-array the lin_data_out wire
            assign lin_ram_out_dearray [LINE_RAM_WIDTH * i +: LINE_RAM_WIDTH] = lin_data_out  [i];
        end
    endgenerate
    
    // Storing data from previous cycles, since data_set_mux_out is not always the most updated one
    reg  [DATA_WIDTH      - 1 : 0] data_del_3,         data_del_4;
    reg  [WORDS_PER_SECT  - 1 : 0] word_address_del_3, word_address_del_4;
    reg                            equal_n0, equal_n1, equal_n1_pre_1;                  // For deciding the data for L1 writes
    
    reg                            dirty_to_ram_del_1, dirty_to_ram_del_2;
    reg                            equal_addr0, equal_addr1;                            // For deciding the eviction data
    reg                            equal_sect0, equal_sect1;                            
    wire                           equal_tag0,  equal_tag1;                             
    reg                            equal_addr1_pre_1, equal_sect1_pre_1;                  
    wire                           equal_r0, equal_r1;
    wire                           equal_e0, equal_e1;
    
    reg  [LINE_RAM_WIDTH  - 1 : 0] l1_data_out;
    reg  [LINE_RAM_WIDTH  - 1 : 0] l1_evict_out;
    reg                            l1_dirty_out;
    
    assign equal_e0 = equal_addr0 & equal_tag0;
    assign equal_e1 = equal_addr1 & equal_tag1;
    
    assign equal_r0 = equal_addr0 & equal_sect0 & equal_tag0;
    assign equal_r1 = equal_addr1 & equal_sect1 & equal_tag1;
    
    // Eviction equal, set selection multiplexer 
    Multiplexer #(
        .ORDER(a),
        .WIDTH(1)
    ) evict_equal_n0_set_mux (
        .SELECT(set_select),
        .IN(tag_equal_n0),
        .OUT(equal_tag0)
    );
    
    Multiplexer #(
        .ORDER(a),
        .WIDTH(1)
    ) evict_equal_n1_set_mux (
        .SELECT(set_select),
        .IN(tag_equal_n1),
        .OUT(equal_tag1)
    );
    
    always @(posedge CLK) begin
         if (cache_pipe_enb) begin
            // Find if previous request and current request are same
            equal_n0       <= ({tag_del_2, tag_address_del_2, section_address_del_2} == {tag_del_1, tag_address_del_1, section_address_del_1}) & (control_del_2 == 2'b10) & CACHE_READY; //(DM3 == DM2)
            equal_n1_pre_1 <= ({tag_del_2, tag_address_del_2, section_address_del_2} == {tag,       tag_address      , section_address      }) & (control_del_2 == 2'b10) & CACHE_READY; //(DM3 == DM1) 
            equal_n1       <= equal_n1_pre_1;   
                        
            // Find if eviction from L1 is corrupted because of nearby L1 cache writes (if cache is written in previous 2 cycles, L1 output will not be the most recent)
            equal_addr0       <= (tag_address_del_2 == tag_address_del_1) & (control_del_2 == 2'b10) & CACHE_READY; //(DM3 == DM2)
            equal_addr1_pre_1 <= (tag_address_del_2 == tag_address      ) & (control_del_2 == 2'b10) & CACHE_READY; //(DM3 == DM1) 
            equal_sect0       <= (section_address_del_2 == section_address_del_1); //(DM3 == DM2)
            equal_sect1_pre_1 <= (section_address_del_2 == section_address      ); //(DM3 == DM1) 
            
            equal_addr1       <= equal_addr1_pre_1;
            equal_sect1       <= equal_sect1_pre_1;
            
            // Requires previous data and addresses    
            word_address_del_3 <= word_address_del_2;
            word_address_del_4 <= word_address_del_3;
            
            // Data delay 3 according to byte enable lines
            data_del_3[ 7 :  0] <= (byte_enb_del_2[0])? data_del_2[ 7 :  0] : data_to_proc[ 7 :  0];
            data_del_3[15 :  8] <= (byte_enb_del_2[1])? data_del_2[15 :  8] : data_to_proc[15 :  8];
            data_del_3[23 : 16] <= (byte_enb_del_2[2])? data_del_2[23 : 16] : data_to_proc[23 : 16];
            data_del_3[31 : 24] <= (byte_enb_del_2[3])? data_del_2[31 : 24] : data_to_proc[31 : 24];
            data_del_4 <= data_del_3;
            
            dirty_to_ram_del_1 <= dirty_to_ram;
            dirty_to_ram_del_2 <= dirty_to_ram_del_1;
        end
    end     
           
    genvar z;
    generate 
        for (z = 0; z < (1 << WORDS_PER_SECT); z = z + 1) begin : DM3_LOOP
            always @(*) begin
                case ({equal_n0, equal_n1}) 
                    2'b00 : l1_data_out[DATA_WIDTH * z +: DATA_WIDTH] = data_set_mux_out[DATA_WIDTH * z +: DATA_WIDTH];
                    2'b10 : l1_data_out[DATA_WIDTH * z +: DATA_WIDTH] = (word_address_del_3 == z) ? data_del_3 : data_set_mux_out[DATA_WIDTH * z +: DATA_WIDTH];
                    2'b01 : l1_data_out[DATA_WIDTH * z +: DATA_WIDTH] = (word_address_del_4 == z) ? data_del_4 : data_set_mux_out[DATA_WIDTH * z +: DATA_WIDTH];
                    2'b11 : begin
                        case ({word_address_del_3 == z, word_address_del_4 == z}) 
                            2'b00 : l1_data_out[DATA_WIDTH * z +: DATA_WIDTH] = data_set_mux_out[DATA_WIDTH * z +: DATA_WIDTH];
                            2'b01 : l1_data_out[DATA_WIDTH * z +: DATA_WIDTH] = data_del_4;
                            2'b10 : l1_data_out[DATA_WIDTH * z +: DATA_WIDTH] = data_del_3;
                            2'b11 : l1_data_out[DATA_WIDTH * z +: DATA_WIDTH] = data_del_3;
                        endcase
                    end
                endcase
            end
            
            always @(*) begin
                case ({equal_r0, equal_r1}) 
                    2'b00 : l1_evict_out[DATA_WIDTH * z +: DATA_WIDTH] = data_set_mux_out[DATA_WIDTH * z +: DATA_WIDTH];
                    2'b10 : l1_evict_out[DATA_WIDTH * z +: DATA_WIDTH] = (word_address_del_3 == z) ? data_del_3 : data_set_mux_out[DATA_WIDTH * z +: DATA_WIDTH];
                    2'b01 : l1_evict_out[DATA_WIDTH * z +: DATA_WIDTH] = (word_address_del_4 == z) ? data_del_4 : data_set_mux_out[DATA_WIDTH * z +: DATA_WIDTH];
                    2'b11 : begin
                        case ({word_address_del_3 == z, word_address_del_4 == z}) 
                            2'b00 : l1_evict_out[DATA_WIDTH * z +: DATA_WIDTH] = data_set_mux_out[DATA_WIDTH * z +: DATA_WIDTH];
                            2'b01 : l1_evict_out[DATA_WIDTH * z +: DATA_WIDTH] = data_del_4;
                            2'b10 : l1_evict_out[DATA_WIDTH * z +: DATA_WIDTH] = data_del_3;
                            2'b11 : l1_evict_out[DATA_WIDTH * z +: DATA_WIDTH] = data_del_3;
                        endcase
                    end
                endcase
            end
        end
        
        always @(*) begin
            case ({equal_e0, equal_e1}) 
                2'b00 : l1_dirty_out = dirty_set_mux_out;
                2'b10 : l1_dirty_out = dirty_to_ram_del_1;
                2'b01 : l1_dirty_out = dirty_to_ram_del_2;
                2'b11 : l1_dirty_out = dirty_to_ram_del_1;                
            endcase
        end
    endgenerate

    // Replacement policy unit
    Replacement_Unit #(
        .S(S),
        .B(B),
        .a(a)
    ) replacement_unit (
        .CLK(CLK),
        //.BLOCK(tag_address_del_1),
        .REPLACE(replace)
    );
        
    // Convert the tag match values from one hot format (from equal units) to binary format  
    OneHot_to_Bin #(
        .ORDER(a)
    ) set_decoder (
        .ONE_HOT(hit_set_wire),
        .DEFAULT(replace),
        .BIN(set_select)
    );
    
    // L1 data, set selection multiplexer 
    Multiplexer #(
        .ORDER(a),
        .WIDTH(LINE_RAM_WIDTH)
    ) data_set_mux (
        .SELECT(set_select),
        .IN(lin_ram_out_dearray),
        .OUT(data_set_mux_out)
    );
    
    // L1 tag, set selection multiplexer 
    Multiplexer #(
        .ORDER(a),
        .WIDTH(TAG_WIDTH)
    ) tag_set_mux (
        .SELECT(set_select),
        .IN(tag_ram_out_dearray),
        .OUT(tag_set_mux_out)
    );
    
    // Dirty, set selection multiplexer 
    Multiplexer #(
        .ORDER(a),
        .WIDTH(1)
    ) dirty_set_mux (
        .SELECT(set_select),
        .IN(dirty_ram_out_dearray),
        .OUT(dirty_set_mux_out)
    );
    
    // Valid, set selection multiplexer 
    Multiplexer #(
        .ORDER(a),
        .WIDTH(1)
    ) valid_set_mux (
        .SELECT(set_select),
        .IN(valid_ram_out_dearray),
        .OUT(valid_set_mux_out)
    );
    
    // Word selection multiplexer
    Multiplexer #(
        .ORDER(WORDS_PER_SECT),
        .WIDTH(DATA_WIDTH)
    ) word_mux (
        .SELECT(word_address_del_2),
        .IN(l1_data_out),
        .OUT(data_to_proc)
    );
    
    // If cache is hitting and instruction is to read, send the data back
    always @(posedge CLK) begin
        if (CACHE_READY & (control_from_proc_del_2 == 2'b01)) begin
            DATA_TO_PROC <= data_to_proc;
        end
       
    end
    
    
    //////////////////////////////////////////////////////////////////////////////
    // Refill path - Address to L2 section                                      //
    //////////////////////////////////////////////////////////////////////////////
       
    // Queue for storing bursts of L2 requests 
    wire [ADDR_WIDTH - 2 - 1 : 0] fetch_queue_out;
    wire                          fetch_queue_empty;
    
    // Ready signal from the RD_ADDR_TO_L2 output register
    wire                          rd_addr_to_L2_ready;     
        
    // A 3-deep low-latency FWFT FIFO for storing high priority fetch requests
    Fetch_Queue #(
        .WIDTH(ADDR_WIDTH - 2)
    ) fetch_queue (
        .CLK(CLK),
        .TOP_VALID(send_rd_addr_to_L2),
        .BOT_READY(rd_addr_to_L2_ready),
        .DATA_IN({tag_del_2, tag_address_del_2, section_address_del_2, word_address_del_2}),
        .DATA_OUT(fetch_queue_out),
        .EMPTY(fetch_queue_empty)
    );
    
    // A final multiplexer to send requests immediately, or after queueing
    wire [ADDR_WIDTH - 2 - 1 : 0] rd_addr_to_L2;    
    
    Multiplexer #(
        .ORDER(1),
        .WIDTH(ADDR_WIDTH - 2)
    ) rd_addr_to_L2_mux (
        .SELECT(fetch_queue_empty),
        .IN({{tag_del_2, tag_address_del_2, section_address_del_2, word_address_del_2}, fetch_queue_out}),
        .OUT(rd_addr_to_L2)
    );
    
    // Output register holding the current RD_ADDR_TO_L2
    wire                        rd_addr_to_L2_valid;
    reg                         rd_addr_to_L2_full; 
           
    assign rd_addr_to_L2_valid = (send_rd_addr_to_L2 | !fetch_queue_empty);
        
    always @(posedge CLK) begin
        // Output address register for the L2 cache
        if ((rd_addr_to_L2_valid & RD_ADDR_TO_L2_READY) | (!rd_addr_to_L2_full & rd_addr_to_L2_valid)) begin
            RD_ADDR_TO_L2 <= rd_addr_to_L2;
        end
        
        // Valid signal for the L2 cache address stream
        if (rd_addr_to_L2_valid) begin
            rd_addr_to_L2_full <= 1;
        end else if (RD_ADDR_TO_L2_READY) begin 
            rd_addr_to_L2_full <= 0;
        end
    end    
    
    assign RD_ADDR_TO_L2_VALID = rd_addr_to_L2_full;
    assign rd_addr_to_L2_ready = !rd_addr_to_L2_full | RD_ADDR_TO_L2_READY;
     
     
    //////////////////////////////////////////////////////////////////////////////
    // Refill path - Data from L2 section                                       //
    //////////////////////////////////////////////////////////////////////////////
    
    wire [LINE_RAM_WIDTH / L2_BUS_WIDTH - 1 : 0] data_from_L2_buffer_enb;
    reg  [LINE_RAM_WIDTH                - 1 : 0] data_from_L2_buffer;
    
    // Buffer for storing data from L2, until they are read into the Stream Buffers or Line RAMs
    integer j;
    always @(posedge CLK) begin
        for (j = 0; j < LINE_RAM_WIDTH / L2_BUS_WIDTH; j = j + 1) begin
            if (data_from_L2_buffer_enb[j]) begin
                data_from_L2_buffer[j * L2_BUS_WIDTH +: L2_BUS_WIDTH] <= DATA_FROM_L2;  
            end
        end
    end    
    
    // Control unit for Data_From_L2 buffer
    Data_From_L2_Buffer_Control #(
        .L2_BUS_WIDTH(L2_BUS_WIDTH),
        .BUFFER_WIDTH(LINE_RAM_WIDTH)
    ) data_from_L2_buffer_control (
        .CLK(CLK),
        .ENB(1'b1),
        .DATA_FROM_L2_READY(DATA_FROM_L2_READY),
        .DATA_FROM_L2_VALID(DATA_FROM_L2_VALID),
        .DATA_FROM_L2_BUFFER_READY(refill_from_L2_ready),
        .DATA_FROM_L2_BUFFER_VALID(refill_from_L2_valid),
        .DATA_FROM_L2_BUFFER_ENB(data_from_L2_buffer_enb)
    );       
    
    //////////////////////////////////////////////////////////////////////////////
    // Victim cache and its controls                                            //
    //////////////////////////////////////////////////////////////////////////////

    wire [LINE_RAM_WIDTH - 1 : 0] victim_cache_refill;
    wire                          victim_cache_control;
    
    wire                          victim_bypass;
    wire [V + T          - 1 : 0] victim_hit_address, victim_bypass_address;
    
    // Set the flush bit
    assign victim_cache_control = (control_del_2 == 2'b11);
    
    Victim_Cache #(
        .S(S),
        .B(B),
        .a(a),
        .T(T),
        .V(V),
        .W(W)
    ) victim_cache (
        .CLK(CLK),
        // Write port from L1 cache
        .DATA_FROM_L1(l1_evict_out),
        .ADDR_FROM_L1({tag_set_mux_out, tag_address_del_2, section_address_del_2}),
        .DIRTY_FROM_L1(l1_dirty_out),
        .CONTROL_FROM_L1(victim_cache_control),
        .WR_FROM_L1_VALID(victim_cache_valid),
        .WR_FROM_L1_READY(victim_cache_ready),
        // Search port from L1 cache
        .SEARCH_ADDR({tag, tag_address, section_address}),
        // Other specialized ports from L1
        .VICTIM_COMMIT(victim_commit),
        .BYPASS(victim_bypass),     
        .BYPASS_ADDRESS(victim_bypass_address),     
        // Ports back to L1 cache
        .VICTIM_HIT(victim_hit),
        .HIT_ADDRESS(victim_hit_address),
        .DATA_TO_L1(victim_cache_refill),
        // Write port to L2
        .WR_TO_L2_READY(WR_TO_L2_READY),
        .WR_TO_L2_VALID(WR_TO_L2_VALID),
        .WR_ADDR_TO_L2(WR_ADDR_TO_L2),
        .DATA_TO_L2(DATA_TO_L2),
        .WR_CONTROL_TO_L2(WR_CONTROL_TO_L2),
        .WR_COMPLETE(WR_COMPLETE)      
    );
    
    //////////////////////////////////////////////////////////////////////////////
    // Refill path - Cache write units                                          //
    //////////////////////////////////////////////////////////////////////////////
    
    wire [1 : 0] refill_sel;                // refill_sel = {0 or 1(for a L1 data write), 2(victim cache refill), 3 (for L2 refill)}
    
    // Line RAM data in multiplexer
    genvar y,x;
   
    generate 
    
        for (y = 0; y < (1 << WORDS_PER_SECT); y = y + 1) begin : REFILL_LOOP
            for (x = 0; x < 4; x = x + 1) begin : BYTE_WR_LOOP
                wire [1 : 0] lin_mem_data_in_sel;
              
                assign lin_mem_data_in_sel[1] = refill_sel[1];
                
                assign lin_mem_data_in_sel[0] = (refill_sel[1])? refill_sel[0] : (y != word_address_del_2 | !byte_enb_del_2[x]);
                
                Multiplexer #(
                    .ORDER(2),
                    .WIDTH(8)
                ) lin_mem_data_in_mux (
                    .SELECT(lin_mem_data_in_sel),
                    .IN({data_from_L2_buffer[(8 * x + DATA_WIDTH * y) +: 8], 
                         victim_cache_refill[(8 * x + DATA_WIDTH * y) +: 8],
                         l1_data_out        [(8 * x + DATA_WIDTH * y) +: 8], 
                         data_del_2         [(8 * x                 ) +: 8]}),
                    .OUT(lin_mem_data_in    [(8 * x + DATA_WIDTH * y) +: 8])
                );
            end
        end
    endgenerate
    
    // From refill control unit
    wire [TAG_WIDTH       - 1 : 0] refill_tag;              // Current refill's tag
    wire [TAG_ADDR_WIDTH  - 1 : 0] refill_tag_addr;         // Current refill cache line
    wire [T               - 1 : 0] refill_sect;             // Current refill section
    wire [ASSOCIATIVITY   - 1 : 0] refill_dst;              // Refill destination set
    wire [BLOCK_SECTIONS  - 1 : 0] refill_tag_valid;        // Tag valid values to be written
    
    // Line memory write port controls
    assign lin_mem_wr_addr = (refill_sel[1]) ? {refill_tag_addr, refill_sect} : {tag_address_del_2, section_address_del_2};
    assign lin_mem_wr_enb  = (refill_sel[1]) ? refill_dst                     : (hit_set_wire & CACHE_READY & {ASSOCIATIVITY {control_del_2 == 2'b10}});
    
    // Tag memory write port controls
    assign tag_mem_wr_addr  = (refill_sel[1]) ? refill_tag_addr                : tag_address_del_2;
    assign tag_mem_wr_enb   = (refill_sel[1]) ? refill_dst                     : 0;
    assign dirty_mem_wr_enb = (refill_sel[1]) ? refill_dst                     : (hit_set_wire & CACHE_READY & {ASSOCIATIVITY {control_del_2 == 2'b10}});
    
    // Tag RAM data in multiplexer
    assign tag_valid_to_ram = refill_tag_valid;
    assign tag_to_ram       = refill_tag;
    assign dirty_to_ram     = (refill_sel[1]) ? 1'b0                           : 1'b1;
    
    
    //////////////////////////////////////////////////////////////////////////////
    // Primary control systems                                                  //
    //////////////////////////////////////////////////////////////////////////////
    
    wire refill_req_valid = valid_set_mux_out;              // & (dirty_set_mux_out | !victim_hit);
    
    Refill_Control_D #(
        .S(S),
        .B(B),
        .a(a),
        .T(T),
        .V(V)
    ) refill_control (
        .CLK(CLK),
        // Inputs from DM2 pipeline stage
        .CONTROL(control_del_1),
        // Inputs from DM3 pipeline stage
        .CACHE_HIT(cache_hit),                              // Whether the L1 cache hits or misses 
        .VICTIM_HIT(victim_hit),                            // Whether the victim cache has hit
        .VICTIM_HIT_ADDRESS(victim_hit_address),            // Hit position in the victim cache
        .REFILL_REQ_TAG(tag_del_2),                         // Tag portion of the PC at DM3
        .REFILL_REQ_LINE(tag_address_del_2),                // Line portion of the PC at DM3
        .REFILL_REQ_SECT(section_address_del_2),            // Section portion of the PC at DM3
        .REFILL_REQ_VTAG(tag_set_mux_out),                  // Tag coming out of tag memory delayed to DM3
        .REFILL_REQ_DST_SET(set_select),                    // Destination set for the refill. In binary format. 
        .REFILL_REQ_DIRTY(dirty_set_mux_out),               // Dirty bit coming out of tag memory delayed to DM3
        .REFILL_REQ_CTRL(control_del_2),                    // Instruction at DM3
        .REFILL_REQ_VALID(refill_req_valid),                // Valid bit coming out of tag memory delayed to DM3
        // To and from the Victim cache
        .VICTIM_BYPASS(victim_bypass),                      // Bypass the normal search routine of victim cache to directly insert a read address
        .VICTIM_BYPASS_ADDRESS(victim_bypass_address),      // Read address of the victim cache
        .VICTIM_CACHE_READY(victim_cache_ready),            // From victim cache that it is ready to receive
        .VICTIM_CACHE_WRITE(victim_cache_valid),            // To victim cache that it has to write the data from DM3
        .VICTIM_COMMIT(victim_commit),                      // To victim cache that it has hit and must send a burst of data
        // To the L1 read ports
        .L1_RD_PORT_SELECT(rd_port_select),                // Selects the inputs to the Read ports of L1 {0(from processor), 1(from refill control)}         
        .EVICT_TAG(evict_tag),                             // Tag for read address at DM1 
        .EVICT_TAG_ADDR(evict_tag_addr),                   // Cache line for read address at DM1 
        .EVICT_SECT(evict_sect),                           // Section for read address at DM1 
        // To the L1 write ports
        .L1_WR_PORT_SELECT(refill_sel),                    // Selects the inputs to the Write ports of L1 {0 or 1(for a L1 data write), 2(victim cache refill), 3 (for L2 refill)}
        .REFILL_DST(refill_dst),                           // Individual write enables for the line memories
        .REFILL_TAG(refill_tag),                           // Tag for the refill write
        .REFILL_TAG_VALID(refill_tag_valid),               // Which sections are valid currently, will be written to tag memory
        .REFILL_TAG_ADDR(refill_tag_addr),                 // Tag address for the refill write
        .REFILL_SECT(refill_sect),                         // Section address for the refill write
        // Outputs to the main processor pipeline		
        .CACHE_READY(CACHE_READY),                         // Signal from cache to processor that its pipeline is currently ready to work  
        // Related to controlling the pipeline
        .MAIN_PIPE_ENB(main_pipe_enb),                     // Enable for main pipeline registers
        .CACHE_PIPE_ENB(cache_pipe_enb),                   // Enable for cache pipeline
        .ADDR_FROM_PROC_SEL(addr_from_proc_sel),           // addr_from_proc_sel = {0(addr_from_proc_del_2), 1 (ADDR_FROM_PROC)}    
        // Related to Address to L2 buffers
        .SEND_RD_ADDR_TO_L2(send_rd_addr_to_L2),           // Valid signal for the input of Addr_to_L2 section
        .DATA_FROM_L2_BUFFER_READY(refill_from_L2_ready),  // Ready signal for refill from L2
        .DATA_FROM_L2_BUFFER_VALID(refill_from_L2_valid)   // Valid signal for refill from L2
    );
    
    //////////////////////////////////////////////////////////////////////////////
    // Initial values                                                           //
    //////////////////////////////////////////////////////////////////////////////
     
    initial begin
        addr_from_proc            = 0;   
        addr_from_proc_del_1      = 0;
        addr_from_proc_del_2      = 0;
           
        word_address_del_1        = addr_from_proc_del_1[BYTES_PER_WORD                     +: WORDS_PER_SECT];
        tag_address_del_1         = addr_from_proc_del_1[(BYTES_PER_WORD + WORDS_PER_BLOCK) +: TAG_ADDR_WIDTH];
        tag_del_1                 = addr_from_proc_del_1[(ADDR_WIDTH - 1)                   -: TAG_WIDTH     ];
        section_address_del_1     = addr_from_proc_del_1[(BYTES_PER_WORD + WORDS_PER_SECT)  +: T             ];
        
        word_address_del_2        = addr_from_proc_del_2[BYTES_PER_WORD                     +: WORDS_PER_SECT];
        tag_address_del_2         = addr_from_proc_del_2[(BYTES_PER_WORD + WORDS_PER_BLOCK) +: TAG_ADDR_WIDTH];
        tag_del_2                 = addr_from_proc_del_2[(ADDR_WIDTH - 1)                   -: TAG_WIDTH     ];
        section_address_del_2     = addr_from_proc_del_2[(BYTES_PER_WORD + WORDS_PER_SECT)  +: T             ];
        
        control_from_proc          = 0;
        control_del_1              = 0;
        control_del_2              = 0;
        
        byte_enb_from_proc         = 0;
        byte_enb_del_1             = 0;
        byte_enb_del_2             = 0;
        
        tag_valid                  = 0;
        tag_match                  = 0;  
        rd_addr_to_L2_full         = 0;
        RD_ADDR_TO_L2              = 0;  
    end
        
    // Log value calculation
    function integer logb2;
        input integer depth;
        for (logb2 = 0; depth > 1; logb2 = logb2 + 1)
            depth = depth >> 1;
    endfunction
endmodule