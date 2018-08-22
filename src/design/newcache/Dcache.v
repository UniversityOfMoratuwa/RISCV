`timescale 1 ps  /  1 ps
module Dcache
    #(
        parameter data_width    = 32                                            ,
        parameter address_width = 32                                            ,
        parameter block_size    = 32                                             ,
        parameter cache_depth   = 512                                           ,
        localparam line_width   = $clog2(cache_depth)                           ,
        localparam offset_width = $clog2(data_width*block_size  /8)               ,
        localparam tag_width    = address_width - line_width -  offset_width    ,
        localparam cache_width  = block_size*data_width

        )
    (
        input                    CLK                             ,
        input   [1:0]			 CONTROL               			,	
        input   [$clog2(data_width)-1: 0]	 WSTRB              ,
        input                    RST                             ,
        input                    FLUSH                           ,
        input  [address_width-1:0] ADDR                              ,
        input                    ADDR_VALID                      ,
        output reg [data_width-1:0]  DATA                            ,
        input      [data_width-1:0]  DATA_in                            ,
        output     reg           CACHE_READY                     ,
        output                   ADDR_TO_L2_VALID                ,
        output [address_width - offset_width-1:0]   ADDR_TO_L2                      ,
        output reg  [cache_width-1:0] DATA_FROM_L2                    ,
        output reg                    DATA_FROM_L2_VALID              ,
        output reg                    DATA_TO_L2_VALID                ,
        output reg  [address_width - offset_width-1:0] WADDR_TO_L2     

    );
    reg  [address_width-1:0] addr_d1             ;
    reg  [address_width-1:0] addr_d2             ;
    reg  [address_width-1:0] addr_d3             ;
    reg  [1:0]               control_d1          ;
    reg  [1:0]               control_d2          ;
    reg  [1:0]               control_d3          ;

    reg  [$clog2(data_width)-1:0]               wstrb_d1          ;
    reg  [$clog2(data_width)-1:0]               wstrb_d2          ;
    reg  [$clog2(data_width)-1:0]               wstrb_d3          ;
    reg  [1:0]               control_d2          ;
    reg  [1:0]               control_d3          ;

    reg [data_width-1:0]  data_d1;
    reg [data_width-1:0]  data_d2;
    reg [data_width-1:0]  data_d3;

    reg                     flag                ;
    reg                     addr_to_l2_valid    ;
    reg [address_width- offset_width -1:0] addr_to_l2          ;
    reg                     cache_porta_wren    ;
    reg  [line_width-1:0]   cache_porta_waddr   ;
    wire  [line_width-1:0]   cache_porta_raddr   ;
    reg  [cache_width-1:0]  cache_porta_data_in ;
    reg  [cache_width-1:0]  cache_porta_data_in_int ;
    wire  [cache_width-1:0]  cache_porta_data_out ;


    reg                     tag_porta_wren      ;
    reg  [line_width-1:0]   tag_porta_waddr     ;
    wire  [line_width-1:0]   tag_porta_raddr     ;
    reg  [tag_width-1:0]    tag_porta_data_in   ;
    wire  [tag_width-1:0]    tag_porta_data_out   ;
    wire [tag_width-1:0]    tag_addr            ;

    reg  [line_width-1:0]   state_waddr         ;
    wire  [line_width-1:0]  state_rdata         ;
    wire  [line_width-1:0]  state_raddr         ;
    reg                     state_wren          ;
    wire                    state               ;

    reg  [line_width-1:0]   dirty_waddr         ;
    wire  [line_width-1:0]  dirty_rdata         ;
    wire  [line_width-1:0]  dirty_raddr         ;
    reg                     dirty_wren          ;
    wire                    dirty               ;
    wire                    cache_ready;
    wire       [data_width-1:0]            data ;

        MEMORY  
    #(
        .data_width(cache_width ),
        .address_width(line_width),
        .depth(cache_depth)
        )
    cache_memory
    (
        .CLK(CLK),
        .PORTA_WREN(cache_porta_wren)           ,
        .PORTA_RADDR(cache_porta_raddr)         ,
        .PORTA_WADDR(cache_porta_waddr)         ,
        .PORTA_DATA_IN(cache_porta_data_in)     ,
        .PORTA_DATA_OUT(cache_porta_data_out)

        );
    MEMORY  
    #(
        .data_width(tag_width   )               ,
        .address_width(line_width)              ,
        .depth(cache_depth)
        )
    tag_memory
    (
        .CLK(CLK)                               ,
        .PORTA_WREN(tag_porta_wren)             ,
        .PORTA_RADDR(tag_porta_raddr)           ,
        .PORTA_WADDR(tag_porta_waddr)           ,
        .PORTA_DATA_IN(tag_porta_data_in)       ,
        .PORTA_DATA_OUT(tag_porta_data_out)

        );
    STATE_MEMORY
    #(
        .depth(cache_depth),
        .address_width(line_width)

    )
    state_memory_inst
    (
        .CLK(CLK)               ,
        .RST(RST)               ,
        .FLUSH(FLUSH)           ,
        .WREN(state_wren)       ,
        .WADDR (state_waddr)    ,
        .RADDR(state_raddr)     ,
        .STATE(state)   
     );
     
    STATE_MEMORY
    #(
        .depth(cache_depth),
        .address_width(line_width)

    )
    dirty_memory_inst
    (
        .CLK(CLK)               ,
        .RST(RST)               ,
        .FLUSH(FLUSH)           ,
        .WREN(dirty_wren)       ,
        .WADDR (dirty_waddr)    ,
        .RADDR(dirty_raddr)     ,
        .STATE(dirty)   
     );
     
    always@(*)
    begin
        CACHE_READY = cache_ready;
    end
    always @(posedge CLK) begin
        if (RST) begin
            addr_d1 <=   0;
            addr_d2 <=   0;
            addr_d3 <=   0;    
            control_d1 <=0;
            control_d2 <=0;
            control_d3 <=0;
       
            
        end
        else if (cache_ready & ADDR_VALID) begin
            addr_d1  <= ADDR;
            addr_d2  <= addr_d1 ;
            addr_d3  <= addr_d2 ;

            control_d1 <= CONTROL;
            control_d2 <= control_d1;
            control_d3 <= control_d2;
        end
    
    
    end
    always@(*)
    begin
            DATA    = data ;
    end

    always@(posedge CLK)
    begin
        if (RST)
        begin
            addr_to_l2_valid  <=0;
            addr_to_l2        <=0;
            flag              <=0;
        end
        else if (~cache_ready & ~state_wren )
        begin
            if(~addr_to_l2_valid & ~flag)
            begin
                addr_to_l2_valid    <= 1        ;
                addr_to_l2          <= addr_d3[address_width  -1 : offset_width] ;
                flag                <= 1        ;
            end
            else
            begin
                addr_to_l2_valid    <= 0        ;
            end

        end

        if (RST)
        begin


            dirty_wren              <= 0        ;
            dirty_waddr             <= 0        ;
            state_wren              <= 0        ;
            tag_porta_wren          <= 0        ;
            cache_porta_wren        <= 0        ;
            cache_porta_waddr       <= 0        ;   
            cache_porta_data_in     <= 0        ;
        end
        else if (cache_ready & control_d3 == 2'b10)
        begin
            cache_porta_wren      <= 1;
            cache_porta_data_in  <=  
        end
        else if (DATA_FROM_L2_VALID)
        begin
            cache_porta_wren    <= 1                ;
            cache_porta_data_in <= DATA_FROM_L2     ;
            cache_porta_waddr   <= cache_porta_raddr;
            tag_porta_wren      <= 1                ;
            tag_porta_waddr     <= tag_porta_raddr  ;
            state_wren          <= 1                ; 
            state_waddr         <= state_raddr      ;  
            tag_porta_data_in   <= tag_addr         ;
            flag                <= 0                ;       
        end
        else
        begin
            cache_porta_wren   <=  0            ;
            tag_porta_wren     <=  0            ;
            state_wren         <=  0            ;
        end
    end
    generate
     if (offset_width>2)
        assign data                 = cache_porta_data_out[{addr_d3[offset_width-1:2],2'b0}*8 +:data_width]       ;
    else begin
        assign data                 = cache_porta_data_out                                                ;
    end
    endgenerate
    
    assign cache_porta_raddr    = addr_d3[offset_width+line_width-1:offset_width]              ;
    assign dirty_raddr          = cache_porta_raddr                                         ;
    assign tag_porta_raddr      = cache_porta_raddr                                         ;
    assign state_raddr          = cache_porta_raddr                                         ;
    assign tag_addr             = addr_d3[address_width-1:offset_width+line_width]             ;
    assign cache_ready          =  (tag_porta_data_out == tag_addr) & state & (control_d3>2'b0)                ;
    assign ADDR_TO_L2_VALID     = addr_to_l2_valid                                          ;
    assign ADDR_TO_L2           = addr_to_l2                                                ;
    
    generate

        reg [data_width-1:0] data_to_be_writen;
        integer i;
     
       always@(*)  
       begin
           for (i=0;i<$clog2(data_width);i=i+1)
           begin
               if(wstrb[i])
               begin
                   data_to_be_writen[i*8 +: 8] = data_d3[i*8 +: 8];
               end
               else begin
                   data_to_be_writen[i*8 +: 8] = data[i*8 +: 8];
               end
           end
       end
        if (offset_width>2)
        begin
            data_to_be_writen[0 +: {addr_d3[offset_width-1:2],2'b0}*8]                                      = cache_porta_data_out[0 +: {addr_d3[offset_width-1:2],2'b0}*8]       ;
            data_to_be_writen[cache_width -: {addr_d3[offset_width-1:2],2'b0}*8+data_width]                 = cache_porta_data_out[0 +: {addr_d3[offset_width-1:2],2'b0}*8]       ;
            data_to_be_writen[{addr_d3[offset_width-1:2],2'b0}*8 +:data_width]                              = data_d3                                                ;


        end
        else begin 
            assign data                 = cache_porta_data_out                ;                                
        end
    endgenerate
endmodule



