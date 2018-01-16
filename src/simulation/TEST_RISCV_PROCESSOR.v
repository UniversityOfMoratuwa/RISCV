`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yasas Senevitatne
// 
// Create Date: 03/05/2017 10:37:35 AM
// Design Name: 
// Module Name: Test_RISCV_PROCESSOR
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

module Test_RISCV_PROCESSOR ();
    // Fixed parameters
    localparam ADDR_WIDTH        = 32;
    localparam DATA_WIDTH        = 32;
    
    // Primary parameters for processor instantiation
    parameter S                  = 17;                    // Size of the cache will be 2^S bits
    parameter B                  = 9;                     // Size of a block will be 2^B bits
    parameter a                  = 1;                     // Associativity of the cache would be 2^a
    parameter T                  = 1;                     // Width to depth translation amount
    parameter W                  = 7;                     // Width of the L2-L1 bus would be 2^W
    parameter V                  = 2;                     // Size of the victim cache will be 2^V cache lines
    parameter N                  = 3;                     // Number of stream buffers
    parameter n                  = 1;                     // Depth of stream buffers would be 2^n
    parameter p                  = 2;                     // Prefetch queue's depth is 2^p
        
    // Related to testbench
    parameter L2_DELAY_RD        = 7;                       // Read delay of the L2 cache (from start of request upto first reply)
    parameter L2_DELAY_WR        = 4;                       // Write delay of the L2 cache (from sending last data to WR_COMPLETE acknowledgement)
    
    parameter INS_RAM_ADDR_WIDTH = 20;                      // 2^INS_RAM_ADDR_WIDTH is the depth of the main instruction memory of the system
    parameter DAT_RAM_ADDR_WIDTH = 20;                      // 2^INS_RAM_ADDR_WIDTH is the depth of the main instruction memory of the system
     
    parameter FIFO_BUFFER_DEPTH  = 32;
          
    // Calculated parameters
    localparam L2_BUS_WIDTH      = 1 << W;
    localparam L2_BURST          = 1 << (B - W);
    localparam INS_RAM_DEPTH     = 1 << INS_RAM_ADDR_WIDTH;
    localparam DAT_RAM_DEPTH     = 1 << DAT_RAM_ADDR_WIDTH;
                
    // Constants
    reg TRUE  = 1;
    reg FALSE = 0;    
    
    // Standard inputs    
    reg                           CLK;
    reg                           RSTN;             
             
    // Output address bus from Instruction Cache to Memory               
    wire [ADDR_WIDTH     - 3 : 0] ADDR_TO_L2_INS;
    wire                          ADDR_TO_L2_READY_INS;
    wire                          ADDR_TO_L2_VALID_INS;
    
    // Input data bus to Insruction Cache from Memory     
    reg  [L2_BUS_WIDTH   - 1 : 0] DATA_FROM_L2_INS;
    reg                           DATA_FROM_L2_VALID_INS;
    wire                          DATA_FROM_L2_READY_INS;
    
    // Write bus between Data Cache and Memory 
    wire                          WR_TO_L2_READY_DAT;
    wire                          WR_TO_L2_VALID_DAT;
    wire [ADDR_WIDTH - 2 - 1 : 0] WR_ADDR_TO_L2_DAT;
    wire [L2_BUS_WIDTH   - 1 : 0] DATA_TO_L2_DAT;
    wire                          WR_CONTROL_TO_L2_DAT;
    wire                          WR_COMPLETE_DAT;
    
    // Read address from Data Cache to Memory
    wire                          RD_ADDR_TO_L2_READY_DAT;
    wire                          RD_ADDR_TO_L2_VALID_DAT;
    wire [ADDR_WIDTH - 2 - 1 : 0] RD_ADDR_TO_L2_DAT;
    
    // Read data to Data Cache from Memory
    reg                           DATA_FROM_L2_VALID_DAT;
    wire                          DATA_FROM_L2_READY_DAT;
    reg  [L2_BUS_WIDTH   - 1 : 0] DATA_FROM_L2_DAT;
    
    reg                           P0_INIT_AXI_TXN;
    
    wire                          EXT_FIFO_WR_ENB;
    wire [DATA_WIDTH - 1 :0]      EXT_FIFO_WR_DATA;
       
    RISCV_PROCESSOR # (
        .S(S),
        .B(B),
        .a(a),
        .T(T),
        .W(W),
        .N(N), 
        .n(n),      
        .p(p),      
        .V(V), 
        .L2_DELAY_RD(L2_DELAY_RD)
    ) uut (
        // Standard inputs
        .CLK(CLK),
        .RSTN(RSTN),
        // Output address bus from Instruction Cache to Memory               
        .ADDR_TO_L2_INS(ADDR_TO_L2_INS),
        .ADDR_TO_L2_READY_INS(ADDR_TO_L2_READY_INS),
        .ADDR_TO_L2_VALID_INS(ADDR_TO_L2_VALID_INS),
        // Input data bus to Insruction Cache from Memory   
        .DATA_FROM_L2_INS(DATA_FROM_L2_INS),
        .DATA_FROM_L2_VALID_INS(DATA_FROM_L2_VALID_INS),
        .DATA_FROM_L2_READY_INS(DATA_FROM_L2_READY_INS),
        // Write bus between Data Cache and Memory 
        .WR_TO_L2_READY_DAT(WR_TO_L2_READY_DAT),
        .WR_TO_L2_VALID_DAT(WR_TO_L2_VALID_DAT),
        .WR_ADDR_TO_L2_DAT(WR_ADDR_TO_L2_DAT),
        .DATA_TO_L2_DAT(DATA_TO_L2_DAT),
        .WR_CONTROL_TO_L2_DAT(WR_CONTROL_TO_L2_DAT),
        .WR_COMPLETE_DAT(WR_COMPLETE_DAT),
        // Read address from Data Cache to Memory
        .RD_ADDR_TO_L2_READY_DAT(RD_ADDR_TO_L2_READY_DAT),
        .RD_ADDR_TO_L2_VALID_DAT(RD_ADDR_TO_L2_VALID_DAT),
        .RD_ADDR_TO_L2_DAT(RD_ADDR_TO_L2_DAT),
        // Read data to Data Cache from Memory
        .DATA_FROM_L2_VALID_DAT(DATA_FROM_L2_VALID_DAT),
        .DATA_FROM_L2_READY_DAT(DATA_FROM_L2_READY_DAT),
        .DATA_FROM_L2_DAT(DATA_FROM_L2_DAT),
        .P0_INIT_AXI_TXN(P0_INIT_AXI_TXN),
        .EXT_FIFO_WR_ENB(EXT_FIFO_WR_ENB),
        .EXT_FIFO_WR_DATA(EXT_FIFO_WR_DATA)
    );
            
    reg [DATA_WIDTH - 1 : 0] EXIT_FIFO_BUFFER [0:FIFO_BUFFER_DEPTH - 1] ;
    
    integer vk;
    integer writeFiles;
    
    initial
    begin
        writeFiles = $fopen("prints.txt", "w")  ;
        $fclose(writeFiles)                     ; 
        P0_INIT_AXI_TXN     = 1                 ;
    end
   
   
   always@(posedge CLK)
   begin
   writeFiles = $fopen("prints.txt", "a");
        if(EXT_FIFO_WR_ENB)
        begin                 
            $fwrite(writeFiles,"%c",EXT_FIFO_WR_DATA);   
            EXIT_FIFO_BUFFER[0]<=EXT_FIFO_WR_DATA;
            for(vk=0;vk<FIFO_BUFFER_DEPTH-1;vk=vk+1)
            begin
                EXIT_FIFO_BUFFER[vk+1]<=EXIT_FIFO_BUFFER[vk];
            end
        end
    $fclose(writeFiles);
    end
    
      
    //L2 Cache emulators
    reg [DATA_WIDTH - 1 : 0] ins_memory [0: INS_RAM_DEPTH - 1] ;  
    reg [DATA_WIDTH - 1 : 0] dat_memory [0: DAT_RAM_DEPTH - 1] ;  
    integer ins;
    initial
    begin
     for (ins=0; ins < INS_RAM_DEPTH; ins=ins+1)
     begin
 //    dat_memory[ins]=32'd5;
        ins_memory[ins]=0;
         

     end
    end
    integer j, k, l;
    integer PC_no;
    integer siz;    
    initial begin
        CLK  = 0;
        RSTN = 1;
        
        PC_no = 0;
        l2_ready_ins = 1;
        l2_ready_dat = 1;
        
       //$readmemh("E:/University/GrandFinale/Project/riscv_fpga/Simulation/RISCV_Processor/Ins_Memory5.txt", ins_memory);
        $readmemh("data_hex.txt", ins_memory);
       
       
       for (siz=0;siz<DAT_RAM_DEPTH ;siz=siz+1)
       begin
          dat_memory[siz]=0;
       end
       $readmemh("data_hex.txt", dat_memory);
    end
       
    ///////////////////////////////////////////
    // Instruction memory
    ///////////////////////////////////////////
    
    reg [L2_BURST   - 1 : 0] l2_input_state_ins;
    
    reg                      mem_requests_ins  [0 : L2_DELAY_RD - 3];
    reg [ADDR_WIDTH - 3 : 0] mem_addresses_ins [0 : L2_DELAY_RD - 3];
    
    reg [ADDR_WIDTH - 1 : 0] output_addr_reg_ins  = 0;
    reg [L2_BURST   - 1 : 0] output_data_state_ins = 0;
        
    reg                      l2_ready_ins;
    
    assign ADDR_TO_L2_READY_INS = l2_ready_ins & DATA_FROM_L2_READY_INS;    
    
    wire [32    - 1 : 0] temp4 = {output_addr_reg_ins[INS_RAM_ADDR_WIDTH + 2  - 1 : 2 + B - 5    ], {(B - 5    ){1'b0}}};
    wire [B - 5 - 1 : 0] temp5 = {output_addr_reg_ins[2 + B - 5               - 1 : 2 + W - 5 + T], {(W - 5 + T){1'b0}}};
    
    genvar ar,as;
    wire [31 : 0] read_value_ins [L2_BURST - 1 : 0][(1 << W - 5) - 1 : 0];
    generate
        for (ar = 0; ar < L2_BURST; ar = ar + 1) begin
            for (as = 0; as < (1 << W - 5); as = as + 1) begin
                wire [B - 5 - 1 : 0] temp6 = temp5 + {ar[B - W - 1 : 0], {(W - 5){1'b0}}};
                
                assign read_value_ins[ar][as] = ins_memory[temp4 + temp6 + as];
            end
        end
    endgenerate
    
                        
    always @(posedge CLK) begin
        if (DATA_FROM_L2_READY_INS) begin
            mem_requests_ins [0] <= ADDR_TO_L2_VALID_INS && ADDR_TO_L2_READY_INS;
            mem_addresses_ins[0] <= ADDR_TO_L2_INS;
            for (j = 1; j < L2_DELAY_RD; j = j + 1) begin
                mem_requests_ins [j] <= mem_requests_ins [j - 1];
                mem_addresses_ins[j] <= mem_addresses_ins[j - 1];
            end
        
            if (ADDR_TO_L2_VALID_INS && ADDR_TO_L2_READY_INS) begin
                l2_ready_ins       <= 0;
                l2_input_state_ins <= 1;           
            end else if (l2_input_state_ins != 0) begin
                l2_input_state_ins <= l2_input_state_ins << 1;
            end
            
            if(l2_input_state_ins[L2_BURST - 2]) begin
                l2_ready_ins <= 1;
            end
            
            if (mem_requests_ins[L2_DELAY_RD - 3]) begin
                output_addr_reg_ins   <= {mem_addresses_ins[L2_DELAY_RD - 3], 2'b00};
                output_data_state_ins <= 1;
            end else if (output_data_state_ins != 0) begin
                output_data_state_ins <= output_data_state_ins << 1;
            end
            
            if (output_data_state_ins != 0) begin            
                DATA_FROM_L2_VALID_INS <= 1;
            end else begin
                DATA_FROM_L2_VALID_INS <= 0;
            end
            
            for (k = 0; k < L2_BURST; k = k + 1) begin
                if (output_data_state_ins[k] == 1) begin
                    for (l = 0; l < (1 << W - 5); l = l + 1) begin
                        DATA_FROM_L2_INS[l * DATA_WIDTH +: DATA_WIDTH] <= read_value_ins[k][l];
                    end
                end
            end
        end      
    end
    
    ///////////////////////////////////////////
    // Data memory
    ///////////////////////////////////////////
      
    // Read port of data memory
    reg  [L2_BURST   - 1 : 0] l2_rd_input_state_dat;
    
    reg                       rd_mem_requests_dat  [0 : L2_DELAY_RD - 3];
    reg  [ADDR_WIDTH - 3 : 0] rd_mem_addresses_dat [0 : L2_DELAY_RD - 3];
        
    reg  [ADDR_WIDTH - 1 : 0] rd_output_addr_reg_dat   = 0;
    reg  [L2_BURST   - 1 : 0] rd_output_data_state_dat = 0;
    reg                       l2_ready_dat;
        
    assign RD_ADDR_TO_L2_READY_DAT = l2_ready_dat & DATA_FROM_L2_READY_DAT;    
    
    wire [32    - 1 : 0] temp1 = {rd_output_addr_reg_dat[DAT_RAM_ADDR_WIDTH + 2  - 1 : 2 + B - 5    ], {(B - 5    ){1'b0}}};
    wire [B - 5 - 1 : 0] temp2 = {rd_output_addr_reg_dat[2 + B - 5               - 1 : 2 + W - 5 + T], {(W - 5 + T){1'b0}}};
    
    genvar ap,aq;
    wire [31 : 0] read_value_dat [L2_BURST - 1 : 0][(1 << W - 5) - 1 : 0];
    generate
        for (ap = 0; ap < L2_BURST; ap = ap + 1) begin
            for (aq = 0; aq < (1 << W - 5); aq = aq + 1) begin
                wire [B - 5 - 1 : 0] temp3 = temp2 + {ap[B - W - 1 : 0], {(W - 5){1'b0}}};
                
                assign read_value_dat[ap][aq] = dat_memory[temp1 + temp3 + aq];
            end
        end
    endgenerate
        
    always @(posedge CLK) begin
        if (DATA_FROM_L2_READY_DAT) begin
            rd_mem_requests_dat [0] <= RD_ADDR_TO_L2_VALID_DAT && RD_ADDR_TO_L2_READY_DAT;
            rd_mem_addresses_dat[0] <= RD_ADDR_TO_L2_DAT;
            for (j = 1; j < L2_DELAY_RD; j = j + 1) begin
                rd_mem_requests_dat [j] <= rd_mem_requests_dat [j - 1];
                rd_mem_addresses_dat[j] <= rd_mem_addresses_dat[j - 1];
            end
        
            if (RD_ADDR_TO_L2_VALID_DAT && RD_ADDR_TO_L2_READY_DAT) begin
                l2_ready_dat          <= 0;
                l2_rd_input_state_dat <= 1;           
            end else if (l2_rd_input_state_dat != 0) begin
                l2_rd_input_state_dat <= l2_rd_input_state_dat << 1;
            end
            
            if(l2_rd_input_state_dat[L2_BURST - 2]) begin
                l2_ready_dat       <= 1;
            end
            
            if (rd_mem_requests_dat[L2_DELAY_RD - 3]) begin
                rd_output_addr_reg_dat   <= {rd_mem_addresses_dat[L2_DELAY_RD - 3], 2'b00};
                rd_output_data_state_dat <= 1;
            end else if (rd_output_data_state_dat != 0) begin
                rd_output_data_state_dat <= rd_output_data_state_dat << 1;
            end
            
            if (rd_output_data_state_dat != 0) begin            
                DATA_FROM_L2_VALID_DAT <= 1;
            end else begin
                DATA_FROM_L2_VALID_DAT <= 0;
            end
            
            for (k = 0; k < L2_BURST; k = k + 1) begin
                if (rd_output_data_state_dat[k] == 1) begin
                    for (l = 0; l < (1 << W - 5); l = l + 1) begin
                        DATA_FROM_L2_DAT[l * DATA_WIDTH +: DATA_WIDTH] <= read_value_dat[k][l];                                
                    end
                end
            end
        end      
    end
    
    // Write port of data memory     
    integer writeFile;
    
    reg  [L2_DELAY_WR + L2_BURST  - 1 : 0] l2_wr_input_state = 1;
    
    assign WR_TO_L2_READY_DAT = |(l2_wr_input_state[L2_BURST - 1 : 0]); 
    assign WR_COMPLETE_DAT    = l2_wr_input_state[L2_DELAY_WR + L2_BURST  - 1];
    
    integer current_section = 0;
    integer m;
    
    always @(posedge CLK) begin
        if (WR_TO_L2_READY_DAT) begin
            if (WR_TO_L2_VALID_DAT) begin
                l2_wr_input_state <= l2_wr_input_state << 1;
                current_section   <= current_section + 1;  
                
                for (m = 0; m < (1 << W - 5); m = m + 1) begin
                    dat_memory[WR_ADDR_TO_L2_DAT[ADDR_WIDTH - 3 : 0] + current_section * (1 << (W - 5)) + m] <= DATA_TO_L2_DAT[m * DATA_WIDTH +: DATA_WIDTH];
                end
                
                writeFile = $fopen("E:/University/GrandFinale/Project/riscv_fpga/Simulation/RISCV_Processor/DataMemoryWrites.trac", "a");
                $fwrite("%d \t %d \t%d \n", WR_ADDR_TO_L2_DAT, DATA_TO_L2_DAT, WR_CONTROL_TO_L2_DAT);  
                $fclose(writeFile);     
            end    
        end else begin
            if (l2_wr_input_state[L2_DELAY_WR + L2_BURST  - 1]) begin
                l2_wr_input_state <= 1;
            end else begin
                l2_wr_input_state <= l2_wr_input_state << 1;
            end
            
            current_section   <= 0;
        end
    end
     
    always begin
        #5;
        CLK = !CLK;
    end
    
    
endmodule