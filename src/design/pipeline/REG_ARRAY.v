`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yasas Sneviratne
// 
// Create Date: 09/09/2016 08:56:17 PM
// Design Name: 
// Module Name: REG_ARRAY
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


module REG_ARRAY(
    input [31:0] DATA_IN,
    input [4:0] RS1_SEL,
    input [4:0] RS2_SEL,
    input CLK,
    input RST,
    input RD_WB_VALID_MEM3_WB,
    input [4:0] RD_WB_MEM3_WB,         // register which is written back to 
    output [31:0] RS1_DATAOUT,
    output [31:0] RS2_DATAOUT
    );
    (* ram_style = "distributed" *)
   
    reg [31:0] REGISTER [1:31];
     // to check wether t1he register write back is still in pipeline
    reg [31:0] RS1_DATAOUT_L=0;
    reg [31:0] RS2_DATAOUT_L=0;
 
    integer i;
 
    //debugging purposes ////////////////////////////////////////////////////////////////////
//      integer writeFile;
//      reg [31:0] last_data=0;
//      always @(posedge CLK)
//      begin
//         if(RD_WB_VALID_MEM3_WB && RD_WB_MEM3_WB==5'd14 && last_data!=DATA_IN)
//         begin
//             last_data<=DATA_IN;
//             writeFile = $fopen("mem_reads.txt", "a");
//             $fwrite(writeFile,"%h \n",DATA_IN);  
         
//             $fclose(writeFile);                                                         //
//         end                                                                             //
//                                                                                         //
//      end                                                                                //
                                                                                           // 
                                                                                           // 
      //////////////////////////////////////////////////////////////////////////////////////
//    wire reset = 1'b1;
//    wire [32*32-1 :0] reg_array_outs;
//    genvar j;
//    generate
//        for (j=0; j<=31;j=j+1)
//        begin : block_loop
//        if (j==0)
//        begin
//             assign reg_array_outs[0 +: 32] = 32'd0;
//        end
    
//        else
//            begin
//                assign reg_array_outs[j*32 +:32]=REGISTER[j];
//            end
//        end
//    endgenerate
    
    always@(posedge CLK)
    begin
        if(RST)
        begin
             for(i=1;i<32;i=i+1)
             begin
             if(i==2)
                 REGISTER[i] <= 32'h10000;
             else
                 REGISTER[i] <= 32'd0;
             end
        end
        else if(RD_WB_VALID_MEM3_WB)
        begin
            REGISTER[RD_WB_MEM3_WB] <= DATA_IN;
        end
    end
    assign RS1_DATAOUT = RS1_SEL== 5'd0 ? 32'd0 : REGISTER[RS1_SEL]; 
    assign RS2_DATAOUT = RS2_SEL== 5'd0 ? 32'd0 : REGISTER[RS2_SEL]; 

                 
   
endmodule
