`timescale 1ns/1ps

`include "PATTERN.v"
`include "TT.v"
	  		  	
module TESTBED;

wire         clk, rst_n, in_valid;
wire  [3:0]  source;
wire  [3:0]  destination;

wire         out_valid;
wire  [3:0]  cost;


// initial begin
//   `ifdef RTL
//     $fsdbDumpfile("TT.fsdb");
// 	  $fsdbDumpvars(0,"+mda");
//     $fsdbDumpvars();
//   `endif
// end

TT u_TT(
    .clk            (   clk          ),
    .rst_n          (   rst_n        ),
    .in_valid       (   in_valid     ),
    .source         (   source       ),
    .destination    (   destination  ),

    .out_valid      (   out_valid    ),
    .cost           (   cost         )
   );
	
PATTERN u_PATTERN(
    .clk            (   clk          ),
    .rst_n          (   rst_n        ),
    .in_valid       (   in_valid     ),
    .source         (   source       ),
    .destination    (   destination  ),

    .out_valid      (   out_valid    ),
    .cost           (   cost         )
   );
  
 
endmodule
