`timescale 1 ps  /  1 ps
module MEMORY
    #(
        parameter data_width    = 32,
        parameter address_width = 32,
        parameter depth         = 512

        )
    (
        input                      CLK              ,
        input 			   RST		    ,
        input                      PORTA_WREN       ,
        input [address_width-1: 0] PORTA_RADDR      ,
        input [address_width-1: 0] PORTA_WADDR      ,
        input [data_width-1   : 0] PORTA_DATA_IN    ,
        input [data_width-1   : 0] PORTA_DATA_OUT   


        );

    reg [data_width-1:0] memory [0:depth-1];

    always@(posedge CLK)begin
	/*if(RST) for(int i = 0; i < depth; i=i+1) memory[i] <= 0;
        else*/ if (PORTA_WREN) begin
            memory [PORTA_WADDR]    <=  PORTA_DATA_IN       ;
        end
    end

    assign PORTA_DATA_OUT           =   memory[PORTA_RADDR] ;
endmodule
