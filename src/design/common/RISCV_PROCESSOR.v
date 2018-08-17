`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/04/2017 08:24:33 PM
// Design Name: 
// Module Name: RISCV_PROCESSOR
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

module RISCV_PROCESSOR#(
        // Fixed parameters
        localparam ADDR_WIDTH           = 32,
        localparam DATA_WIDTH           = 32,
        localparam EXT_FIFO_ADDRESS     = 32'h10150,
   //     localparam EXT_FIFO_ADDRESS     = 32'h10150,
        parameter  PERIPHERAL_BASE_ADDR = 32'h10000000,
           
        // Primary parameters
        parameter S                     = 17,                    // Size of the cache will be 2^S bits
        parameter B                     = 9,                     // Size of a block will be 2^B bits
        parameter a                     = 1,//1,                     // Associativity of the cache would be 2^a
        parameter T                     = 1,                     // Width to depth translation amount
        parameter W                     = 7,                     // Width of the L2-L1 bus would be 2^W
        parameter N                     = 3,                     // Number of stream buffers
        parameter n                     = 1,                     // Depth of stream buffers would be 2^n
        parameter p                     = 2,                     // Prefetch queue's depth is 2^p
        parameter V                     = 2,                     // Size of the victim cache will be 2^V cache lines
        parameter L2_DELAY_RD           = 7,                     // Delay of the second level of cache
        parameter HISTORY_DEPTH         = 32,                                  
        // Calculated parameters
        localparam BYTES_PER_WORD       = logb2(DATA_WIDTH/8),
        
        localparam CACHE_SIZE           = 1 << S,
        localparam BLOCK_SIZE           = 1 << B,
        localparam ASSOCIATIVITY        = 1 << a,
        
        localparam TAG_WIDTH            = ADDR_WIDTH + 3 + a - S,
        localparam LINE_ADDR_WIDTH      = S - a - B + T,
        localparam TAG_ADDR_WIDTH       = S - a - B,
        
        localparam L2_BUS_WIDTH         = 1 << W,
        localparam BLOCK_SECTIONS       = 1 << T,
        
        localparam SET_SIZE             = CACHE_SIZE / ASSOCIATIVITY,
        localparam LINE_RAM_WIDTH       = 1 << (B - T),
        localparam LINE_RAM_DEPTH       = 1 << LINE_ADDR_WIDTH,
        localparam TAG_RAM_WIDTH        = TAG_WIDTH + BLOCK_SECTIONS,
        localparam TAG_RAM_DEPTH        = 1 << TAG_ADDR_WIDTH,
        
        localparam PREFETCH_QUEUE_DEPTH = 1 << p,
        localparam STREAM_BUF_DEPTH     = 1 << n,
        localparam STREAM_SEL_BITS      = logb2(N + 1),
        
        localparam L2_BURST             = 1 << (B - W)
    ) (
        // Standard inputs
        input                               CLK,
        input                               RSTN,
            
        ////////////////////////
        // INSTRUCTION CACHE  //
        ////////////////////////
        
        // Output address bus from Instruction Cache to Memory
        (* mark_debug *) input                               ADDR_TO_L2_READY_INS,
        (* mark_debug *) output                              ADDR_TO_L2_VALID_INS,      
        (* mark_debug *) output     [ADDR_WIDTH - 2 - 1 : 0] ADDR_TO_L2_INS,
                
        // Input data bus to Insruction Cache from Memory       
        (* mark_debug *) input                               DATA_FROM_L2_VALID_INS,
        (* mark_debug *) output                              DATA_FROM_L2_READY_INS,
        (* mark_debug *) input      [L2_BUS_WIDTH   - 1 : 0] DATA_FROM_L2_INS,
        
        
        ////////////////////////
        //    DATA CACHE      //
        ////////////////////////
        
        // Write bus between Data Cache and Memory 
        (* mark_debug *) input                               WR_TO_L2_READY_DAT,
        (* mark_debug *) output                              WR_TO_L2_VALID_DAT,
        (* mark_debug *) output     [ADDR_WIDTH - 2 - 1 : 0] WR_ADDR_TO_L2_DAT,
        (* mark_debug *) output     [L2_BUS_WIDTH   - 1 : 0] DATA_TO_L2_DAT,
        (* mark_debug *) output                              WR_CONTROL_TO_L2_DAT,
        (* mark_debug *) input                               WR_COMPLETE_DAT,
        
        // Read address from Data Cache to Memory
        (* mark_debug *) input                               RD_ADDR_TO_L2_READY_DAT,
        (* mark_debug *) output                              RD_ADDR_TO_L2_VALID_DAT,
        (* mark_debug *) output     [ADDR_WIDTH - 2 - 1 : 0] RD_ADDR_TO_L2_DAT,
        
        // Read data to Data Cache from Memory
        (* mark_debug *) input                               DATA_FROM_L2_VALID_DAT,
        (* mark_debug *) output                              DATA_FROM_L2_READY_DAT,
        (* mark_debug *) input      [L2_BUS_WIDTH   - 1 : 0] DATA_FROM_L2_DAT,
                         input  P0_INIT_AXI_TXN,
        ////////////////////////
        //   EXTRACTION FIFO  //
        ////////////////////////
                   
       output reg                                            EXT_FIFO_WR_ENB,
       output reg [DATA_WIDTH     - 1 : 0]                   EXT_FIFO_WR_DATA=32,
        
        
        ///////////////////////////
        //    DATA PERIPHERAL    //
        ///////////////////////////
        
        output      [31:0]          RD_ADDR_TO_PERI,
        output                      RD_ADDR_TO_PERI_VALID,
        input                       RD_ADDR_TO_PERI_READY,
        output      [31:0]          WR_ADDR_TO_PERI,
        output                      WR_TO_PERI_VALID,
        input                       WR_TO_PERI_READY,
        output      [31:0]          DATA_TO_PERI,
        input       [31:0]          DATA_FROM_PERI,
        output                      DATA_FROM_PERI_READY,
        input                       DATA_FROM_PERI_VALID,
        input                       TRANSACTION_COMPLETE_PERI,
        output  [3:0]                      WSTRB_OUT,
        input                                           MEIP                            ,   //machine external interupt pending
        input                                           MTIP                            ,   //machine timer interupt pending
        input                                           MSIP                                //machine software interupt pending, from external hart
        
        
    );
     
     // Peripheral signals
     reg                                p_flag = 0;
     reg                                stop_dat_cache = 0;
     reg                                stop_ins_cache = 0;
     integer                            counter = 0;
     reg                                peri_start;
     reg        [31:0]                  addr_to_peri;
     reg                                control_to_peri;
     reg        [31:0]                  data_to_peri;
     wire       [31:0]                  data_from_peri;
     wire                               peri_complete;
     reg                                peri_done = 0;
     reg        [3 :0]                  wstrb_to_peri;
     
     
     // Status signals between processor and instruction cache
     wire                               proc_ready_ins;
     wire                               cache_ready_ins;
     
     // Input address bus from the processor to instruction cache
     wire                               branch_taken;
     wire   [ADDR_WIDTH - 1 : 0]        branch_address;
           
     // Output data bus from instruction cache to the processor
     wire   [DATA_WIDTH - 1 : 0]        data_to_proc_ins;
     wire   [ADDR_WIDTH - 1 : 0]        pc_to_proc_ins;
     
     
     //Status signals between processor and data cache
     wire                               cache_ready_dat;
        
     //Input address bus from the processor to data cache     
     wire   [2          - 1 : 0]        control_from_proc_dat;
     wire   [ADDR_WIDTH - 1 : 0]        addr_from_proc_dat;
     wire   [DATA_WIDTH - 1 : 0]        data_from_proc_dat;
     wire   [4          - 1 : 0]        byte_enb_proc;
               
     //Output data from data cache to processor
     wire   [DATA_WIDTH - 1 : 0]        data_to_proc_dat;
     
     /////////////////////////////////////////////////////////
     //ijaz maathu
     wire predicted;
     wire [31:0] pc;
     wire [31:0] ex_pc;
     wire branch;
     wire prd_valid;
     wire [31:0] prd_addr;
     wire flush;
     wire [31:0] return_addr;
     wire  return;
     wire [31:0] ins_id_ex;
     
     //reg [63:0]     mtime;
     //reg [63:0]     mtimecmp;
     //reg            timer_interrupt;
     //reg            reg_done = 0;
     //reg [31:0]     data_from_reg;
     //reg            reg_flag = 0;
     
    ///////////////////////////////////////////////////// 
    
    //Simulation

     
    wire    exstage_stalled ;
     
    Ins_Cache # (
    .S(S),
    .B(B),
    .a(a),
    .T(T),
    .W(W),
    .L2_DELAY(L2_DELAY_RD),
    .N(N),
    .n(n),
    .p(p)
    ) ins_cache (
    // Standard inputs
    .CLK(CLK),
    .RSTN(RSTN),
    .PC(pc) ,
    // Status signals between processor and cache
    .CACHE_READY(cache_ready_ins),
    .PROC_READY(proc_ready_ins & !exstage_stalled & P0_INIT_AXI_TXN!=0 & !stop_ins_cache),
    // Ports towards the processor
    .BRANCH_ADDR_IN(prd_addr),
    .BRANCH(1),
    .DATA_TO_PROC(data_to_proc_ins),
    .PC_TO_PROC(pc_to_proc_ins),
    /// Read port towards the L2 cache    
    .ADDR_TO_L2(ADDR_TO_L2_INS),
    .ADDR_TO_L2_READY(ADDR_TO_L2_READY_INS),
    .ADDR_TO_L2_VALID(ADDR_TO_L2_VALID_INS),
    .DATA_FROM_L2(DATA_FROM_L2_INS),
    .DATA_FROM_L2_VALID(DATA_FROM_L2_VALID_INS),
    .DATA_FROM_L2_READY(DATA_FROM_L2_READY_INS)
     );
    
     PIPELINE pipeline(
    .CLK(CLK),
    // Towards instruction cache
    .CACHE_READY(cache_ready_ins & !exstage_stalled & P0_INIT_AXI_TXN!=0 & !stop_ins_cache),
    .PIPELINE_STALL(proc_ready_ins),
    .BRANCH_TAKEN(branch_taken),
    .BYTE_ENB_TO_CACHE( byte_enb_proc),
    .BRANCH_ADDRESS(branch_address),
    .PC_IF_ID(pc_to_proc_ins), 
    .INS_IF_ID(data_to_proc_ins),
    //Data cache busses
    .CONTROL_DATA_CACHE(control_from_proc_dat), 
    .ADDR_TO_DATA_CACHE(addr_from_proc_dat),
    .DATA_TO_DATA_CACHE(data_from_proc_dat),
    .DATA_TO_PROC((p_flag)? data_from_peri: data_to_proc_dat),
    .CACHE_READY_DATA(cache_ready_dat & !stop_dat_cache),
    .EX_PC(ex_pc),
    .BRANCH(branch),
    .FLUSH(flush),
    .RETURN_ADDR(return_addr),
    .RETURN(return),
    .PREDICTED(predicted),
    .EXSTAGE_STALLED(exstage_stalled),
    .INS_ID_EX(ins_id_ex),
    .MEIP(MEIP),
    .MSIP(MSIP),
    .MTIP(MTIP)
    );
    
    Data_Cache # (
    .S(S),
    .B(B),
    .a(a),
    .T(T),
    .W(W),
    .L2_DELAY_RD(L2_DELAY_RD),
    .V(V)
    ) data_cache (
    // Standard inputs
    .CLK(CLK),
    // Status signals between processor and cache
    .CACHE_READY(cache_ready_dat),
    // Ports towards the processor
    .CONTROL_FROM_PROC((addr_from_proc_dat != EXT_FIFO_ADDRESS & addr_from_proc_dat < PERIPHERAL_BASE_ADDR)? control_from_proc_dat : 0),  // CONTROL_FROM_PROC = {00(idle), 01(read), 10(write), 11(flush address from cache)}
    .BYTE_ENB_FROM_PROC(byte_enb_proc),
    .ADDR_FROM_PROC(addr_from_proc_dat),
    .DATA_FROM_PROC(data_from_proc_dat),
    .DATA_TO_PROC(data_to_proc_dat),
    // Write port towards the L2 cache
    .WR_TO_L2_READY(WR_TO_L2_READY_DAT),
    .WR_TO_L2_VALID(WR_TO_L2_VALID_DAT),
    .WR_ADDR_TO_L2(WR_ADDR_TO_L2_DAT),
    .DATA_TO_L2(DATA_TO_L2_DAT),
    .WR_CONTROL_TO_L2(WR_CONTROL_TO_L2_DAT),
    .WR_COMPLETE(WR_COMPLETE_DAT),
    // Read port towards the L2 cache
    .RD_ADDR_TO_L2_READY(RD_ADDR_TO_L2_READY_DAT),
    .RD_ADDR_TO_L2_VALID(RD_ADDR_TO_L2_VALID_DAT),
    .RD_ADDR_TO_L2(RD_ADDR_TO_L2_DAT),
    .DATA_FROM_L2_VALID(DATA_FROM_L2_VALID_DAT),
    .DATA_FROM_L2_READY(DATA_FROM_L2_READY_DAT),
    .DATA_FROM_L2(DATA_FROM_L2_DAT)       
    );
    
    
    BHT bht (
    .CLK(CLK)                              ,
    .PC(pc)                                ,
    .EX_PC(ex_pc)                          ,
    .BRANCH(branch)                        ,
    .BRANCH_TAKEN(branch_taken)            ,
    .BRANCH_ADDR (branch_address)          ,
    .PRD_VALID (prd_valid)                 ,
    .PRD_ADDR  (prd_addr)                  ,
    .FLUSH(flush)                          ,
    .CACHE_READY(cache_ready_ins & !exstage_stalled & P0_INIT_AXI_TXN!=0 & !stop_ins_cache)          ,
    .CACHE_READY_DATA(cache_ready_dat & !stop_dat_cache),
    .RETURN_ADDR(return_addr),
    .RETURN(return),
    .PREDICTED(predicted)
    );
    
    Peripheral peripheral
    (
    .CLK(CLK),
    .RESETN(RSTN),
    .START(peri_start),
    .ADDRESS(addr_to_peri),
    .WRITE(control_to_peri),
    .DATA_IN(data_to_peri),
    .DATA_OUT(data_from_peri),
    .DONE(peri_complete),
    .WSTRB(wstrb_to_peri),
    .RD_ADDR_TO_PERI(RD_ADDR_TO_PERI),
    .RD_ADDR_TO_PERI_VALID(RD_ADDR_TO_PERI_VALID),
    .RD_ADDR_TO_PERI_READY(RD_ADDR_TO_PERI_READY),
    .WR_ADDR_TO_PERI(WR_ADDR_TO_PERI),
    .WR_TO_PERI_VALID(WR_TO_PERI_VALID),
    .WR_TO_PERI_READY(WR_TO_PERI_READY),
    .DATA_TO_PERI(DATA_TO_PERI),
    .DATA_FROM_PERI(DATA_FROM_PERI),
    .DATA_FROM_PERI_READY(DATA_FROM_PERI_READY),
    .DATA_FROM_PERI_VALID(DATA_FROM_PERI_VALID),
    .TRANSACTION_COMPLETE_PERI(TRANSACTION_COMPLETE_PERI),
    .CACHE_READY_DAT(cache_ready_dat),
    .WSTRB_OUT(WSTRB_OUT)
    );
    
    
    // Intercepting and extracting certain data writes
    reg [DATA_WIDTH - 1 : 0] data;
    reg [2          - 1 : 0] control;
    reg [ADDR_WIDTH - 1 : 0] address;
    
    reg [7:0] counter1 = 0;
    
    always@(posedge CLK)
    begin
        if  (addr_from_proc_dat >= PERIPHERAL_BASE_ADDR/* && addr_from_proc_dat!= EXT_FIFO_ADDRESS */&&  control_from_proc_dat != 0 && !stop_dat_cache && cache_ready_ins && cache_ready_dat && counter==0)
        begin
            data_to_peri <= data_from_proc_dat;
            addr_to_peri <= addr_from_proc_dat;
            control_to_peri <= (control_from_proc_dat == 2) ? 1'b1:1'b0;
            wstrb_to_peri <= byte_enb_proc;
            peri_start <=1;
            stop_ins_cache <=1;
            counter <= counter +1;
            peri_done <= 0;
        end
        else if (cache_ready_dat && counter>0)
        begin
            if(peri_complete)
            begin
                peri_done <= 1;
            end
                        
            if (counter == 3 && !peri_done)
            begin
                stop_dat_cache <=1;
                p_flag         <=0;
                stop_ins_cache <=0;     
            end
            else if (counter == 3 && peri_done)
            begin
                stop_ins_cache <=0;  
                p_flag         <=1;
                counter        <=0;
                stop_dat_cache <=0;
            end
            else if (counter!=0)
            begin
                counter       <=counter + 1;
                peri_start    <=0;
            end    
        end
        
        if (p_flag && peri_done & peri_start)
        begin
            peri_start <=0;
        end
        if (p_flag & cache_ready_dat & !stop_dat_cache)
        begin
            p_flag <= 0;
        end
    end
    
    //Simulation Code/////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    always @ (posedge CLK) begin 
//         EXT_FIFO_WR_ENB  <=P0_INIT_AXI_TXN & cache_ready_dat & cache_ready_ins ;//<= data_to_proc_ins;
//         EXT_FIFO_WR_DATA <= {ex_pc[31:2],cache_ready_dat,cache_ready_ins};
         if (((addr_from_proc_dat == EXT_FIFO_ADDRESS) & (control_from_proc_dat == 2)  & cache_ready_dat & cache_ready_ins  & P0_INIT_AXI_TXN))
         begin
             EXT_FIFO_WR_ENB  <= 1;
             EXT_FIFO_WR_DATA <= data_from_proc_dat;
         end      
         else
         begin
             EXT_FIFO_WR_ENB  <= 0;
         end
    end
    
    function integer logb2;
        input integer depth;
        for (logb2 = 0; depth > 1; logb2 = logb2 + 1)
            depth = depth >> 1;
    endfunction
    
    localparam FIFO_BUFFER_DEPTH  = 32;
    
    reg [DATA_WIDTH - 1 : 0] EXIT_FIFO_BUFFER [0:FIFO_BUFFER_DEPTH - 1] ;
    
    integer vk;
    integer writeFiles;
    initial
    begin
        writeFiles = $fopen("prints.txt", "w");
        $fclose(writeFiles);  
    end
    always@(posedge CLK)
    begin
        writeFiles = $fopen("prints.txt", "a");
        if(EXT_FIFO_WR_ENB)
        begin                 
            $fwrite(writeFiles,"%c",EXT_FIFO_WR_DATA);   
            $write("%c",EXT_FIFO_WR_DATA);   
            EXIT_FIFO_BUFFER[0]<=EXT_FIFO_WR_DATA;
            for(vk=0;vk<FIFO_BUFFER_DEPTH-1;vk=vk+1)
            begin
                EXIT_FIFO_BUFFER[vk+1]<=EXIT_FIFO_BUFFER[vk];
            end
        end
        $fclose(writeFiles);
    end
    
endmodule
