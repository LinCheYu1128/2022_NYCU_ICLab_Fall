//++++++++++++++ Include DesignWare++++++++++++++++++
// synopsys translate_off
`include "DW_minmax.v"
// synopsys translate_on
//+++++++++++++++++++++++++++++++++++++++++++++++++
module EDH(
    // CHIP IO
    clk,
    rst_n,
    in_valid,
    pic_no,
    se_no,
    op,
    busy,

    // AXI4 IO
    arid_m_inf,
    araddr_m_inf,
    arlen_m_inf,
    arsize_m_inf,
    arburst_m_inf,
    arvalid_m_inf,
    arready_m_inf,
    
    rid_m_inf,
    rdata_m_inf,
    rresp_m_inf,
    rlast_m_inf,
    rvalid_m_inf,
    rready_m_inf,

    awid_m_inf,
    awaddr_m_inf,
    awsize_m_inf,
    awburst_m_inf,
    awlen_m_inf,
    awvalid_m_inf,
    awready_m_inf,

    wdata_m_inf,
    wlast_m_inf,
    wvalid_m_inf,
    wready_m_inf,
    
    bid_m_inf,
    bresp_m_inf,
    bvalid_m_inf,
    bready_m_inf 
);
// ===============================================================
//                      Parameter Declaration 
// ===============================================================
parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32;    // DO NOT modify AXI4 Parameter

// ===============================================================
//                      Input / Output 
// ===============================================================

// << CHIP io port with system >>
input              clk, rst_n;
input              in_valid;
input      [3:0]   pic_no;
input      [5:0]   se_no;    
input      [1:0]   op;
output reg         busy;     

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
    Your AXI-4 interface could be designed as a bridge in submodule,
    therefore I declared output of AXI as wire.  
    Ex: AXI4_interface AXI4_INF(...);
*/

// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)    axi read address channel 
output wire [ID_WIDTH-1:0]      arid_m_inf;
output wire [1:0]            arburst_m_inf;
output wire [2:0]             arsize_m_inf;
output wire [7:0]              arlen_m_inf;
output wire                  arvalid_m_inf;
input  wire                  arready_m_inf;
output wire [ADDR_WIDTH-1:0]  araddr_m_inf;
// ------------------------
// (2)    axi read data channel 
input  wire [ID_WIDTH-1:0]       rid_m_inf;
input  wire                   rvalid_m_inf;
output wire                   rready_m_inf;
input  wire [DATA_WIDTH-1:0]   rdata_m_inf;
input  wire                    rlast_m_inf;
input  wire [1:0]              rresp_m_inf;
// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1)     axi write address channel 
output wire [ID_WIDTH-1:0]      awid_m_inf;
output wire [1:0]            awburst_m_inf;
output wire [2:0]             awsize_m_inf;
output wire [7:0]              awlen_m_inf;
output wire                  awvalid_m_inf;
input  wire                  awready_m_inf;
output wire [ADDR_WIDTH-1:0]  awaddr_m_inf;
// -------------------------
// (2)    axi write data channel 
output wire                   wvalid_m_inf;
input  wire                   wready_m_inf;
output wire [DATA_WIDTH-1:0]   wdata_m_inf;
output wire                    wlast_m_inf;
// -------------------------
// (3)    axi write response channel 
input  wire  [ID_WIDTH-1:0]      bid_m_inf;
input  wire                   bvalid_m_inf;
output wire                   bready_m_inf;
input  wire  [1:0]             bresp_m_inf;
// -----------------------------
//================================================================
//  Assign some fixed signal
//================================================================
assign arid_m_inf    = 0      ;
assign arsize_m_inf  = 3'b100 ;
assign arburst_m_inf = 2'b01  ;
assign awid_m_inf    = 0      ;
assign awsize_m_inf  = 3'b100 ;
assign awburst_m_inf = 2'b01  ;
assign awlen_m_inf   = 255    ;
//================================================================
//  FSM parameter
//================================================================
reg [2:0] current_state, next_state;
parameter IDLE   = 3'd0;
parameter INPUT  = 3'd1;
parameter LOAD   = 3'd2; // load se state
parameter READ   = 3'd3; // load pic to SRAM
parameter WRITE  = 3'd4; // cal write pic back to dram
//================================================================
//  reg wire declaration
//================================================================
reg  [3:0]       pic_no_reg;
reg  [5:0]        se_no_reg;    
reg  [1:0]           op_reg;
reg  [8:0]     addr_control;

reg  [7:0]        se_kernel[0:15];
reg  [12:0]     line_buffer[0:255];
wire [7:0]    sram_position[0:15];
wire [7:0]         position[0:15];
wire [8:0]    minus_element[0:255]; // do pic - se
wire [8:0]      add_element[0:255]; // do pic + se
wire [7:0]  erosion_correct[0:255]; // check if excced min (0)
wire [7:0] dilation_correct[0:255]; // check if excced max (255)
wire [7:0]          element[0:255];
wire [7:0]          compare[0:239]; // find min max
wire [7:0]           answer[0:15];
wire      zero_padding_flag;

reg  [12:0]     denominator;       // mother
reg  [20:0]       numerator[0:15]; // son
reg  [7:0]      min_element;
wire [7:0] min_element_temp;
wire [12:0]         cdf_min;
reg  [7:0]         hist_ans[0:15];
//================================================================
//  AXI4 declaration
//================================================================
reg         rd_valid;
// reg [11:0]  rd_addr ;
reg [127:0] rd_data ;
reg        rd_se_pic;

reg         wr_valid;
// reg [11:0]  wr_addr ;
reg [127:0] wr_data ;
reg         wr_ready;
reg         fin_flag;
//================================================================
//  SRAM CONTROL
//================================================================
reg MEM_wen;
reg  [7:0] MEM_addr;
reg  [127:0] MEM_in;
wire [127:0] MEM_out;

RA1SH_128_256 PIC_SRAM(.Q(MEM_out), .CLK(clk), .CEN(1'b0), .WEN(MEM_wen), .A(MEM_addr), .D(MEM_in), .OEN(1'b0) );

always @(*) begin
    MEM_in = rdata_m_inf;
end

always @(*) begin
    if(rvalid_m_inf)
        MEM_wen = 0;
    else
        MEM_wen = 1;
end

always @(*) begin
    if(!op_reg[1] && addr_control == 16 && wready_m_inf)
        MEM_addr = 17;
    else if(addr_control == 0 && wready_m_inf)
        MEM_addr = 1;
    else
        MEM_addr = addr_control[7:0];
end
//================================================================
//  DESIGN
//================================================================
reg [31:0] debug;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        debug <= 0;
    else if(current_state == WRITE && wready_m_inf)
        debug <= debug + 1;
end

assign zero_padding_flag = (addr_control[1:0] == 2'b00 && addr_control > 17 );

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        addr_control <= 0;
    else if(current_state == READ)begin
        if(rvalid_m_inf)
            addr_control <= addr_control + 1;
    end
    else if(current_state == WRITE)begin
        if(op_reg[1])begin
           if(wready_m_inf)
                addr_control <= (addr_control == 0)? addr_control + 2 : addr_control + 1;
            else
                addr_control <= 0;
        end
        else begin
            if(wready_m_inf)
                addr_control <= (addr_control == 16)? addr_control + 2 : addr_control + 1; 
            else
                addr_control <= 16;
        end
    end
    else 
        addr_control <= 0;
end

DW_minmax #(8, 16) MIN_IP(.a({rdata_m_inf}), .tc(0), .min_max(0), .value(min_element_temp));

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        min_element <= 255;
    else if(current_state == READ)begin
        if(rvalid_m_inf)
            min_element <= (min_element > min_element_temp)? min_element_temp : min_element;
        else 
            min_element <= min_element;
    end
    else if(current_state == IDLE)begin
        min_element <= 255;
    end 
end

assign cdf_min = line_buffer[min_element];

always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		denominator <= 1;
	end
	else begin
		denominator <= 4096 - cdf_min;
	end
end

// always@(posedge clk or negedge rst_n)begin
// 	if(!rst_n)begin
// 		for(i=0;i<16;i=i+1) 
//             numerator[i] <= 0;
// 	end
// 	else begin
//         for(i=0;i<16;i=i+1)begin
//             numerator[i] <= (line_buffer[sram_position[i]] - cdf_min)*255;
//         end
// 	end
// end

genvar i, j, k;
generate
    // hist answer
    for(i=0; i<16; i=i+1) begin
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                hist_ans[i] <= 0;
            end
            else begin
                if(denominator==0)
                    hist_ans[i] <= 255;
                else
                    hist_ans[i] <= numerator[i]/denominator;
            end
        end
    end

    // numerator
    for(i=0; i<16; i=i+1) begin
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                numerator[i] <= 0;
            end
            else begin
                numerator[i] <= (line_buffer[sram_position[i]] - cdf_min)*255;
            end
        end
    end

    // se kernel
    for(i=0; i<16; i=i+1)begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)
                se_kernel[i] <= 0;
            else if(current_state == LOAD && rvalid_m_inf)
                se_kernel[i] <= (op_reg[0])? rdata_m_inf[8*(15-i)+7 : 8*(15-i)] : rdata_m_inf[8*i+7 : 8*i];
        end
    end

    // assign each pixel data from dram
    for(i=0; i<16; i=i+1)begin
        assign position[i] = rdata_m_inf[8*i+7 : 8*i];
        assign sram_position[i] = MEM_out[8*i+7 : 8*i];
    end

    // line buffer
    for(i=0; i<256; i=i+1)begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)     
                line_buffer[i] <= 0 ;
            else if(current_state == READ && rvalid_m_inf)begin
                if(op_reg[1])begin   // hist
                    line_buffer[i] <= line_buffer[i] + (position[ 0]<=i) + (position[ 1]<=i) + (position[ 2]<=i) + (position[ 3]<=i)
                                                     + (position[ 4]<=i) + (position[ 5]<=i) + (position[ 6]<=i) + (position[ 7]<=i)
                                                     + (position[ 8]<=i) + (position[ 9]<=i) + (position[10]<=i) + (position[11]<=i)
                                                     + (position[12]<=i) + (position[13]<=i) + (position[14]<=i) + (position[15]<=i);
                end
                else begin   // erosion dilation
                    if(addr_control < 16)begin
                        if(i>=240)
                            line_buffer[i] <= {5'b0, position[i-240]};
                        else
                            line_buffer[i] <= line_buffer[i+16];
                    end
                end
            end
            else if(current_state == WRITE && wready_m_inf)begin
                if(op_reg[1])begin
                    line_buffer[i] <= line_buffer[i];
                end
                else begin
                    if(i>=240)begin
                        if(addr_control > 256)
                            line_buffer[i] <= 12'b0;
                        else
                            line_buffer[i] <= {5'b0, sram_position[i-240]};
                    end
                    else begin
                        line_buffer[i] <= line_buffer[i+16];
                    end
                end 
            end
            else if(current_state == IDLE)begin
                line_buffer[i] <= 0 ;
            end
        end
    end

    // ersion and dilation element
    for(i=0; i<13; i=i+1)begin
        for(j=0; j<4; j=j+1)begin
            for(k=0; k<4; k=k+1)begin
                assign minus_element[16*i+4*j+k] = line_buffer[i+64*j+k][7:0] - se_kernel[4*j+k];
                assign   add_element[16*i+4*j+k] = line_buffer[i+64*j+k][7:0] + se_kernel[4*j+k];
            end
        end
    end
    for(j=0; j<4; j=j+1)begin
        for(k=0; k<4; k=k+1)begin
            if(k<3)begin
                assign minus_element[16*13+4*j+k] = line_buffer[13+64*j+k][7:0] - se_kernel[4*j+k];
                assign   add_element[16*13+4*j+k] = line_buffer[13+64*j+k][7:0] + se_kernel[4*j+k];
            end
            else begin
                assign minus_element[16*13+4*j+k] = (zero_padding_flag)? 0 : line_buffer[13+64*j+k][7:0] - se_kernel[4*j+k];
                assign   add_element[16*13+4*j+k] = (zero_padding_flag)? se_kernel[4*j+k] : line_buffer[13+64*j+k][7:0] + se_kernel[4*j+k];
            end

            if(k<2)begin
                assign minus_element[16*14+4*j+k] = line_buffer[14+64*j+k][7:0] - se_kernel[4*j+k];
                assign   add_element[16*14+4*j+k] = line_buffer[14+64*j+k][7:0] + se_kernel[4*j+k];
            end
            else begin
                assign minus_element[16*14+4*j+k] = (zero_padding_flag)? 0 : line_buffer[14+64*j+k][7:0] - se_kernel[4*j+k];
                assign   add_element[16*14+4*j+k] = (zero_padding_flag)? se_kernel[4*j+k] : line_buffer[14+64*j+k][7:0] + se_kernel[4*j+k];
            end

            if(k<1)begin
                assign minus_element[16*15+4*j+k] = line_buffer[15+64*j+k][7:0] - se_kernel[4*j+k];
                assign   add_element[16*15+4*j+k] = line_buffer[15+64*j+k][7:0] + se_kernel[4*j+k];
            end
            else begin
                assign minus_element[16*15+4*j+k] = (zero_padding_flag)? 0 : line_buffer[15+64*j+k][7:0] - se_kernel[4*j+k];
                assign   add_element[16*15+4*j+k] = (zero_padding_flag)? se_kernel[4*j+k] : line_buffer[15+64*j+k][7:0] + se_kernel[4*j+k];
            end
        end
    end

    // check if excced range
    for(i=0; i<16; i=i+1)begin
        for(j=0; j<4; j=j+1)begin
            for(k=0; k<4; k=k+1)begin
                assign  erosion_correct[16*i+4*j+k] = (minus_element[16*i+4*j+k][8])? 0   : minus_element[16*i+4*j+k][7:0];
                assign dilation_correct[16*i+4*j+k] = (  add_element[16*i+4*j+k][8])? 255 :   add_element[16*i+4*j+k][7:0];
            end
        end
    end

    // element
    for(k=0;k<256;k=k+1)begin
		assign element[k] = (op_reg[0]) ? dilation_correct[k] : erosion_correct[k];
	end

    // find min max
    for(i=0; i<16; i=i+1)begin
		for(j=0; j<8; j=j+1)begin
			assign compare[j+15*i] = (element[j*2+16*i] < element[j*2+1+16*i])^op_reg[0] ? element[j*2+16*i] : element[j*2+1+16*i];
		end
		for(j=0; j<4; j=j+1)begin
			assign compare[j+8+15*i] = (compare[j*2+15*i] < compare[j*2+1+15*i])^op_reg[0] ? compare[j*2+15*i] : compare[j*2+1+15*i];
		end
		assign compare[12+15*i] = (compare[ 8+15*i]<compare[ 9+15*i])^op_reg[0] ? compare[ 8+15*i] : compare[ 9+15*i];
		assign compare[13+15*i] = (compare[10+15*i]<compare[11+15*i])^op_reg[0] ? compare[10+15*i] : compare[11+15*i];
		assign compare[14+15*i] = (compare[12+15*i]<compare[13+15*i])^op_reg[0] ? compare[12+15*i] : compare[13+15*i];
	end

    // answer
    for(i=0; i<16; i=i+1)begin
		assign answer[i] = compare[14+15*i];
	end
endgenerate


always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     
        pic_no_reg <= 0 ;
    else if(in_valid)
        pic_no_reg <= pic_no;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     
        se_no_reg <= 0 ;
    else if(in_valid)
        se_no_reg <= se_no;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     
        op_reg <= 0 ;
    else if(in_valid)
        op_reg <= op;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        rd_se_pic <= 0;
    else if(next_state == LOAD)
        rd_se_pic <= 0;
    else if(next_state == READ)
        rd_se_pic <= 1;
end
//================================================================
//  FSM
//================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     current_state <= IDLE ;
    else            current_state <= next_state ;
end
// Next State
always @(*) begin
    if (!rst_n) 
        next_state = IDLE;
    else begin
        case (current_state)
            IDLE : next_state = (in_valid)? INPUT: IDLE;
            INPUT: next_state = (op_reg != 2'b10)? LOAD: READ;
            LOAD : next_state = (rvalid_m_inf)? READ : LOAD;
            READ  : next_state = (rlast_m_inf)? WRITE : READ;
            WRITE: next_state = (wlast_m_inf)? IDLE : WRITE; 
            default: next_state = IDLE;
        endcase
    end
end
//================================================================
//  OUTPUT
//================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        busy <= 0;
    else if(current_state == INPUT) 
        busy <= 1;
    else if(wlast_m_inf) 
        busy <= 0;
end

//================================================================
//  AXI4 interface
//================================================================
always @(posedge clk or negedge rst_n)begin
	if(!rst_n) rd_valid <= 0;
	else if(next_state == LOAD && current_state == INPUT) rd_valid <= 1;
    else if(next_state == READ && current_state != READ) rd_valid <= 1;
    else rd_valid <= 0;
end

always @(posedge clk or negedge rst_n)begin
	if(!rst_n) wr_valid <= 0;
    else if(next_state == WRITE && current_state != WRITE) wr_valid <= 1;
    else wr_valid <= 0;
end

always @(*)begin
	if(!rst_n) wr_ready = 0;
    else if(current_state == WRITE)begin
        if(op_reg[1])begin
            if(addr_control == 0 && wready_m_inf)
                wr_ready = 0;
            else if(addr_control == 2)
                wr_ready = 0;
            else    
                wr_ready = 1;
        end
        else begin
            wr_ready = 1;
        end
    end 
    else wr_ready = 0;
end

always @(*) begin
    if(current_state == WRITE)begin
        if(op_reg[1])begin
            if(addr_control==257) 
                fin_flag = 1;
            else
                fin_flag = 0;
        end
        else begin
            if(addr_control==271) 
                fin_flag = 1;
            else
                fin_flag = 0;
        end
    end
    else begin
         fin_flag = 0;
    end
end

always @(*) begin
    if(op_reg[1])begin
        wr_data = {hist_ans[15], hist_ans[14], hist_ans[13], hist_ans[12],
                   hist_ans[11], hist_ans[10], hist_ans[ 9], hist_ans[ 8],
                   hist_ans[ 7], hist_ans[ 6], hist_ans[ 5], hist_ans[ 4],
                   hist_ans[ 3], hist_ans[ 2], hist_ans[ 1], hist_ans[ 0]};
    end
    else begin
        wr_data = {answer[15], answer[14], answer[13], answer[12],
                   answer[11], answer[10], answer[ 9], answer[ 8],
                   answer[ 7], answer[ 6], answer[ 5], answer[ 4],
                   answer[ 3], answer[ 2], answer[ 1], answer[ 0]};
    end
end

AXI4_READ AXI4_INF_R(
    .clk(clk),
    .rst_n(rst_n),
// AXI4 IO
// axi read address channel 
    .araddr_m_inf(araddr_m_inf),
    .arvalid_m_inf(arvalid_m_inf),
    .arready_m_inf(arready_m_inf),
    .arlen_m_inf(arlen_m_inf),
// axi read data channel     
    .rdata_m_inf(rdata_m_inf),
    .rlast_m_inf(rlast_m_inf),
    .rvalid_m_inf(rvalid_m_inf),
    .rready_m_inf(rready_m_inf),
// other
    .rd_valid(rd_valid),
    .rd_pic_addr(pic_no_reg),
    .rd_se_addr(se_no_reg),
    .rd_se_pic(rd_se_pic)
    // .rd_data(rd_data)
);

AXI4_WRITE AXI4_INF_W(
    .clk(clk),
    .rst_n(rst_n),
// AXI4 IO
// axi write address channel 
    .awaddr_m_inf(awaddr_m_inf),
    .awvalid_m_inf(awvalid_m_inf),
    .awready_m_inf(awready_m_inf),
// axi write data channel 
    .wdata_m_inf(wdata_m_inf),
    .wlast_m_inf(wlast_m_inf),
    .wvalid_m_inf(wvalid_m_inf),
    .wready_m_inf(wready_m_inf),
// axi write response channel 
    // .bresp_m_inf(bresp_m_inf),
    .bvalid_m_inf(bvalid_m_inf),
    .bready_m_inf(bready_m_inf), 
// other
    .wr_valid(wr_valid),
    .wr_addr(pic_no_reg), // 4 bit
    .wr_data(wr_data),
    .wr_ready(wr_ready),
    .wr_last(fin_flag)
);

endmodule


//################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//  AXI4_READ module
//
// rd_se_pic = 0 for reading se  (len=0)
// rd_se_pic = 1 for reading pic (len=255)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//################################################################

module AXI4_READ(
    // CHIP IO
    clk,
    rst_n,
// AXI4 IO
// axi read address channel 
    araddr_m_inf,
    arvalid_m_inf,
    arready_m_inf,
    arlen_m_inf,
// axi read data channel     
    rdata_m_inf,
    rlast_m_inf,
    rvalid_m_inf,
    rready_m_inf,
// other
    rd_valid,
    rd_pic_addr,
    rd_se_addr,
    rd_se_pic
    // rd_data
);

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 128;
// global signals 
input   clk, rst_n;
// axi read address channel 
output reg                   arvalid_m_inf;
input  wire                  arready_m_inf;
output wire [7:0]              arlen_m_inf;
output reg  [ADDR_WIDTH-1:0]  araddr_m_inf;
// axi read data channel 
input  wire [DATA_WIDTH-1:0]  rdata_m_inf;
input  wire                   rlast_m_inf;
input  wire                  rvalid_m_inf;
output reg                   rready_m_inf;
// other
input wire [3:0] rd_pic_addr;
input wire [5:0]  rd_se_addr; 
input wire rd_valid;
input wire rd_se_pic;

//  address (10000~2ffff) 32'h
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) araddr_m_inf <= 0;
    else if(rd_valid && rd_se_pic) araddr_m_inf <= {16'h0004, rd_pic_addr, 12'h0000}; //pic
    else if(rd_valid && !rd_se_pic) araddr_m_inf <= {20'h00030, 2'b0, rd_se_addr, 4'h0};  //se
end

assign arlen_m_inf = (!rd_se_pic)? 0 :255;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)                   arvalid_m_inf <= 0;
    else if(rd_valid)            arvalid_m_inf <= 1;
    else if(arready_m_inf)       arvalid_m_inf <= 0;
end
// assign rready_m_inf = 1;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)                   rready_m_inf <= 0;
    else if(arready_m_inf)       rready_m_inf <= 1;
    else if(rlast_m_inf)         rready_m_inf <= 0;
end

endmodule

//################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//  AXI4_WRITE module
//  
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//################################################################

module AXI4_WRITE(
    // CHIP IO
    clk,
    rst_n,
// AXI4 IO
// axi write address channel 
    awaddr_m_inf,
    awvalid_m_inf,
    awready_m_inf,
// axi write data channel 
    wdata_m_inf,
    wlast_m_inf,
    wvalid_m_inf,
    wready_m_inf,
// axi write response channel 
    // bresp_m_inf,
    bvalid_m_inf,
    bready_m_inf, 
// other
    wr_valid,
    wr_addr, 
    wr_data,
    wr_ready,
    wr_last
);

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 128;
// global signals 
input   clk, rst_n;
// axi read address channel 
output reg                   awvalid_m_inf;
input  wire                  awready_m_inf;
output reg  [ADDR_WIDTH-1:0]  awaddr_m_inf;
// axi read data channel 
output reg  [DATA_WIDTH-1:0]   wdata_m_inf;
output reg                     wlast_m_inf;
output reg                    wvalid_m_inf;
input  wire                   wready_m_inf;
// axi write response channel 
// input  wire                    bresp_m_inf;
input  wire                   bvalid_m_inf;
output reg                    bready_m_inf;
// other
input wire        wr_valid;
input wire [3:0]   wr_addr;
input wire [127:0] wr_data;
input wire        wr_ready;
input wire         wr_last;

//  address (10000~2ffff) 32'h
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) awaddr_m_inf <= 0;
    else if(wr_valid) awaddr_m_inf <= {16'h0004, wr_addr, 12'h0000};
    // else awaddr_m_inf <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) awvalid_m_inf <= 0;
    else if(wr_valid) awvalid_m_inf <= 1;
    else if(awready_m_inf) awvalid_m_inf <= 0;
    // else awvalid_m_inf <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) wvalid_m_inf <= 0;
    else if(wr_ready) wvalid_m_inf <= 1;
    else if(wready_m_inf) wvalid_m_inf <= 0; 
end

always @(*) begin
    wdata_m_inf = wr_data;
    // if(wr_ready) wdata_m_inf = wr_data;
    // else wdata_m_inf = 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) wlast_m_inf <= 0;
    else if(wr_last) wlast_m_inf <= 1;
    else wlast_m_inf <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) bready_m_inf <= 0;
    else if(awready_m_inf) bready_m_inf <= 1;
    else if(bvalid_m_inf) bready_m_inf <= 0;
end
endmodule

// evince /RAID2/EDA/synopsys/synthesis/cur/dw/doc/manuals/dwbb_userguide.pdf &