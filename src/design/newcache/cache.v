`timescale 1 ps  /  1 ps
module Icache
    #(
        parameter data_width    = 32                                            ,
        parameter address_width = 32                                            ,
        parameter block_size    = 8                                             ,
        parameter cache_depth   = 512                                           ,
        localparam line_width   = $clog2(cache_depth)                           ,
        localparam offset_width = $clog2(data_width*block_size  /8)               ,
        localparam tag_width    = address_width - line_width -  offset_width    ,
        localparam cache_width  = block_size*data_width

        )
    (
        input                    CLK                             ,
        input                    RST                             ,
        input                    FLUSH                           ,
        input  [address_width-1:0] ADDR                              ,
        input                    ADDR_VALID                      ,
        output [data_width-1:0]  DATA                            ,
        output                   CACHE_READY                     ,
        output                   ADDR_TO_L2_VALID                ,
        output [address_width - offset_width-1:0]   ADDR_TO_L2                      ,
        input  [cache_width-1:0] DATA_FROM_L2                    ,
        input                    DATA_FROM_L2_VALID              




    );
    reg                     addr_d1             ;
    reg                     addr_d2             ;
    reg                     addr_d3             ;
    reg                     addr_d4             ;
    reg                     flag                ;
    reg                     addr_to_l2_valid    ;
    reg [address_width- offset_width -1:0] addr_to_l2          ;
    reg                     cache_porta_wren    ;
    reg                     cache_portb_wren    ;
    wire [line_width-1:0]   cache_portc_raddr   ;
    reg  [line_width-1:0]   cache_porta_waddr   ;
    reg  [line_width-1:0]   cache_portb_waddr   ;
    reg  [cache_width-1:0]  cache_porta_data_in ;
    reg  [cache_width-1:0]  cache_portb_data_in ;
    wire [cache_width-1:0]  cache_portc_data_out;


    reg                     tag_porta_wren      ;
    reg                     tag_portb_wren      ;
    wire [line_width-1:0]   tag_portc_raddr     ;
    reg  [line_width-1:0]   tag_porta_waddr     ;
    reg  [line_width-1:0]   tag_portb_waddr     ;
    reg  [tag_width-1:0]    tag_porta_data_in   ;
    reg  [tag_width-1:0]    tag_portb_data_in   ;
    wire [tag_width-1:0]    tag_portc_data_out  ;   
    wire [tag_width-1:0]    tag_addr            ;

    reg  [line_width-1:0]   state_waddr         ;
    wire  [line_width-1:0]  state_rdata         ;
    wire  [line_width-1:0]  state_raddr         ;
    reg                     state_wren          ;
    wire                    state               ;
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
        .PORTB_WREN(cache_portb_wren)           ,
        .PORTC_RADDR(cache_portc_raddr)         ,
        .PORTA_WADDR(cache_porta_waddr)         ,
        .PORTB_WADDR(cache_portb_waddr)         ,
        .PORTA_DATA_IN(cache_porta_data_in)     ,
        .PORTB_DATA_IN(cache_portb_data_in)     ,
        .PORTC_DATA_OUT(cache_portc_data_out)

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
        .PORTB_WREN(tag_portb_wren)             ,
        .PORTC_RADDR(tag_portc_raddr)           ,
        .PORTA_WADDR(tag_porta_waddr)           ,
        .PORTB_WADDR(tag_portb_waddr)           ,
        .PORTA_DATA_IN(tag_porta_data_in)       ,
        .PORTB_DATA_IN(tag_portb_data_in)       ,
        .PORTC_DATA_OUT(tag_portc_data_out)

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
    always@(posedge CLK)
    begin
        if(RST )
        begin
            addr_d1 <=0;
            addr_d2 <=0;
            addr_d3 <=0;
            addr_d4 <=0;
        end
        else if(ADDR_VALID)
        begin
            addr_d1 <= ADDR;
            addr_d2 <= addr_d1;
            addr_d3 <= addr_d2;
            addr_d4 <= addr_d3;
        end
    end
    always@(posedge CLK)
    begin
        if (RST)
        begin
            addr_to_l2_valid  <=0;
            addr_to_l2        <=0;
            flag              <=0;
        end
        else if (~CACHE_READY & ADDR_VALID & ~state_wren )
        begin
            if(~addr_to_l2_valid & ~flag)
            begin
                addr_to_l2_valid    <= 1        ;
                addr_to_l2          <= addr_d4[address_width  -1 : offset_width] ;
                flag                <= 1        ;
            end
            else
            begin
                addr_to_l2_valid    <= 0        ;
            end

        end

        if (RST)
        begin
            state_wren              <= 0        ;
            tag_portb_wren          <= 0        ;
            tag_porta_wren          <= 0        ;
            cache_portb_wren        <= 0        ;
            cache_porta_wren        <= 0        ;
            cache_porta_waddr       <= 0        ;   
            cache_portb_waddr       <= 0        ;
            cache_porta_data_in     <= 0        ;
            cache_portb_data_in     <= 0        ;   
        end
        else if (DATA_FROM_L2_VALID)
        begin
            cache_porta_wren    <= 1                ;
            cache_porta_data_in <= DATA_FROM_L2     ;
            cache_porta_waddr   <= cache_portc_raddr;
            tag_porta_wren      <= 1                ;
            tag_porta_waddr     <= tag_portc_raddr  ;
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
    assign DATA                 = cache_portc_data_out[{addr_d4[offset_width-1:2],2'b0}*8 +:32]       ;
    assign cache_portc_raddr    = addr_d4[offset_width+line_width-1:offset_width]              ;
    assign tag_portc_raddr      = cache_portc_raddr                                         ;
    assign state_raddr          = cache_portc_raddr                                         ;
    assign tag_addr             = addr_d4[address_width-1:offset_width+line_width]             ;
    assign CACHE_READY          = (tag_portc_data_out == tag_addr) & state                  ;
    assign ADDR_TO_L2_VALID     = addr_to_l2_valid                                          ;
    assign ADDR_TO_L2           = addr_to_l2                                                ;
endmodule
module STATE_MEMORY         
    #(
        parameter depth          = 512              ,
        parameter address_width  = $clog2(depth)

    )
        (
        input                     CLK       ,
        input                     RST       ,
        input                     FLUSH     ,
        input                     WREN      ,   
        input [address_width-1:0] WADDR     ,
        input [address_width-1:0] RADDR     ,
        output                    STATE   
     );
    reg [depth-1:0] state_mem;  
    always@(posedge CLK)
    begin
        
        if(RST | FLUSH)
        begin
            state_mem       <=  0       ;
        end
        else if (WREN)
        begin
            state_mem[WADDR] <= 1       ;
        end
    end
    assign STATE = state_mem[RADDR]     ;
endmodule
module MEMORY
    #(
        parameter data_width    = 32,
        parameter address_width = 32,
        parameter depth         = 512

        )
    (
        input                      CLK              ,
        input                      PORTA_WREN       ,
        input                      PORTB_WREN       ,
        input [address_width-1: 0] PORTC_RADDR      ,
        input [address_width-1: 0] PORTA_WADDR      ,
        input [address_width-1: 0] PORTB_WADDR      ,
        input [data_width-1   : 0] PORTA_DATA_IN    ,
        input [data_width-1   : 0] PORTB_DATA_IN    ,
        input [data_width-1   : 0] PORTC_DATA_OUT   


        );
    reg [data_width-1:0] memory [0:depth-1];
    always@(posedge CLK)
    begin
        if (PORTA_WREN)
        begin
            memory [PORTA_WADDR]    <=  PORTA_DATA_IN       ;
        end
        if (PORTB_WREN)
        begin
            memory [PORTB_WADDR]    <=  PORTB_DATA_IN       ;
        end
    end
    assign PORTC_DATA_OUT           =   memory[PORTC_RADDR] ;
endmodule

