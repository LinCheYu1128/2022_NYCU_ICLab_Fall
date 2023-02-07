`ifdef RTL
	`include "NN.v"  
	`define CYCLE_TIME 50.0
`endif
`ifdef GATE
	`include "NN_SYN.v"
	`define CYCLE_TIME 50.0
`endif

module PATTERN(
	// Output signals
	clk,
	rst_n,
	in_valid_u,
	in_valid_w,
	in_valid_v,
	in_valid_x,
	weight_u,
	weight_w,
	weight_v,
	data_x,
	// Input signals
	out_valid,
	out
);
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
	parameter inst_sig_width = 23;
	parameter inst_exp_width = 8;
	parameter inst_ieee_compliance = 0;

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
	output reg clk,rst_n,in_valid_u,in_valid_w,in_valid_v,in_valid_x;
	output reg [inst_sig_width + inst_exp_width: 0] weight_u,weight_w,weight_v,data_x;
	input	out_valid;
	input	[inst_sig_width + inst_exp_width: 0] out;
	
//================================================================
// parameters & integer
//================================================================
integer ans_count, cycles, total_cycles;
integer patcount, PATNUM;
integer in_read, out_read;
integer i, j, a, gap;


reg [inst_sig_width + inst_exp_width: 0] u_temp [0:8];
reg [inst_sig_width + inst_exp_width: 0] w_temp [0:8];
reg [inst_sig_width + inst_exp_width: 0] v_temp [0:8];
reg [inst_sig_width + inst_exp_width: 0] x_temp [0:8];
reg [inst_sig_width + inst_exp_width: 0] y_temp [0:8];
//================================================================
// clock
//================================================================
always	#(`CYCLE_TIME/2.0) clk = ~clk;
initial	clk = 0;

//================================================================
// PATTERN
//================================================================
initial begin
	in_read = $fopen("../00_TESTBED/input.txt", "r");
	out_read = $fopen("../00_TESTBED/output.txt", "r");
	a = $fscanf(in_read, "%d\n", PATNUM);

	rst_n      = 1'b1;
	in_valid_u = 1'b0;
	in_valid_w = 1'b0;
	in_valid_v = 1'b0;
	in_valid_x = 1'b0;
	weight_u   = 32'bx;
	weight_w   = 32'bx;
	weight_v   = 32'bx;
	data_x     = 32'bx;

	total_cycles = 0;
	reset_task;

	for(patcount = 0; patcount < PATNUM; patcount = patcount+1)begin
		load_data;
		wait_outvalid_task;
		check_ans_task;
		$display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32mexecution cycle : %3d\033[m",patcount ,cycles);
	end
	YOU_PASS_task;
end

wire [31:0] tmp_out;
wire ALessB;
wire ALargeB;
wire AEqualB;
wire unordered_inst;
wire [31:0] z0_inst,z1_inst;
wire[31:0] inst_b;
assign inst_b = 32'b00111010000000110001001001101111; // 0.0005

wire [31:0]pos_tmp_out;
assign pos_tmp_out = {1'b0,tmp_out[30:0]};
DW_fp_sub #(inst_sig_width, inst_exp_width, inst_ieee_compliance) S0 ( .a(out), .b(y_temp[ans_count]), .rnd(3'b000), .z(tmp_out), .status(status_inst) );
DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance) U1 ( .a(pos_tmp_out), .b(inst_b), .zctr(1'b0), .aeqb(AEqualB),.altb(ALessB), .agtb(ALargeB), .unordered(unordered_inst),.z0(z0_inst), .z1(z1_inst), .status0(status0_inst),.status1(status1_inst) );


task check_ans_task ;  begin
	ans_count = 0;
	for(i=0; i<9; i=i+1)begin
		a = $fscanf(out_read, "%b\n", y_temp[i]);
	end
	while (out_valid === 1) begin
		if(ans_count>9)begin
			$display ("----------------------------------------------------------------------------------------------------------------------");
			$display ("                                             The out_valid should be 9 cycles                                         ");
			$display ("----------------------------------------------------------------------------------------------------------------------");
			$finish;
		end
		else begin
			if(ALargeB)begin
				$display ("----------------------------------------------------------------------------------------------------------------------");
				$display ("                                                  Your Answer is Wrong!             						             ");
				$display ("                                                  Your Answer is : %32b       	                                 ",out);
				$display ("                                               Correct Answer is : %32b           			       ",y_temp[ans_count]);
				$display ("----------------------------------------------------------------------------------------------------------------------");
				$finish;
			end
			ans_count = ans_count+1;	
		end
		@(negedge clk);
	end
	if(ans_count!=9)begin
		$display ("----------------------------------------------------------------------------------------------------------------------");
		$display ("                                             The out_valid should be 9 cycles                                         ");
		$display ("----------------------------------------------------------------------------------------------------------------------");
		$finish;
	end
end endtask

task load_data ;  begin
	// $display ("start Pattern No.%1d", patcount);
	// random gap
	gap = $urandom_range(2,5);
	repeat(gap) @(negedge clk);
	
	// load input
	for(i=0; i<9; i=i+1)begin
		a = $fscanf(in_read, "%b\n", u_temp[i]);
	end
	for(i=0; i<9; i=i+1)begin
		a = $fscanf(in_read, "%b\n", w_temp[i]);
	end
	for(i=0; i<9; i=i+1)begin
		a = $fscanf(in_read, "%b\n", v_temp[i]);
	end
	for(i=0; i<9; i=i+1)begin
		a = $fscanf(in_read, "%b\n", x_temp[i]);
	end	

	// input task
	in_valid_u = 1'b1;
	in_valid_w = 1'b1;
	in_valid_v = 1'b1;
	in_valid_x = 1'b1;
	for(i=0; i<9; i=i+1)begin
		weight_u = u_temp[i];
		weight_w = w_temp[i];
		weight_v = v_temp[i];
		data_x   = x_temp[i];
		if(out_valid === 1) begin
			$display ("----------------------------------------------------------------------------------------------------------------------");
			$display ("                                    out_valid should not be high when in_valid is high                                ");
			$display ("----------------------------------------------------------------------------------------------------------------------");
			$finish;
    	end
		@(negedge clk);
	end
	in_valid_u = 1'b0;
	in_valid_w = 1'b0;
	in_valid_v = 1'b0;
	in_valid_x = 1'b0;
	weight_u = 32'bx;
	weight_w = 32'bx;
	weight_v = 32'bx;
	data_x   = 32'bx;
end endtask

task wait_outvalid_task ; begin
	cycles = 0 ;
	while( out_valid === 0 ) begin
		cycles = cycles + 1 ;
		if (cycles==100) begin 
			$display ("----------------------------------------------------------------------------------------------------------------------");
			$display ("                                             Exceed maximun cycle!!!                                                  ");
			$display ("----------------------------------------------------------------------------------------------------------------------");
			$finish;
		end
		@(negedge clk);
	end
	total_cycles = total_cycles + cycles ;
end endtask

task reset_task ;  begin
	force clk = 0;
	#(20); rst_n = 0;
	#(20);
	if((out_valid!==0) || (out!==0))begin
		reset_fail;
	end
	#(20);rst_n = 1;
	#(6); release clk;
end endtask

always @(negedge clk) begin
  if(out_valid === 0 && out !== 0)begin
    $display ("----------------------------------------------------------------------------------------------------------------------");
	$display ("                                          out should be 0 when out_valid is low         						         ");
	$display ("----------------------------------------------------------------------------------------------------------------------");
	$finish;
  end
end

task reset_fail ; begin
	$display ("----------------------------------------------------------------------------------------------------------------------");
	$display ("                                                  Oops! Reset is Wrong                						         ");
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