`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:         RISC-V FYP Group
// Engineer:        Ravi Tharaka
// 
// Create Date:     07/29/2016 02:03:35 PM
// Design Name:     
// Module Name:     Memory Modules
// Project Name:    RISC-V Base ISA 
// Target Devices:  Any
// Tool Versions: 
// Description:     Parameterized depth and width multiplexer
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Mem_Simple_Dual_Port #(
        // Primary parameters
        parameter RAM_WIDTH = 64,                       // Specify RAM data width
        parameter RAM_DEPTH = 512,                      // Specify RAM depth (number of entries)
        parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE", // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        parameter INIT_FILE = ""                        // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) (
        // Inputs
        input [clogb2(RAM_DEPTH-1)-1:0] ADDR_W,   // Write address bus, width determined from RAM_DEPTH
        input [clogb2(RAM_DEPTH-1)-1:0] ADDR_R,   // Read address bus, width determined from RAM_DEPTH
        input [RAM_WIDTH-1:0] DATA_IN,            // RAM input data
        input CLK,                                // Clock
        input WR_ENB,                             // Write enable
        input RD_ENB,                             // Read Enable, for additional power savings, disable when not in use
        input OUT_RST,                            // Output reset (does not affect memory contents)
        input OUT_ENB,                            // Output register enable
      
        // Outputs
        output [RAM_WIDTH-1:0] DATA_OUT           // RAM output data
    );

    reg [RAM_WIDTH-1:0] bram [RAM_DEPTH-1:0];
    reg [RAM_WIDTH-1:0] ram_data = {RAM_WIDTH{1'b0}};

    // The following code either initializes the memory values to a specified file or to all zeros to match hardware
    generate
        if (INIT_FILE != "") begin: use_init_file
            initial
                $readmemh(INIT_FILE, bram, 0, RAM_DEPTH-1);
        end else begin: init_bram_to_zero
            integer ram_index;
            initial
                for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
                    bram[ram_index] = {RAM_WIDTH{1'b0}};
        end
    endgenerate

    always @(posedge CLK) begin
        if (WR_ENB)
            bram[ADDR_W] <= DATA_IN;
        if (RD_ENB)
            ram_data <= bram[ADDR_R];
    end

    //  The following code generates HIGH_PERFORMANCE (use output register) or LOW_LATENCY (no output register)
    generate
        if (RAM_PERFORMANCE == "LOW_LATENCY") begin: no_output_register
            // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
            assign DATA_OUT = ram_data;
            
        end else begin: output_register
            // The following is a 2 clock cycle read latency with improve clock-to-out timing
            reg [RAM_WIDTH-1:0] DATA_OUT_reg = {RAM_WIDTH{1'b0}};
            
            always @(posedge CLK) begin
                if (OUT_RST)
                    DATA_OUT_reg <= {RAM_WIDTH{1'b0}};
                else if (OUT_ENB)
                    DATA_OUT_reg <= ram_data;
            end    
            
            assign DATA_OUT = DATA_OUT_reg;
        end
    endgenerate

    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
        input integer depth;
        for (clogb2 = 0; depth > 0; clogb2 = clogb2 + 1)
            depth = depth >> 1;
    endfunction

endmodule

/*
//  Simple Dual Port RAM
    Mem_Simple_Dual_Port #(
        .RAM_WIDTH(),                           // Specify RAM data width
        .RAM_DEPTH(),                           // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE("")                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) your_instance_name (
        .ADDR_W(),          // Write address bus, width determined from RAM_DEPTH
        .ADDR_R(),          // Read address bus, width determined from RAM_DEPTH
        .DATA_IN(),         // RAM input data, width determined from RAM_WIDTH
        .CLK(),             // Clock
        .WR_ENB(),          // Write enable
        .RD_ENB(),	            // Read Enable, for additional power savings, disable when not in use
        .OUT_RST(),         // Output reset (does not affect memory contents)
        .OUT_ENB(),         // Output register enable
        .DATA_OUT()         // RAM output data, width determined from RAM_WIDTH
    );
*/
						
						