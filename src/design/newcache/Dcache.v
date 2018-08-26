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
        input   [data_width/8-1: 0]	 WSTRB              ,
        input                    RST                             ,
        input                    FLUSH                           ,
        input  [address_width-1:0] ADDR                              ,
        input                    ADDR_VALID                      ,
        output reg [data_width-1:0]  DATA                            ,
        input      [data_width-1:0]  DATA_in                            ,
        output     reg           CACHE_READY                     ,
        output                   ADDR_TO_L2_VALID                ,
        output [address_width - offset_width-1:0]   ADDR_TO_L2                      ,
        input   [cache_width-1:0] DATA_FROM_L2                    ,
        input                   DATA_FROM_L2_VALID              ,
        output reg    [cache_width-1:0]          DATA_TO_L2,
        output reg                    DATA_TO_L2_VALID                ,
        output reg  [address_width - offset_width-1:0] WADDR_TO_L2    ,
        input                         WRITE_DONE 

    );
    reg  [address_width-1:0] addr_d0             ;
    reg  [address_width-1:0] addr_d1             ;
    reg  [address_width-1:0] addr_d2             ;
    reg  [address_width-1:0] addr_d3             ;
    reg  [address_width-1:0] addr_d4             ;
    reg  [address_width- offset_width -1:0] addr_reg             ;
    reg  [1:0]               control_d0          ;
    reg  [1:0]               control_d1          ;
    reg  [1:0]               control_d2          ;
    reg  [1:0]               control_d3          ;

    reg  [data_width/8-1:0]               wstrb_d0          ;
    reg  [data_width/8-1:0]               wstrb_d1          ;
    reg  [data_width/8-1:0]               wstrb_d2          ;
    reg  [data_width/8-1:0]               wstrb_d3          ;

    reg [data_width-1:0]  data_d0;
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
    reg  [cache_width-1:0]  cache_porta_data_out_reg ;
    wire  [cache_width-1:0]  cache_porta_data_out_i ;


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
    reg                     dirty_din           ;
    reg                     dirty_reg           ;
    wire                    cache_ready;
    reg                     writing ;
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
        .PORTA_DATA_OUT(cache_porta_data_out_i)

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
        .STATE(state)   ,
        .DATA(1'b1)
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
        .STATE(dirty)   ,
        .DATA(dirty_din)
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
            data_d1   <=0;
            data_d2  <=0;
            data_d3 <=0;
            
        end
        else if (cache_ready & ADDR_VALID) begin
            addr_d0  <= ADDR;
            addr_d1  <= addr_d0;
            addr_d2  <= addr_d1 ;
            addr_d3  <= addr_d2 ;
            addr_d4 <= addr_d3;

            control_d0 <= CONTROL;
            control_d1 <= control_d0;
            control_d2 <= control_d1;
            control_d3 <= control_d2;

            data_d0    <= DATA_in;
            data_d1    <= data_d0;
            data_d2    <= data_d1;
            data_d3    <= data_d2;
            
            wstrb_d0   <= WSTRB;
            wstrb_d1   <= wstrb_d0;
            wstrb_d2   <= wstrb_d1;
            wstrb_d3   <= wstrb_d2;
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
            DATA_TO_L2_VALID <=0;

        end
        else if (~cache_ready  )
        begin
            if(~addr_to_l2_valid & ~flag & ~dirty_reg  & ~state_wren & ~writing)
            begin
                addr_to_l2_valid    <= 1        ;
                addr_to_l2          <= addr_d3[address_width  -1 : offset_width] ;
                flag                <= 1        ;
            end
            else if (dirty_reg )
            begin
                WADDR_TO_L2         <= addr_reg;
                DATA_TO_L2_VALID  <= 1;
                DATA_TO_L2        <= cache_porta_data_out_reg;
            end
            else 
            begin
                addr_to_l2_valid    <= 0        ;
                DATA_TO_L2_VALID  <= 0;
                DATA_TO_L2_VALID  <= 0;
            end

        end

        if(RST)
        begin
            writing <=0;
        end
        else if (dirty_reg)
        begin
            writing <=1;
        end
        else if (WRITE_DONE)
        begin
            writing <=0;
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
            cache_porta_data_in  <=  cache_porta_data_in_int;
            cache_porta_waddr    <= cache_porta_raddr;
            dirty_wren           <= 1;
            dirty_waddr          <= dirty_raddr;
            dirty_din            <=1;
        end
        else if (DATA_FROM_L2_VALID)
        begin
            begin
                cache_porta_wren    <= 1                ;
                cache_porta_data_in <= control_d3 == 2'b10 ? cache_porta_data_in_int  : DATA_FROM_L2     ;
                cache_porta_waddr   <= cache_porta_raddr;
                tag_porta_wren      <= 1                ;
                tag_porta_waddr     <= tag_porta_raddr  ;
                state_wren          <= 1                ; 
                state_waddr         <= state_raddr      ;  
                tag_porta_data_in   <= tag_addr         ;
                flag                <= 0                ; 
                dirty_reg           <= dirty            ;
                dirty_wren          <= 1    ;
                cache_porta_data_out_reg <= cache_porta_data_out_i;
                dirty_din          <=   control_d3 == 2'b10 ;
                dirty_waddr        <= dirty_raddr;
                addr_reg            <= {tag_porta_data_out,addr_d3[address_width-tag_width-1 : offset_width]};
            end      

        end

        else
        begin
            cache_porta_wren   <=  0            ;
            tag_porta_wren     <=  0            ;
            state_wren         <=  0            ;
            dirty_wren         <=  0            ;
            dirty_din          <= 0;
            dirty_reg          <=0;
        end
    end

    



    reg [data_width-1:0] data_to_be_writen;
    integer i;
 
   always@(*)  
   begin
       for (i=0;i<data_width/8;i=i+1)
       begin
           if(wstrb_d3[i])
           begin
               data_to_be_writen[i*8 +: 8] = data_d3[i*8 +: 8];
           end
           else begin
               data_to_be_writen[i*8 +: 8] = data[i*8 +: 8];
           end
       end
       for (i = 0; i<cache_width ;i=i+data_width)
       begin
           if (i== {addr_d3[offset_width-1:2],2'b0}*8 )
           begin
            cache_porta_data_in_int[i +:data_width]                                      = data_to_be_writen;
           end
           else
           begin
            cache_porta_data_in_int[i +:data_width]                 =  cache_porta_data_out[i +:data_width]       ;
           end      
      end
   end
    generate
    if (offset_width>2)
        assign data                 = cache_porta_data_out[{addr_d3[offset_width-1:2],2'b0}*8 +:data_width];
    else begin
        assign data                 = cache_porta_data_out                                                        ;
    end
    endgenerate
    assign cache_porta_data_out = DATA_FROM_L2_VALID ? DATA_FROM_L2 :  ((dirty_wren & addr_d3[offset_width+line_width-1:offset_width]==addr_d4[offset_width+line_width-1:offset_width])? cache_porta_data_in: cache_porta_data_out_i);

    assign cache_porta_raddr    = addr_d3[offset_width+line_width-1:offset_width]              ;
    assign dirty_raddr          = cache_porta_raddr                                         ;
    assign tag_porta_raddr      = cache_porta_raddr                                         ;
    assign state_raddr          = cache_porta_raddr                                         ;
    assign tag_addr             = addr_d3[address_width-1:offset_width+line_width]             ;
    assign cache_ready          =  ((tag_porta_data_out == tag_addr) & state  & ~writing) | (control_d3!==2'b01 & control_d3!==2'b10)    ;
    assign ADDR_TO_L2_VALID     = addr_to_l2_valid                                          ;
    assign ADDR_TO_L2           = addr_to_l2                                                ;
    


endmodule



