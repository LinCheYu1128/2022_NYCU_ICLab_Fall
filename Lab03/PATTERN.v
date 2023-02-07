
`define CYCLE_TIME 10.0

module PATTERN(
  clk,
  rst_n,
  in_valid,
  guy,
  in0,
  in1,
  in2,
  in3,
  in4,
  in5,
  in6,
  in7,
  
  out_valid,
  out
);

output reg       clk, rst_n;
output reg       in_valid;
output reg [2:0] guy;
output reg [1:0] in0, in1, in2, in3, in4, in5, in6, in7;
input            out_valid;
input      [1:0] out;

integer total_cycles, cycles;
integer patcount, PATNUM;
reg [1:0] maze [0:63][0:7];

integer SEED;
integer cycle_num;
integer i, j, gap;
integer obstacle, old_obstacle, type, start, space;
integer pos_x, pos_y;
integer ans_count;
integer now_state, next_state;

integer JUM_CHECK;
//================================================================
// clock
//================================================================
always	#(`CYCLE_TIME/2.0) clk = ~clk;
initial	clk = 0;

//================================================================
// PATTERN
//================================================================
initial begin
	rst_n     = 1'b1;
  guy       = 3'bx;
	in0       = 2'bx;
  in1       = 2'bx;
  in2       = 2'bx;
  in3       = 2'bx;
  in4       = 2'bx;
  in5       = 2'bx;
  in6       = 2'bx;
  in7       = 2'bx;
	in_valid  = 1'b0;

	total_cycles = 0;
	force clk = 0;
	reset_task;
	
	SEED = 255;
  PATNUM = 300;
	for (patcount = 0; patcount < PATNUM; patcount = patcount + 1) begin
    generate_map_task;
		input_data;
		wait_outvalid_task;
    check_ans_task;
		$display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32m Cycles: %3d\033[m", patcount ,cycles);
	end
	YOU_PASS_task;
	$finish;
end 

always @(negedge clk) begin
  if(out_valid === 0 && out !== 0)begin
    $display ("************************************************************************************************************************");
    $display ("*                                                SPEC 4 IS FAIL!                                                       *");
    $display ("*                                  The out should be reset when out_valid is low                                       *");
    $display ("************************************************************************************************************************");
    $finish;
  end
end

task check_ans_task;begin
  ans_count = 0;
  pos_x = start;
  pos_y = 0;
  JUM_CHECK = 0; 
  // 0 for no fail; 
  // 1 for jump from high to low(1 cycle); 2 for jump from high to low(2 cycle); 
  // 3 for jump to same high(floor 0 to floor 1); 
  // 4 for jump to same high(floor 1 to floor 2); 5 for jump to same high(floor 2 to floor 1)
  while(out_valid === 1 )begin
    if(ans_count > 62)begin
      $display ("************************************************************************************************************************");
			$display ("*                                                SPEC 7 IS FAIL!                                                       *");
			$display ("*                                      The out_valid is more than 63 cycles                                            *");
			$display ("************************************************************************************************************************");
			$finish;
    end

    if((JUM_CHECK == 3 || JUM_CHECK == 4) && out !== 0)begin
      $display ("************************************************************************************************************************");
			$display ("*                                                SPEC 8-3 IS FAIL!                                                     *");
      $display ("*                                     Jump to same high, out should be 0 for 1 cycle                                   *");
			$display ("************************************************************************************************************************");
			$finish;
    end
    if((JUM_CHECK == 1 || JUM_CHECK == 2) && out !== 0)begin
      $display ("************************************************************************************************************************");
			$display ("*                                                SPEC 8-2 IS FAIL!                                                     *");
      $display ("*                                Jump from high to low, out should be 0 for 2 cycles                                   *");
			$display ("************************************************************************************************************************");
			$finish;
    end

    if(JUM_CHECK == 1 && out === 0) JUM_CHECK = 2;
    else if(JUM_CHECK == 2 && out === 0) JUM_CHECK = 0;
    else if(JUM_CHECK == 3 && out === 0) JUM_CHECK = 0;
    else if(JUM_CHECK == 4 && out === 0) JUM_CHECK = 5;
    else if(JUM_CHECK == 4 && out === 0) JUM_CHECK = 0;

    if(out === 3)begin
      if(maze[pos_y][pos_x] == 0 && maze[pos_y + 1][pos_x] == 0 && maze[pos_y + 2][pos_x] == 0) JUM_CHECK = 3;  // 0 1 0
      else if(maze[pos_y][pos_x] == 1 && maze[pos_y + 1][pos_x] == 0 && maze[pos_y + 2][pos_x] == 1) JUM_CHECK = 4;// 1 2 1
      else if(maze[pos_y][pos_x] == 1 && maze[pos_y + 2][pos_x] == 0) JUM_CHECK = 1; // 1 2 1 0
      else if(maze[pos_y][pos_x] == 0 && maze[pos_y + 2][pos_x] == 1) begin // 0 1 0(crash)
        $display ("************************************************************************************************************************");
        $display ("*                                                SPEC 8-1 IS FAIL!                                                     *");
        $display ("*                                               crash the low obstacle                                                 *");
        $display ("************************************************************************************************************************"); 
        $finish;
      end 
      else if(maze[pos_y][pos_x] == 0 && maze[pos_y + 1][pos_x] == 2) begin // 0 1(crash)
        $display ("************************************************************************************************************************");
        $display ("*                                                SPEC 8-1 IS FAIL!                                                     *");
        $display ("*                                              crash the high obstacle                                                 *");
        $display ("************************************************************************************************************************"); 
        $finish;
      end 
      else if(maze[pos_y][pos_x] == 1 && maze[pos_y + 3][pos_x] == 1) begin // 1 2 1 0(crash)
        $display ("************************************************************************************************************************");
        $display ("*                                                SPEC 8-1 IS FAIL!                                                     *");
        $display ("*                                               crash the low obstacle                                                 *");
        $display ("************************************************************************************************************************"); 
        $finish;
      end
    end

    if(out === 1)begin // right
      pos_x = pos_x + 1;
    end 
    else if(out === 2)begin
      pos_x = pos_x - 1;
    end 

    pos_y = pos_y + 1;
    
    next_state = maze[pos_y][pos_x];
    
    if(pos_x > 7 || pos_x < 0)begin
      // SPEC 8-1 fail
      $display ("************************************************************************************************************************");
			$display ("*                                                SPEC 8-1 IS FAIL!                                                     *");
      $display ("*                                                 out of platform                                                      *");
			$display ("************************************************************************************************************************");
			$finish;
    end
    else if(next_state == 'd3)begin
      // SPEC 8-1 fail 
      $display ("************************************************************************************************************************");
			$display ("*                                                SPEC 8-1 IS FAIL!                                                     *");
      $display ("*                                               crash the obstacle                                                     *");
			$display ("************************************************************************************************************************"); 
      $finish;
    end
    else if(next_state == 'd1 && out !== 3 && JUM_CHECK == 0)begin
      $display ("************************************************************************************************************************");
			$display ("*                                                SPEC 8-1 IS FAIL!                                                     *");
      $display ("*                                               crash the obstacle                                                     *");
			$display ("************************************************************************************************************************"); 
      $finish;
    end

    ans_count = ans_count + 1;
    @(negedge clk);
  end
  if(ans_count < 62)begin
    $display ("************************************************************************************************************************");
    $display ("*                                                SPEC 7 IS FAIL!                                                       *");
    $display ("*                                      The out_valid is less than 63 cycles                                            *");
    $display ("************************************************************************************************************************");
    $finish;
  end  

end endtask

task generate_map_task;begin

  for(j = 0; j < 64; j=j+1)begin
    for(i = 0; i < 8; i=i+1)begin
        maze[j][i] = 0;
		end
  end

  cycle_num = 0; 
  start = {$random(SEED)}%8;
  old_obstacle = start;

  while (cycle_num < 64) begin

    obstacle = {$random(SEED)}%8;
    type = 1 + {$random(SEED)}%2; // 1 for low obstacle; 2 for high obstacle

    if(type == 1)begin
      if(obstacle > old_obstacle)      space = (obstacle - old_obstacle + 1) + {$random(SEED)}%3;
      else if(obstacle < old_obstacle) space = (old_obstacle - obstacle + 1) + {$random(SEED)}%3;
      else  space = 2 + {$random(SEED)}%3;
    end
    else begin
      if(obstacle > (old_obstacle + 1))      space = (obstacle - old_obstacle) + {$random(SEED)}%3;
      else if((obstacle + 1) < old_obstacle) space = (old_obstacle - obstacle) + {$random(SEED)}%3;
      else  space = 2 + {$random(SEED)}%3;
    end
                               

    if(space + cycle_num< 64)begin
      for(i = 0; i < 8; i=i+1)begin
        if(obstacle == i)begin
          maze[space+cycle_num][i] = type;
        end
        else maze[space+cycle_num][i] = 2'b11;
      end
    end

    cycle_num = space + cycle_num;
    old_obstacle = obstacle;
  end
  // ==========================
  //         test spec
  // ==========================
  // start = 1;
  // maze[1][0] = 3; maze[2][0] = 0; maze[3][0] = 3; maze[4][0] = 0;
  // maze[1][1] = 1; maze[2][1] = 0; maze[3][1] = 1; maze[4][1] = 0;
  // maze[1][2] = 3; maze[2][2] = 0; maze[3][2] = 3; maze[4][2] = 0;
  // maze[1][3] = 3; maze[2][3] = 0; maze[3][3] = 3; maze[4][3] = 0;
  // maze[1][4] = 3; maze[2][4] = 0; maze[3][4] = 3; maze[4][4] = 0;
  // maze[1][5] = 3; maze[2][5] = 0; maze[3][5] = 3; maze[4][5] = 0;
  // maze[1][6] = 3; maze[2][6] = 0; maze[3][6] = 3; maze[4][6] = 0;
  // maze[1][7] = 3; maze[2][7] = 0; maze[3][7] = 3; maze[4][7] = 0;
  // =========================
  $display("start = %d", start); 
  for(i = 0; i < 64; i = i + 1)begin
    $display("%d %d %d %d %d %d %d %d", maze[i][0], maze[i][1], maze[i][2], maze[i][3], maze[i][4], maze[i][5], maze[i][6], maze[i][7]);
  end
end endtask

task input_data; begin
	gap = $urandom_range(2,4);
	repeat(gap) @(negedge clk);
  for(i = 0; i < 64; i = i + 1)begin
    in_valid = 1'b1;
    if(i == 0) guy = start;
    else guy = 3'bx;
    in0 = maze[i][0];
    in1 = maze[i][1];
    in2 = maze[i][2];
    in3 = maze[i][3];
    in4 = maze[i][4];
    in5 = maze[i][5];
    in6 = maze[i][6];
    in7 = maze[i][7];
    if(out_valid == 1) begin
      $display ("***********************************************************************************************************************");
      $display ("*                                                  SPEC 5 IS FAIL!                                                    *");
      $display ("*                                   out_valid should not be high when in_valid is high                             *");
      $display ("***********************************************************************************************************************");
      $finish;
    end
    @(negedge clk);
  end
  in0      = 2'bx;
  in1      = 2'bx;
  in2      = 2'bx;
  in3      = 2'bx;
  in4      = 2'bx;
  in5      = 2'bx;
  in6      = 2'bx;
  in7      = 2'bx;
	in_valid = 1'b0;
end endtask

task wait_outvalid_task ; begin
	cycles = 0 ;
	while( out_valid!==1 ) begin
		cycles = cycles + 1 ;
		if (cycles==3000) begin
			$display ("************************************************************************************************************************");
			$display ("*                                                SPEC 6 IS FAIL!                                                       *");
			$display ("*                                The execution latency are over  3000 cycles                                           *");
			$display ("************************************************************************************************************************");
			$finish;
		end
		@(negedge clk);
	end
	total_cycles = total_cycles + cycles ;
end endtask

task reset_task ; begin
	#(10); rst_n = 0;
	#(10);
	if((out_valid !== 0) || (out !== 0)) begin
		$display ("**************************************************************************************************************************");
		$display ("*                                                     SPEC 3 IS FAIL!                                                    *");
		$display ("*                                        Output signal should be 0 after initial RESET                                   *");
		$display ("**************************************************************************************************************************");
	  $finish ;
	end
	#(10); rst_n = 1 ;
	#(3.0); release clk;
end endtask

task YOU_PASS_task; begin                                                                                                                                                                                                                             
    $display("\033[1;35m           ==========================================================================================================");
    $display ("\033[1;35m                                                  Congratulations!                						             ");
    $display ("\033[1;35m                                           You have passed all patterns!          						             ");
    $display ("\033[1;35m                                           Your execution cycles = %5d cycles   					   ", total_cycles);
    $display ("\033[1;35m                                           Your clock period = %.1f ns        					        ", `CYCLE_TIME);
    $display ("\033[1;35m                                           Your total latency = %.1f ns         		   ", total_cycles*`CYCLE_TIME);
    $display("\033[1;35m           ==========================================================================================================");  
    $display("\033[1;0m"); 
    $finish;
end endtask



endmodule