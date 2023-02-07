`ifdef RTL
	`timescale 1ns/1ps
	`include "CDC.v"
	`define CYCLE_TIME_clk1 36.7
	`define CYCLE_TIME_clk2 6.8
	`define CYCLE_TIME_clk3 2.6
`endif
`ifdef GATE
	`timescale 1ns/1ps
	`include "CDC_SYN.v"
	`define CYCLE_TIME_clk1 36.7
	`define CYCLE_TIME_clk2 6.8
	`define CYCLE_TIME_clk3 2.6
`endif
module PATTERN(
	//Output Port
	clk1,
    clk2,
    clk3,
	rst_n,
	in_valid1,
	in_valid2,
	user1,
	user2,

    //Input Port
    out_valid1,
    out_valid2,
	equal,
	exceed,
	winner
); 
//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
output reg			clk1, clk2, clk3, rst_n;
output reg			in_valid1, in_valid2;
output reg [3:0]	user1, user2;

input 				out_valid1, out_valid2;
input 				equal, exceed, winner;
//================================================================
//  parameters & integer
//================================================================
integer input_file, output_file;
integer gap;
integer a, b, c, d;
integer i, j, k, l;
integer cycles, total_cycles;
integer epoch_count, round_count, bit_count, win_bit_count, win_epoch_count;
//================================================================
//  reg & wire
//================================================================
reg [6:0] equal_temp  ;
reg [6:0] exceed_temp ;
reg [1:0] winner_temp ;
reg [6:0] golden_equal  [0:499][0:3];
reg [6:0] golden_exceed [0:499][0:3];
reg [1:0] golden_winner [0:499];
//================================================================
//  clock
//================================================================
initial clk1 = 0;
initial clk2 = 0;
initial clk3 = 0;
always #(`CYCLE_TIME_clk1/2.0) clk1 = ~clk1;
always #(`CYCLE_TIME_clk2/2.0) clk2 = ~clk2;
always #(`CYCLE_TIME_clk3/2.0) clk3 = ~clk3;
//================================================================
//  initial
//================================================================
initial begin
	input_file  = $fopen("../00_TESTBED/input.txt","r");
  	output_file = $fopen("../00_TESTBED/output.txt","r");
	rst_n     = 'b1;
	in_valid1 = 'b0;
	in_valid2 = 'b0;
	user1     = 'bx;
	user2     = 'bx;

	force clk1 = 0;
	force clk2 = 0;
	force clk3 = 0;
	reset_task;
	load_output_file;
	@(negedge clk1);
	for(i=0; i<500; i=i+1)begin
		for(k=0; k<5; k=k+1)begin
			in_valid1 = 'b1;
			in_valid2 = 'b0;
			a = $fscanf(input_file,"%d",user1);
			user2     = 'bx;
			@(negedge clk1);
		end
		for(k=0; k<5; k=k+1)begin
			in_valid1 = 'b0;
			in_valid2 = 'b1;
			user1     = 'bx;
			a = $fscanf(input_file,"%d",user2);
			@(negedge clk1);
		end
	end
	in_valid1 = 'b0;
	in_valid2 = 'b0;
	user1     = 'bx;
	user2     = 'bx;
	while (1) begin
		if(win_epoch_count == 500)
			YOU_PASS_task;
		@(negedge clk1);
	end
	
end

always @(negedge clk3)begin
	if(bit_count==6)begin
		if(equal_temp !== golden_equal[epoch_count][round_count])
			equal_fail_task;
		if(exceed_temp !== golden_exceed[epoch_count][round_count])
			exceed_fail_task;
	end
end

always @(*) begin
	if(out_valid1)begin
		equal_temp[6-bit_count] = equal;
		exceed_temp[6-bit_count] = exceed;
	end
end

always@(posedge clk3 or negedge rst_n)begin
	if(!rst_n)begin
		epoch_count <= 0;
		bit_count   <= 0;
		round_count <= 0;
	end
	else if(out_valid1)begin
		bit_count <= (bit_count==6)? 0: bit_count + 1;
		round_count <= (round_count==3 && bit_count==6)? 0: ((bit_count==6)? round_count + 1: round_count);
		epoch_count <= (round_count==3 && bit_count==6)? epoch_count+1 : epoch_count;
	end	
	else
		bit_count <= 0;
end

always @(negedge clk3)begin
	if(out_valid2)begin
		if(golden_winner[win_epoch_count]==0)begin
			if(winner !== 0)begin
				winner_fail_task;
			end
			else
				$display("\033[0;34mPASS epochs %3d\033[1;0m", win_epoch_count);
		end
		else if(win_bit_count == 1)begin
			if(winner_temp !== golden_winner[win_epoch_count])
				winner_fail_task;
			else
				$display("\033[0;34mPASS epochs %3d\033[1;0m", win_epoch_count);
		end
	end
	
end

always @(*) begin
	if(out_valid2)begin
		winner_temp[1-win_bit_count] = winner;
	end
end

always@(posedge clk3 or negedge rst_n)begin
	if(!rst_n)begin
		win_bit_count <= 0;
		win_epoch_count <= 0;
	end
	else if(out_valid2)begin
		if(golden_winner[win_epoch_count]==0)begin
			win_epoch_count <= win_epoch_count + 1;
		end
		else begin
			win_bit_count <= (win_bit_count==1)? 0 : win_bit_count + 1;
			win_epoch_count <= (win_bit_count==1)? win_epoch_count + 1 : win_epoch_count;
		end
	end	
	else
		win_bit_count <= 0;
end

always@(negedge clk3 or negedge rst_n)begin
	if(!rst_n)begin
		cycles <= 0;
	end
	else begin
		cycles <= cycles + 1;
		if(cycles >= 100000)
			cycle_fail;
	end	
end

//================================================================
//  task
//================================================================
task load_output_file ; begin
	for(l=0; l<500; l=l+1)begin
		for(j=0; j<4; j=j+1)begin
			a = $fscanf(output_file,"%d", golden_equal[l][j]);
			a = $fscanf(output_file,"%d", golden_exceed[l][j]);
		end
		a = $fscanf(output_file,"%d", golden_winner[l]);
	end
end endtask

task winner_fail_task; begin
	if(golden_winner[win_epoch_count] == 0)begin
		$display ("----------------------------------------------------------------------------------------------------------------------");
		$display ("                                                    Answer wrong !                                                    ");
		$display ("                                                Winner should be 0  !             						             ");
		$display ("----------------------------------------------------------------------------------------------------------------------");
		repeat(1)  @(negedge clk3);
		$finish;
	end
	else begin
		$display ("----------------------------------------------------------------------------------------------------------------------");
		$display ("                                                    Answer wrong !                                                    ");
		$display ("                                                Winner should be %d !                 ", golden_winner[win_epoch_count]);
		$display ("                                                Your winner is %d !             		                    ", winner_temp);
		$display ("----------------------------------------------------------------------------------------------------------------------");
		repeat(1)  @(negedge clk3);
		$finish;
	end
end endtask

task equal_fail_task; begin
	$display ("----------------------------------------------------------------------------------------------------------------------");
	$display ("                                                    Answer wrong !                                                    ");
	$display ("                                                Equal should be %d !          ", golden_equal[epoch_count][round_count]);
	$display ("                                                Your equal is %d !             		                     ", equal_temp);
	$display ("----------------------------------------------------------------------------------------------------------------------");
	repeat(1)  @(negedge clk3);
	$finish;
end endtask

task exceed_fail_task; begin
	$display ("----------------------------------------------------------------------------------------------------------------------");
	$display ("                                                    Answer wrong !                                                    ");
	$display ("                                                Exceed should be %d !         ", golden_exceed[epoch_count][round_count]);
	$display ("                                                Your exceed is %d !             		                    ", exceed_temp);
	$display ("----------------------------------------------------------------------------------------------------------------------");
	repeat(1)  @(negedge clk3);
	$finish;
end endtask

task cycle_fail ; begin
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $display ("                                             Exceed maximun cycle!!!                                                  ");
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $finish;
end endtask

task reset_task ; begin
	#(10); rst_n = 0;
	#(30);
	if((out_valid1 !== 0) || (out_valid2 !== 0) || (equal !== 0) || (exceed !== 0) || (winner !== 0)) begin
		$display ("------------------------------------------------------------------------------------------------------------");
		$display ("                                                FAIL!                                                       ");
		$display ("                          Output signal should be 0 after initial RESET at %8t                              ",$time);
		$display ("------------------------------------------------------------------------------------------------------------");
		#(100);
	    $finish ;
	end
	#(10); rst_n = 1 ;
	#(3.0); release clk1; release clk2; release clk3;
end endtask


task YOU_PASS_task; begin                                                                                                                                                                                                                           
    $display("\033[1;34m      ===============================================================================================================");
	$display("\033[1;34m                                                      Congratulations!                						         ");
	$display("\033[1;34m                                               You have passed all patterns!          						         ");
	$display("\033[1;34m                                               Your execution cycles = %5d cycles   				         ", cycles);
	$display("\033[1;34m                                               Your clock period = %.1f ns        				   ", `CYCLE_TIME_clk3);
	$display("\033[1;34m                                               Your total latency = %.1f ns                 ", cycles*`CYCLE_TIME_clk3);
    $display("\033[1;34m      ===============================================================================================================");  
    $display("\033[1;0m"); 
    $finish;
end endtask

endmodule 