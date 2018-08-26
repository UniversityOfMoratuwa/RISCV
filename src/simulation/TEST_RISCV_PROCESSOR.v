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

module Test_RISCV_PROCESSOR
#(
   parameter  ram_addr_width= 20                                         ,
 localparam ram_depth     = 2**ram_addr_width                            ,
 parameter data_width     = 32                                          ,
 parameter address_width  = 32                                           ,
 parameter block_size     = 8                                           ,
 parameter cache_depth    = 512                                          ,
 parameter l2_delay_read  = 10                                           ,
 localparam line_width    = $clog2(cache_depth)                          ,
 localparam offset_width  = $clog2(data_width*block_size/8 )               ,
 localparam tag_width     = address_width - line_width -  offset_width   ,
 localparam cache_width   = block_size*data_width                        ,
 parameter  C_M00_AXI_TARGET_SLAVE_BASE_ADDR    = 32'h00000000,
 parameter integer C_M00_AXI_BURST_LEN    = block_size,
 parameter integer C_M00_AXI_ID_WIDTH    = 1,
 parameter integer C_M00_AXI_ADDR_WIDTH    = 32,
 parameter integer C_M00_AXI_DATA_WIDTH    = 32,
 parameter integer C_M00_AXI_AWUSER_WIDTH    = 0,
 parameter integer C_M00_AXI_ARUSER_WIDTH    = 0,
 parameter integer C_M00_AXI_WUSER_WIDTH    = 0,
 parameter integer C_M00_AXI_RUSER_WIDTH    = 0,
 parameter integer C_M00_AXI_BUSER_WIDTH    = 0,
 parameter integer C_S00_AXI_ID_WIDTH    = 1,
 parameter integer C_S00_AXI_DATA_WIDTH    = 32,
 parameter integer C_S00_AXI_ADDR_WIDTH    = 32,
 parameter integer C_S00_AXI_AWUSER_WIDTH    = 0,
 parameter integer C_S00_AXI_ARUSER_WIDTH    = 0,
 parameter integer C_S00_AXI_WUSER_WIDTH    = 0,
 parameter integer C_S00_AXI_RUSER_WIDTH    = 0,
 parameter integer C_S00_AXI_BUSER_WIDTH    = 0
) ();
    // Fixed parameters
    localparam ADDR_WIDTH        = 32;
    localparam DATA_WIDTH        = 32;
    
    // Primary parameters for processor instantiation

                
    // Constants
    reg TRUE  = 1;
    reg FALSE = 0;    
    
    // Standard inputs    
    reg                           CLK;
    reg                           RSTN;             
             

 
    wire  m00_axi_init_axi_txn;                                
    wire  m00_axi_txn_done;                                    
    wire  m00_axi_error;                                     
    wire  m00_axi_aclk=CLK;                                         
    wire  m00_axi_aresetn=RSTN;                                      
    wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_awid;             
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_awaddr;          
    wire [7 : 0] m00_axi_awlen;                                
    wire [2 : 0] m00_axi_awsize;                               
    wire [1 : 0] m00_axi_awburst;                              
    wire  m00_axi_awlock;                                    
    wire [3 : 0] m00_axi_awcache;                             
    wire [2 : 0] m00_axi_awprot;                               
    wire [3 : 0] m00_axi_awqos;                               
    wire [C_M00_AXI_AWUSER_WIDTH-1 : 0] m00_axi_awuser;        
    wire  m00_axi_awvalid;                                     
    wire  m00_axi_awready;                                      
    wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_wdata;           
    wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] m00_axi_wstrb;         
    wire  m00_axi_wlast;                                       
    wire [C_M00_AXI_WUSER_WIDTH-1 : 0] m00_axi_wuser;          
    wire  m00_axi_wvalid;                                      
    wire  m00_axi_wready;                                       
    wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_bid;                
    wire [1 : 0] m00_axi_bresp;                                 
    wire [C_M00_AXI_BUSER_WIDTH-1 : 0] m00_axi_buser;          
    wire  m00_axi_bvalid;                                       
    wire  m00_axi_bready;                                      
    wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_arid;             
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_araddr;          
    wire [7 : 0] m00_axi_arlen;                                
    wire [2 : 0] m00_axi_arsize;                               
    wire [1 : 0] m00_axi_arburst;                              
    wire  m00_axi_arlock;                                      
    wire [3 : 0] m00_axi_arcache;                              
    wire [2 : 0] m00_axi_arprot;                               
    wire [3 : 0] m00_axi_arqos;                                
    wire [C_M00_AXI_ARUSER_WIDTH-1 : 0] m00_axi_aruser;        
    wire  m00_axi_arvalid;                                     
    wire  m00_axi_arready;                                      
    wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_rid;                
    wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_rdata;            
    wire [1 : 0] m00_axi_rresp;                                 
    wire  m00_axi_rlast;                                        
    wire [C_M00_AXI_RUSER_WIDTH-1 : 0] m00_axi_ruser;           
    wire  m00_axi_rvalid;                                       
    wire  m00_axi_rready;                                      
    wire  m01_axi_init_axi_txn;                                
    wire  m01_axi_txn_done;                                    
    wire  m01_axi_error;                                     
    wire  m01_axi_aclk=CLK;                                         
    wire  m01_axi_aresetn=RSTN;                                      
    wire [C_M00_AXI_ID_WIDTH-1 : 0] m01_axi_awid;             
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m01_axi_awaddr;          
    wire [7 : 0] m01_axi_awlen;                                
    wire [2 : 0] m01_axi_awsize;                               
    wire [1 : 0] m01_axi_awburst;                              
    wire  m01_axi_awlock;                                    
    wire [3 : 0] m01_axi_awcache;                             
    wire [2 : 0] m01_axi_awprot;                               
    wire [3 : 0] m01_axi_awqos;                               
    wire [C_M00_AXI_AWUSER_WIDTH-1 : 0] m01_axi_awuser;        
    wire  m01_axi_awvalid;                                     
    wire  m01_axi_awready;                                      
    wire [C_M00_AXI_DATA_WIDTH-1 : 0] m01_axi_wdata;           
    wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] m01_axi_wstrb;         
    wire  m01_axi_wlast;                                       
    wire [C_M00_AXI_WUSER_WIDTH-1 : 0] m01_axi_wuser;          
    wire  m01_axi_wvalid;                                      
    wire  m01_axi_wready;                                       
    wire [C_M00_AXI_ID_WIDTH-1 : 0] m01_axi_bid;                
    wire [1 : 0] m01_axi_bresp;                                 
    wire [C_M00_AXI_BUSER_WIDTH-1 : 0] m01_axi_buser;          
    wire  m01_axi_bvalid;                                       
    wire  m01_axi_bready;                                      
    wire [C_M00_AXI_ID_WIDTH-1 : 0] m01_axi_arid;             
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m01_axi_araddr;          
    wire [7 : 0] m01_axi_arlen;                                
    wire [2 : 0] m01_axi_arsize;                               
    wire [1 : 0] m01_axi_arburst;                              
    wire  m01_axi_arlock;                                      
    wire [3 : 0] m01_axi_arcache;                              
    wire [2 : 0] m01_axi_arprot;                               
    wire [3 : 0] m01_axi_arqos;                                
    wire [C_M00_AXI_ARUSER_WIDTH-1 : 0] m01_axi_aruser;        
    wire  m01_axi_arvalid;                                     
    wire  m01_axi_arready;                                      
    wire [C_M00_AXI_ID_WIDTH-1 : 0] m01_axi_rid;                
    wire [C_M00_AXI_DATA_WIDTH-1 : 0] m01_axi_rdata;            
    wire [1 : 0] m01_axi_rresp;                                 
    wire  m01_axi_rlast;                                        
    wire [C_M00_AXI_RUSER_WIDTH-1 : 0] m01_axi_ruser;           
    wire  m01_axi_rvalid;                                       
    wire  m01_axi_rready; 
   RISCV_PROCESSOR # (
   ) uut (
       // Standard inputs
       .CLK(CLK),
       .RSTN(RSTN),
       // Output address bus from Instruction Cache to Memory               
       //axi interface
       .m00_axi_aclk(m00_axi_aclk),
       .m00_axi_aresetn(m00_axi_aresetn),
       .m00_axi_awid(m00_axi_awid),
       .m00_axi_awaddr(m00_axi_awaddr),
        .m00_axi_awlen(m00_axi_awlen),
        .m00_axi_awsize(m00_axi_awsize),
        .m00_axi_awburst(m00_axi_awburst),
        .m00_axi_awlock(m00_axi_awlock),
        .m00_axi_awcache(m00_axi_awcache),
        .m00_axi_awprot(m00_axi_awprot),
        .m00_axi_awqos(m00_axi_awqos),
        .m00_axi_awuser(m00_axi_awuser),
        .m00_axi_awvalid(m00_axi_awvalid),
        .m00_axi_awready(m00_axi_awready),
        .m00_axi_wdata(m00_axi_wdata),
        .m00_axi_wstrb(m00_axi_wstrb),
        .m00_axi_wlast(m00_axi_wlast),
        .m00_axi_wuser(m00_axi_wuser),
        .m00_axi_wvalid(m00_axi_wvalid),
        .m00_axi_wready(m00_axi_wready),
        .m00_axi_bid(m00_axi_bid),
        .m00_axi_bresp(m00_axi_bresp),
        .m00_axi_buser(m00_axi_buser),
        .m00_axi_bvalid(m00_axi_bvalid),
        .m00_axi_bready(m00_axi_bready),
        .m00_axi_arid(m00_axi_arid),
        .m00_axi_araddr(m00_axi_araddr),
        .m00_axi_arlen(m00_axi_arlen),
        .m00_axi_arsize(m00_axi_arsize),
        .m00_axi_arburst(m00_axi_arburst),
        .m00_axi_arlock(m00_axi_arlock),
        .m00_axi_arcache(m00_axi_arcache),
        .m00_axi_arprot(m00_axi_arprot),
        .m00_axi_arqos(m00_axi_arqos),
        .m00_axi_aruser(m00_axi_aruser),
        .m00_axi_arvalid(m00_axi_arvalid),
        .m00_axi_arready(m00_axi_arready),
        .m00_axi_rid(m00_axi_rid),
        .m00_axi_rdata(m00_axi_rdata),
        .m00_axi_rresp(m00_axi_rresp),
        .m00_axi_rlast(m00_axi_rlast),
        .m00_axi_ruser(m00_axi_ruser),
        .m00_axi_rvalid(m00_axi_rvalid),
        .m00_axi_rready(m00_axi_rready),
               .m01_axi_aclk(m01_axi_aclk),
       .m01_axi_aresetn(m01_axi_aresetn),
       .m01_axi_awid(m01_axi_awid),
       .m01_axi_awaddr(m01_axi_awaddr),
        .m01_axi_awlen(m01_axi_awlen),
        .m01_axi_awsize(m01_axi_awsize),
        .m01_axi_awburst(m01_axi_awburst),
        .m01_axi_awlock(m01_axi_awlock),
        .m01_axi_awcache(m01_axi_awcache),
        .m01_axi_awprot(m01_axi_awprot),
        .m01_axi_awqos(m01_axi_awqos),
        .m01_axi_awuser(m01_axi_awuser),
        .m01_axi_awvalid(m01_axi_awvalid),
        .m01_axi_awready(m01_axi_awready),
        .m01_axi_wdata(m01_axi_wdata),
        .m01_axi_wstrb(m01_axi_wstrb),
        .m01_axi_wlast(m01_axi_wlast),
        .m01_axi_wuser(m01_axi_wuser),
        .m01_axi_wvalid(m01_axi_wvalid),
        .m01_axi_wready(m01_axi_wready),
        .m01_axi_bid(m01_axi_bid),
        .m01_axi_bresp(m01_axi_bresp),
        .m01_axi_buser(m01_axi_buser),
        .m01_axi_bvalid(m01_axi_bvalid),
        .m01_axi_bready(m01_axi_bready),
        .m01_axi_arid(m01_axi_arid),
        .m01_axi_araddr(m01_axi_araddr),
        .m01_axi_arlen(m01_axi_arlen),
        .m01_axi_arsize(m01_axi_arsize),
        .m01_axi_arburst(m01_axi_arburst),
        .m01_axi_arlock(m01_axi_arlock),
        .m01_axi_arcache(m01_axi_arcache),
        .m01_axi_arprot(m01_axi_arprot),
        .m01_axi_arqos(m01_axi_arqos),
        .m01_axi_aruser(m01_axi_aruser),
        .m01_axi_arvalid(m01_axi_arvalid),
        .m01_axi_arready(m01_axi_arready),
        .m01_axi_rid(m01_axi_rid),
        .m01_axi_rdata(m01_axi_rdata),
        .m01_axi_rresp(m01_axi_rresp),
        .m01_axi_rlast(m01_axi_rlast),
        .m01_axi_ruser(m01_axi_ruser),
        .m01_axi_rvalid(m01_axi_rvalid),
        .m01_axi_rready(m01_axi_rready)
    );
            

    
  
   
   
      
   
    initial begin
        CLK  = 0;
        RSTN = 0;
        #20;
        RSTN = 1;
        

 
    end


    always begin
        #5;
        CLK = !CLK;
    end
    
    myip_v1_0_S00_AXI # ( 
        .C_S_AXI_ID_WIDTH   (C_S00_AXI_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH (C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_S00_AXI_ADDR_WIDTH),
        .C_S_AXI_AWUSER_WIDTH(C_S00_AXI_AWUSER_WIDTH),
        .C_S_AXI_ARUSER_WIDTH(C_S00_AXI_ARUSER_WIDTH),
        .C_S_AXI_WUSER_WIDTH(C_S00_AXI_WUSER_WIDTH),
        .C_S_AXI_RUSER_WIDTH(C_S00_AXI_RUSER_WIDTH),
        .C_S_AXI_BUSER_WIDTH(C_S00_AXI_BUSER_WIDTH)
    ) myip_v1_0_S00_AXI_inst (
        .S_AXI_ACLK(m00_axi_aclk),
        .S_AXI_ARESETN(m00_axi_aresetn),
        .S_AXI_AWID(m00_axi_awid),
        .S_AXI_AWADDR(m00_axi_awaddr),
        .S_AXI_AWLEN(m00_axi_awlen),
        .S_AXI_AWSIZE(m00_axi_awsize),
        .S_AXI_AWBURST(m00_axi_awburst),
        .S_AXI_AWLOCK(m00_axi_awlock),
        .S_AXI_AWCACHE(m00_axi_awcache),
        .S_AXI_AWPROT(m00_axi_awprot),
        .S_AXI_AWQOS(m00_axi_awqos),
        .S_AXI_AWREGION(m00_axi_awregion),
        .S_AXI_AWUSER(m00_axi_awuser),
        .S_AXI_AWVALID(m00_axi_awvalid),
        .S_AXI_AWREADY(m00_axi_awready),
        .S_AXI_WDATA(m00_axi_wdata),
        .S_AXI_WSTRB(m00_axi_wstrb),
        .S_AXI_WLAST(m00_axi_wlast),
        .S_AXI_WUSER(m00_axi_wuser),
        .S_AXI_WVALID(m00_axi_wvalid),
        .S_AXI_WREADY(m00_axi_wready),
        .S_AXI_BID(m00_axi_bid),
        .S_AXI_BRESP(m00_axi_bresp),
        .S_AXI_BUSER(m00_axi_buser),
        .S_AXI_BVALID(m00_axi_bvalid),
        .S_AXI_BREADY(m00_axi_bready),
        .S_AXI_ARID(m00_axi_arid),
        .S_AXI_ARADDR(m00_axi_araddr),
        .S_AXI_ARLEN(m00_axi_arlen),
        .S_AXI_ARSIZE(m00_axi_arsize),
        .S_AXI_ARBURST(m00_axi_arburst),
        .S_AXI_ARLOCK(m00_axi_arlock),
        .S_AXI_ARCACHE(m00_axi_arcache),
        .S_AXI_ARPROT(m00_axi_arprot),
        .S_AXI_ARQOS(m00_axi_arqos),
        .S_AXI_ARREGION(m00_axi_arregion),
        .S_AXI_ARUSER(m00_axi_aruser),
        .S_AXI_ARVALID(m00_axi_arvalid),
        .S_AXI_ARREADY(m00_axi_arready),
        .S_AXI_RID(m00_axi_rid),
        .S_AXI_RDATA(m00_axi_rdata),
        .S_AXI_RRESP(m00_axi_rresp),
        .S_AXI_RLAST(m00_axi_rlast),
        .S_AXI_RUSER(m00_axi_ruser),
        .S_AXI_RVALID(m00_axi_rvalid),
        .S_AXI_RREADY(m00_axi_rready)
    );
        myip_v1_0_S00_AXI # ( 
        .C_S_AXI_ID_WIDTH   (C_S00_AXI_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH (C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_S00_AXI_ADDR_WIDTH),
        .C_S_AXI_AWUSER_WIDTH(C_S00_AXI_AWUSER_WIDTH),
        .C_S_AXI_ARUSER_WIDTH(C_S00_AXI_ARUSER_WIDTH),
        .C_S_AXI_WUSER_WIDTH(C_S00_AXI_WUSER_WIDTH),
        .C_S_AXI_RUSER_WIDTH(C_S00_AXI_RUSER_WIDTH),
        .C_S_AXI_BUSER_WIDTH(C_S00_AXI_BUSER_WIDTH)
    ) myip_v1_0_S01_AXI_inst (
        .S_AXI_ACLK(m01_axi_aclk),
        .S_AXI_ARESETN(m01_axi_aresetn),
        .S_AXI_AWID(m01_axi_awid),
        .S_AXI_AWADDR(m01_axi_awaddr),
        .S_AXI_AWLEN(m01_axi_awlen),
        .S_AXI_AWSIZE(m01_axi_awsize),
        .S_AXI_AWBURST(m01_axi_awburst),
        .S_AXI_AWLOCK(m01_axi_awlock),
        .S_AXI_AWCACHE(m01_axi_awcache),
        .S_AXI_AWPROT(m01_axi_awprot),
        .S_AXI_AWQOS(m01_axi_awqos),
        .S_AXI_AWREGION(m01_axi_awregion),
        .S_AXI_AWUSER(m01_axi_awuser),
        .S_AXI_AWVALID(m01_axi_awvalid),
        .S_AXI_AWREADY(m01_axi_awready),
        .S_AXI_WDATA(m01_axi_wdata),
        .S_AXI_WSTRB(m01_axi_wstrb),
        .S_AXI_WLAST(m01_axi_wlast),
        .S_AXI_WUSER(m01_axi_wuser),
        .S_AXI_WVALID(m01_axi_wvalid),
        .S_AXI_WREADY(m01_axi_wready),
        .S_AXI_BID(m01_axi_bid),
        .S_AXI_BRESP(m01_axi_bresp),
        .S_AXI_BUSER(m01_axi_buser),
        .S_AXI_BVALID(m01_axi_bvalid),
        .S_AXI_BREADY(m01_axi_bready),
        .S_AXI_ARID(m01_axi_arid),
        .S_AXI_ARADDR(m01_axi_araddr),
        .S_AXI_ARLEN(m01_axi_arlen),
        .S_AXI_ARSIZE(m01_axi_arsize),
        .S_AXI_ARBURST(m01_axi_arburst),
        .S_AXI_ARLOCK(m01_axi_arlock),
        .S_AXI_ARCACHE(m01_axi_arcache),
        .S_AXI_ARPROT(m01_axi_arprot),
        .S_AXI_ARQOS(m01_axi_arqos),
        .S_AXI_ARREGION(m01_axi_arregion),
        .S_AXI_ARUSER(m01_axi_aruser),
        .S_AXI_ARVALID(m01_axi_arvalid),
        .S_AXI_ARREADY(m01_axi_arready),
        .S_AXI_RID(m01_axi_rid),
        .S_AXI_RDATA(m01_axi_rdata),
        .S_AXI_RRESP(m01_axi_rresp),
        .S_AXI_RLAST(m01_axi_rlast),
        .S_AXI_RUSER(m01_axi_ruser),
        .S_AXI_RVALID(m01_axi_rvalid),
        .S_AXI_RREADY(m01_axi_rready)
    );
    // A
    reg [7:0] byte_ram[0: (1<<24)-1][0:3];

    bit [31:0] word_ram[0: (1<<24)-1];

    always@(negedge RSTN)
    begin
        $readmemh("data_hex.txt",word_ram);
        for (int j=0; j < (1<<24_); j=j+1)
        begin
            for (int i=0; i<4; i=i+1)
            begin
                byte_ram[j][i]=  word_ram[j][8*i +: 8];
            end
        end
    end
endmodule