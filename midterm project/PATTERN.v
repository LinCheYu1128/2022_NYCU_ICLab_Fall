`ifdef RTL
`define CYCLE_TIME 20
`endif
`ifdef GATE
`define CYCLE_TIME 20
`endif

`include "../00_TESTBED/MEM_MAP_define.v"
`include "../00_TESTBED/pseudo_DRAM.v"

module PATTERN #(parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32)(
    // CHIP IO       
    clk,	
    rst_n,	
    in_valid,	
    op,	
    pic_no,	  
    se_no,	  
    busy,

    // AXI4 IO
    awid_s_inf,
    awaddr_s_inf,
    awsize_s_inf,
    awburst_s_inf,
    awlen_s_inf,
    awvalid_s_inf,
    awready_s_inf,
                        
    wdata_s_inf,
    wlast_s_inf,
    wvalid_s_inf,
    wready_s_inf,
                        
    bid_s_inf,
    bresp_s_inf,
    bvalid_s_inf,
    bready_s_inf,
                    
    arid_s_inf,
    araddr_s_inf,
    arlen_s_inf,
    arsize_s_inf,
    arburst_s_inf,
    arvalid_s_inf,
                    
    arready_s_inf, 
    rid_s_inf,
    rdata_s_inf,
    rresp_s_inf,
    rlast_s_inf,
    rvalid_s_inf,
    rready_s_inf 
);
// ===============================================================
//                      Input / Output 
// ===============================================================

// << CHIP io port with system >>
output reg              clk, rst_n;
output reg              in_valid;
output reg [3:0]        pic_no;
output reg [5:0]        se_no;    
output reg [1:0]        op;
input                   busy;   
// << AXI Interface wire connecttion for pseudo DRAM read/write >>
// (1)     axi write address channel 
//         src master
input wire [ID_WIDTH-1:0]      awid_s_inf; //[3:0]
input wire [ADDR_WIDTH-1:0]  awaddr_s_inf; //[31:0]
input wire [2:0]             awsize_s_inf;
input wire [1:0]            awburst_s_inf;
input wire [7:0]              awlen_s_inf;
input wire                  awvalid_s_inf;
//         src slave
output wire                 awready_s_inf;
// -----------------------------

// (2)    axi write data channel 
//         src master
input wire [DATA_WIDTH-1:0]   wdata_s_inf; //[127:0]
input wire                    wlast_s_inf;
input wire                   wvalid_s_inf;
//         src slave
output wire                  wready_s_inf;

// (3)    axi write response channel 
//         src slave
output wire  [ID_WIDTH-1:0]     bid_s_inf;
output wire  [1:0]            bresp_s_inf;
output wire                  bvalid_s_inf;
//         src master 
input wire                   bready_s_inf;
// -----------------------------

// (4)    axi read address channel 
//         src master
input wire [ID_WIDTH-1:0]      arid_s_inf;
input wire [ADDR_WIDTH-1:0]  araddr_s_inf;
input wire [7:0]              arlen_s_inf;
input wire [2:0]             arsize_s_inf;
input wire [1:0]            arburst_s_inf;
input wire                  arvalid_s_inf;
//         src slave
output wire                 arready_s_inf;
// -----------------------------

// (5)    axi read data channel 
//         src slave
output wire [ID_WIDTH-1:0]      rid_s_inf;
output wire [DATA_WIDTH-1:0]  rdata_s_inf;
output wire [1:0]             rresp_s_inf;
output wire                   rlast_s_inf;
output wire                  rvalid_s_inf;
//         src master
input wire                   rready_s_inf;


// -------------------------//
//     DRAM Connection      //
//--------------------------//

pseudo_DRAM u_DRAM(
    .clk(clk),
    .rst_n(rst_n),
    // axi write address channel
    .   awid_s_inf(   awid_s_inf),
    . awaddr_s_inf( awaddr_s_inf),
    . awsize_s_inf( awsize_s_inf),
    .awburst_s_inf(awburst_s_inf),
    .  awlen_s_inf(  awlen_s_inf),
    .awvalid_s_inf(awvalid_s_inf),
    .awready_s_inf(awready_s_inf),
    // axi write data channel
    .  wdata_s_inf(  wdata_s_inf),
    .  wlast_s_inf(  wlast_s_inf),
    . wvalid_s_inf( wvalid_s_inf),
    . wready_s_inf( wready_s_inf),
    // axi write response channel
    .    bid_s_inf(    bid_s_inf),
    .  bresp_s_inf(  bresp_s_inf),
    . bvalid_s_inf( bvalid_s_inf),
    . bready_s_inf( bready_s_inf),
    // axi read address channel
    .   arid_s_inf(   arid_s_inf),
    . araddr_s_inf( araddr_s_inf),
    .  arlen_s_inf(  arlen_s_inf),
    . arsize_s_inf( arsize_s_inf),
    .arburst_s_inf(arburst_s_inf),
    .arvalid_s_inf(arvalid_s_inf),
    .arready_s_inf(arready_s_inf), 
    // axi read data channel 
    .    rid_s_inf(    rid_s_inf),
    .  rdata_s_inf(  rdata_s_inf),
    .  rresp_s_inf(  rresp_s_inf),
    .  rlast_s_inf(  rlast_s_inf),
    . rvalid_s_inf( rvalid_s_inf),
    . rready_s_inf( rready_s_inf) 
);

//================================================================
//    clock
//================================================================
always	#(`CYCLE_TIME/2.0) clk = ~clk;
initial	clk = 0;
//================================================================
//   parameters & integers
//================================================================
integer in_read, out_read;
integer i, j, l, a, gap;
integer curr_cycle, cycles, total_cycles;
integer patcount, PATNUM;

integer op_reg, se_no_reg, pic_no_reg;

integer addr;
//================================================================
//    wires % registers
//================================================================
reg [7:0] golden_out[0:4095];
reg [7:0] DRAM_r[0:4*64*1024-1];
//================================================================
//    initial
//================================================================

initial begin
    // $readmemh("../00_TESTBED/DRAM/dram.dat", u_DRAM.DRAM_r);
    in_read  = $fopen("../00_TESTBED/op.txt", "r");
    a = $fscanf(in_read, "%d\n", PATNUM);

    rst_n    = 'b1;
    in_valid = 'bx;
    se_no    = 'bx;
    pic_no   = 'bx;
    op       = 'bx;

    force clk = 0 ;
    reset_task;
    total_cycles = 0;

    for(patcount = 0;patcount < PATNUM; patcount = patcount+1)begin
        input_task;
        wait_busy_task;
        check_answer_task;
        $display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32mexecution cycle : %3d\033[m",patcount ,cycles);
    end

    repeat(10) @(negedge clk);
    YOU_PASS_task;
    
end

//================================================================
// TASK
//================================================================
task input_task; begin
	
	gap = $urandom_range(3,10);
	repeat(gap) @(negedge clk);
    a = $fscanf(in_read, "%d\n", op_reg);
    a = $fscanf(in_read, "%d\n", se_no_reg);
    a = $fscanf(in_read, "%d\n", pic_no_reg);

	op       = op_reg; 
    se_no    = se_no_reg;
    pic_no   = pic_no_reg;
    in_valid = 'b1;

    @(negedge clk);
    se_no    = 'bx;
    pic_no   = 'bx;
    op       = 'bx;
    in_valid = 'b0;

end endtask
reg [7:0] temp;
task check_answer_task; begin
    for(i=0; i<4096; i=i+1)begin
        a = $fscanf(in_read, "%h", golden_out[i]);

        addr = {16'h0004, pic_no_reg[3:0] , i[11:0]};
        
        temp = u_DRAM.DRAM_r[addr];
        if(u_DRAM.DRAM_r[addr] !== golden_out[i])begin
            $display ("----------------------------------------------------------------------------------------------------------------------");
			$display ("                                                Your distance is Wrong!             						             ");
            $display ("                                                  Wrong answer at : %h       	                                ",addr);
			$display ("                                                  Your Answer is : %d       	                     ",u_DRAM.DRAM_r[addr]);
			$display ("                                               Correct Answer is : %03d           		              ", golden_out[i]);
			$display ("----------------------------------------------------------------------------------------------------------------------");
			repeat(1)  @(negedge clk);
			$finish;
        end
    end
end endtask

task wait_busy_task ; begin
	cycles = 0 ;
    while( busy===0 )begin
        cycles = cycles + 1 ;
        if (cycles==100000) begin
            cycle_fail;
		end
        @(negedge clk);
    end
	while( busy!==0 ) begin
		cycles = cycles + 1 ;
		if (cycles==100000) begin
            cycle_fail;
		end
		@(negedge clk);
	end
	total_cycles = total_cycles + cycles ;
end endtask

task reset_task ;  begin
	#(20); rst_n = 0;
    in_valid = 0;
	#(20);
	if(busy!==0)begin
		reset_fail;
	end
	#(20);rst_n = 1;
	#(6); release clk;
end endtask

task cycle_fail ; begin
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $display ("                                             Exceed maximun cycle!!!                                                  ");
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $finish;
end endtask

task reset_fail ; begin
	$display ("----------------------------------------------------------------------------------------------------------------------");
	$display ("                                                  Oops! Reset is Wrong                						             ");
	$display ("----------------------------------------------------------------------------------------------------------------------");
	$finish;
end endtask

task YOU_PASS_task; begin                                                                                                                                                                                            
    $display("\033[1;32m                                          .:---:.                                                                         ");                                  
    $display("\033[1;32m                                       .*aa&&&&&aa#=                                                                      ");                                  
    $display("\033[1;32m                                    .#a#*+***###&aaaa&&&&&##**+=-::.                                                      ");                                  
    $display("\033[1;32m                                 .=*&aa&####***++++++++++++++****##&&&&##+=-:                                             ");                                  
    $display("\033[1;32m                              :*&aa&#*+++++++++++++++++++++++++++++++++++*##&&&#+=:.                                      ");                                  
    $display("\033[1;32m                           :+aa&*+=====================+++++++++++++++++++++++++*##&&#+-.                                 ");                                  
    $display("\033[1;32m                         =&a#*================================+++++++++++++++++++++++*#&a&*=.                             ");                                  
    $display("\033[1;32m                       +aa*===============+&&+==================++==+++++++++++++++++++++*#&aa*-     .----.               ");                                  
    $display("\033[1;32m                     =a&*==================**==================+aa+=====+++++++++++++++++++++#&aa#=+aa####&&&*-           ");                                  
    $display("\033[1;32m                   .&a*======================================================+++++++++++++++++++*&aa*++++++++*&a*.        ");                                  
    $display("\033[1;32m                  :a&+===========================================================++++++++++++++++++*++++*###**++#a*       ");                                  
    $display("\033[1;32m                 :a&==============++**#######*#aa*****#####**++=====================+++++++++++++++++++&a&&&&a&#++&&.     ");                                  
    $display("\033[1;32m                 &a=========+*#&#*+-:.       \033[1;37m=*::#:        .:-=#a&##*+\033[1;32m=================+++++++++++++++*a&&&&&&&a&++&&");                                  
    $display("\033[1;32m                =a+=====+*#*=:\033[1;37m***=         -*-   \033[1;37m.*+         =*=.:#:.\033[1;32m-=+*#*+==============+++++++++++++&&&&&&&&&&+++a*");                                  
    $display("\033[1;32m                #a===*##=.   \033[1;37m-##  #+     :*= \033[1;32m::    \033[1;37m=#.    .+*:    \033[1;32m.\033[1;37m#:     \033[1;32m.-+*#*+============+++++++++++#&a&&&a&*+++&a");                                  
    $display("\033[1;32m                #a*&*+#*\033[1;37m=   .&. \033[1;32m#+:\033[1;37m:*+.-*=  \033[1;32m*&*    \033[1;37m :*= -*+.     \033[1;32m.:.\033[1;37m#-         \033[1;32m.=+#*+===========+++++++++++*#**+++++&&");                                  
    $display("\033[1;32m                =a&. #- \033[1;37m-*-:#.\033[1;32m.#+-*  \033[1;37m.=: \033[1;32m .#-+*      \033[1;37m -+-        \033[1;32m-a. \033[1;37m*+        \033[1;32m:++=:a*#*+=========+++++++++++++++++#a-");                                  
    $display("\033[1;32m                 &a::#   \033[1;37m -=. \033[1;32m*+*&+      .#: =*..               :+a=  \033[1;37m=*    -++-.-  -* \033[1;32m:=*#+========+++++++++++++#a#.");                                  
    $display("\033[1;32m                 :aa#:       *&#:&:      *=  :&&#...           ::##+   \033[1;37m:*+++:        *=   \033[1;32m:=*#+========+++++++++++&a:  ");                                  
    $display("\033[1;32m                .#&:.       =a- .a-+*##**#*-  #*=#+++==--:::::::-a-*     .-=---+*=*  \033[1;37m#&:     \033[1;32m.=#*========++++++++++&&  ");                                  
    $display("\033[1;32m               =a#.        :&. :*a*-. .           ..::--=++++++*#+-*     .--=+&&#&&:++\033[1;37m.&.      \033[1;32m.*a*========++++++++*a+ ");                                  
    $display("\033[1;32m             -&&- :*      .&:.##-:=*******=.                      .=+++++++++*+  .-*a+.\033[1;37m:#:-=*++-:+*\033[1;32m#*=======++++++++&a ");                                  
    $display("\033[1;32m            #a&===&:      ++ &-.*#-:.....:+&-                            .-*##**+=:  =&+.-:.&    \033[1;37m:& \033[1;32m-#+=======++++++*a-");                                  
    $display("\033[1;32m             .:-#a+      .&.   &+..........:&-                         :*#+-:...:-+&-  +*   a.    \033[1;37m#- \033[1;32m &+=======++++++a+");                                  
    $display("\033[1;32m                a&.      ++   -&          ..&=                        :a+..........:a:      a.    \033[1;37m:#  \033[1;32m:&========+++++a*");                                  
    $display("\033[1;32m               =a-      .&.   -&           +#.              .         =&         ...*+      a:     \033[1;37m#: \033[1;32m.&*========++++a*");                                  
    $display("\033[1;32m               &&       =#     +#:      :+&=       +:==.  -##*        :a.           &-      a:     \033[1;37m:+=-\033[1;32m+#=========+++a*");                                  
    $display("\033[1;32m              .a+      .#-   \033[1;31m...-+#****#*=.        \033[1;32m.+#=#+**--&         -&+:       -#+      :&:.        :a=========++*a=");                                  
    $display("\033[1;32m              =a:     .:a. \033[1;31m......:..........        \033[1;32m-*:------&       \033[1;31m....-*#******+:     \033[1;32m##+*:.  .=:   .a==========+#a:");                                  
    $display("\033[1;32m              *a.     :-&  \033[1;31m....:=:...:-:.....       \033[1;32m=*-------&      \033[1;31m......::.....:...   \033[1;32m-#:#*-:=*+*+    a==========+&& ");                                  
    $display("\033[1;32m           --:*&     .:+*  \033[1;31m...:=:...:=:......       \033[1;32m=*------+*      \033[1;31m.....--:...:-:.... \033[1;32m.#&#####&*=+=   .a==========+a= ");                                  
    $display("\033[1;32m          .a&aa&     ::*=   \033[1;31m...:....::......        \033[1;32m-*------#=      \033[1;31m....::....--......\033[1;32m+&*+++++==+#a:   :&==========&&  ");                                  
    $display("\033[1;32m           a*=&a+-.  ::*=..   \033[1;31m....:........         \033[1;32m:#:-----a.       \033[1;31m................\033[1;32m##++++=======&-   =#=========+a-  ");                                  
    $display("\033[1;32m           aa*+++*##-::*&*::    \033[1;37m.:++:.           .   \033[1;32m&-----+*           \033[1;31m.:-=::....  \033[1;32m+#+++=========**   **=========a*   ");                                  
    $display("\033[1;32m       .=*aa+====+++##\033[1;37m+#:-#:: .:=#.:#+:.      .:+*-..\033[1;32m=*----&- \033[1;37m+++-:.     :+*-+*=..  \033[1;32m.a+++==========**   &+========#a.  ");                                  
    $display("\033[1;32m      .aa--a=======++\033[1;37m*&.  *+:::#=    =#-:.   .-#- =*=.\033[1;32m+*=+#+\033[1;37m-# .=*+-:. :=#    -**:\033[1;32m.#*++===========**  :&========#a:    ");                                  
    $display("\033[1;32m       .#a+a========*\033[1;37m&.    &-=#:      .*+:..:=#.    -#=:\033[1;32m---\033[1;37m&:     .+*=:-&       .+\033[1;32m#&++============#-  **=======#a-     ");                                  
    $display("\033[1;32m         :#a*======+a#*+=-:\033[1;37m=&*          -#-:*+        -#=:&:         -*&-..:-\033[1;32m=++*#a*++===========+&--.a=======#a:");                                  
    $display("\033[1;32m           +a+======#&*==++*#***++==-::..\033[1;37m:##=           +&=..\033[1;32m::--=+++**##**++====+&++============&+&.+#=====+&&. ");                                  
    $display("\033[1;32m            =a*=======#&*===========+++****#***********#*****++++================&*+============#*#+:&=====#a=     ");                                  
    $display("\033[1;32m             :&&+=======#&#+====================================================+&++===========*&&###+===*a*.      ");                                  
    $display("\033[1;32m              .aa#========*#&#+=================================================&*+===========+a&**a*==#a*.        ");                                  
    $display("\033[1;32m               &&*a#+=======+*#&#*+============================================*&+===========+a#+++\033[1;31m&#&aa-");                                  
    $display("\033[1;32m               -aa&*a&+=========+*#&##*+=======================================a+===========+&*+=\033[1;31m+a&&&&aa+");                                  
    $display("\033[1;32m                =+. +a*##+===========+***=====================================*#============&*+===\033[1;31ma&&&&&a-");                                  
    $display("\033[1;32m                     *a-#aa#*=+*=================---\033[1;33m:::::::::::::\033[1;32m---=======================*&+====\033[1;31m#a&&&aa#&&.            ");                                  
    $display("\033[1;32m                      *aa#.=#aa*============--\033[1;33m::::::::::::::::::::::::::\033[1;32m-==================++======\033[1;31m&&&aaa&&a*            ");                                  
    $display("\033[1;32m                       -*.   =a*=========-\033[1;33m::::::::::::::::::::::::::::::::::\033[1;32m-======================\033[1;31m+a&&&&&&a& .-+:       ");                                  
    $display("\033[1;32m                             -a+=======-\033[1;33m::::::::::::::::::::::::::::::::::::::\033[1;32m-=====================\033[1;31m+&&&&&&aa&aaaa:  :.  ");                                  
    $display("\033[1;32m                             .a#=====-\033[1;33m:::::::::::::::::::::::::::::::::::::::::::\033[1;32m=====================\033[1;31m#a&&&aa&&&&a&+&aa= ");                                  
    $display("\033[1;32m                              #&====\033[1;33m:::::::::::::::::::::::::::::::::::::::::::::::\033[1;32m-===================\033[1;31m+&&&&&&&&&aa&&&aa:");                                  
    $display("\033[1;32m                              :a*==\033[1;33m::::::::::::::::::::::::::::::::::::::::::::::::::\033[1;32m====================\033[1;31m+##&&&&&&&&&&##=");                                  
    $display("\033[1;34m      ===============================================================================================================");
    $display("\033[1;34m                                                  Congratulations!                						             ");
    $display("\033[1;34m                                           You have passed all patterns!          						             ");
    $display("\033[1;34m                                           Your execution cycles = %5d cycles   					   ", total_cycles);
    $display("\033[1;34m                                           Your clock period = %.1f ns        					        ", `CYCLE_TIME);
    $display("\033[1;34m                                           Your total latency = %.1f ns                    ", total_cycles*`CYCLE_TIME);
    $display("\033[1;34m      ===============================================================================================================");  
    $display("\033[1;0m"); 
    $finish;

end endtask

endmodule

