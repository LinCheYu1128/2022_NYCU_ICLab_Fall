module BP(
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

input             clk, rst_n;
input             in_valid;
input       [2:0] guy;
input       [1:0] in0, in1, in2, in3, in4, in5, in6, in7;
output reg        out_valid;
output reg  [1:0] out;

//==============================================//
//             Parameter and Integer            //
//==============================================//

reg [1:0]  current_state, next_state;
parameter IDLE = 2'd0 ;
parameter MAP  = 2'd1 ;
parameter EXE  = 2'd2 ;
parameter OUT  = 2'd3 ;

integer   i ,j ;

//==============================================//
//             reg/wire declaration             //
//==============================================//
reg [5:0] counter;

reg [2:0] start_point;

reg [5:0] space_distance     [1:31];
reg [4:0] obstacle_info_list [0:31];
reg [4:0] obstacle_info;

reg [1:0] direction;
//==============================================//
//             Combinational Block              //
//==============================================//

always @(*) begin
  if(in0 == 2'b01 || in0 == 2'b10)      obstacle_info = {in0, 3'd0};
  else if(in1 == 2'b01 || in1 == 2'b10) obstacle_info = {in1, 3'd1};
  else if(in2 == 2'b01 || in2 == 2'b10) obstacle_info = {in2, 3'd2};
  else if(in3 == 2'b01 || in3 == 2'b10) obstacle_info = {in3, 3'd3};
  else if(in4 == 2'b01 || in4 == 2'b10) obstacle_info = {in4, 3'd4};
  else if(in5 == 2'b01 || in5 == 2'b10) obstacle_info = {in5, 3'd5};
  else if(in6 == 2'b01 || in6 == 2'b10) obstacle_info = {in6, 3'd6};
  else if(in7 == 2'b01 || in7 == 2'b10) obstacle_info = {in7, 3'd7};
  else                                  obstacle_info = 0;
end

always @(*) begin
  if(obstacle_info_list[0][2:0] > obstacle_info_list[1][2:0]) direction = 2'b10;
  else if(obstacle_info_list[0][2:0] < obstacle_info_list[1][2:0]) direction = 2'b01;
  else direction = 2'b00;
end

//==============================================//
//               Sequential Block               //
//==============================================//
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) start_point <= 0;
  else if(current_state == IDLE && in_valid) start_point <= guy;
  else start_point <= start_point;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n) counter <= 0;
  else if(current_state == IDLE && in_valid) counter <= counter + 1;
  else if(in_valid && obstacle_info != 0) counter <= counter + 1;
  else if(next_state == IDLE) counter <= 0;
  else counter <= counter;
end

genvar k;
generate
  for(k = 2; k < 32; k = k + 1)begin
    always@(posedge clk or negedge rst_n)begin
      if(!rst_n)begin
        space_distance[k] <= 0;
      end
      else if(k == counter && in_valid)begin
        space_distance[k] <= space_distance[k] + 1;
      end
      else if(next_state == OUT && k != 31 && space_distance[1]==1) begin
        space_distance[k] <= space_distance[k+1];
      end
    end
  end
  for(k = 1; k < 32; k = k + 1)begin
    always@(posedge clk or negedge rst_n)begin
      if(!rst_n)begin
        obstacle_info_list[k] <= 0;
      end
      else if(k == counter && in_valid)begin
        obstacle_info_list[k] <= (obstacle_info!=0)? obstacle_info: obstacle_info_list[k];
      end
      else if(next_state == OUT && k != 31 && space_distance[1]==1)begin
        obstacle_info_list[k] <= obstacle_info_list[k+1];
      end
    end
  end
endgenerate

always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
    space_distance[1] <= 0;
  end
  else if(counter==1 && in_valid)begin
    space_distance[1] <= space_distance[1] + 1;
  end
  else if(next_state == OUT)begin
    if(space_distance[1]==1)begin
      space_distance[1] <= space_distance[2];
    end
    else begin
      space_distance[1] <= space_distance[1] - 1;
    end
  end
end

always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
    obstacle_info_list[0] <= 0;
  end
  else if(current_state == IDLE && in_valid)begin
    obstacle_info_list[0] <= {2'b00, guy};
  end
  else if(next_state == OUT)begin
    if(space_distance[1]==1)begin
      obstacle_info_list[0] <= obstacle_info_list[1];
    end
    else if(direction==1)begin
      obstacle_info_list[0] <= {obstacle_info_list[0][4:3], obstacle_info_list[0][2:0] + 1};
    end
    else if(direction==2)begin
      obstacle_info_list[0] <= {obstacle_info_list[0][4:3], obstacle_info_list[0][2:0] - 1};
    end
    else obstacle_info_list[0] <= obstacle_info_list[0];
  end
end


//==============================================//
//                FSM Block                     //
//==============================================//

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        current_state <= IDLE; /* initial state */
    else
        current_state <= next_state;
end

always@(*)begin
    if(!rst_n)
        next_state = IDLE ;
    else begin
        case(current_state)
            IDLE:
                next_state = (!in_valid)? IDLE : MAP ;
            MAP:
                next_state = (!in_valid)? OUT : MAP ;
            // EXE :
            //     next_state = OUT;
            OUT :
                next_state = (space_distance[1]==0)? IDLE : OUT ;
            default :
                next_state = IDLE ;
        endcase
    end
end

//==============================================//
//                Output Block                  //
//==============================================//

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        out_valid <= 0; /* remember to reset */
    else if(next_state == OUT)
        out_valid <= 1;
    else
        out_valid <= 0;
end


reg [3:0] debug_count;

always @(posedge clk or negedge rst_n) begin
  if(!rst_n) debug_count <= 0;
  else if(next_state == OUT)begin
    debug_count <= debug_count + 1;
  end
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        out <= 0; /* remember to reset */
    else if(next_state == OUT)begin
      if(space_distance[1]==1)begin
        if(obstacle_info_list[1][4:3] == 2'b01) out <= 3;
        else out <= direction;
      end
      else begin
        out <= direction;
      end 
      // ========================================
      //               Test SPEC 8
      // ========================================
      // if      (debug_count == 0) out <= 2;
      // else if (debug_count == 1) out <= 2;
      // else if (debug_count == 2) out <= 3;
      // else if (debug_count == 3) out <= 1;
      // else if (debug_count == 4) out <= 0;
      // else if (debug_count == 5) out <= 0;
      // else if (debug_count == 6) out <= 3;
      // else if (debug_count == 7) out <= 0;
      // else if (debug_count == 8) out <= 0;
      // else if (debug_count == 9) out <= 3;
      // else if (debug_count == 10) out <= 3;
      // else out <= 0;
    end
    else 
        out <= 0;
end

endmodule



if(!obs_dist)begin
  if(obs_dist_abs>0) begin
    move <= 2'b10;
    obs_dist_abs <= obs_dist_abs - 1;
  end
  else begin
     move <= 2'b00;
  end
end
else begin
  if(obs_dist_abs>0) begin
    move <= 2'b01;
    obs_dist_abs <= obs_dist_abs - 1;
  end
  else begin
     move <= 2'b00;
  end
end