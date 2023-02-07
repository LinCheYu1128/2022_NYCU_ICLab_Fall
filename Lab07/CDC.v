`include "synchronizer.v"
`include "syn_XOR.v"
module CDC(
	//Input Port
	clk1,
    clk2,
    clk3,
	rst_n,
	in_valid1,
	in_valid2,
	user1,
	user2,

    //Output Port
    out_valid1,
    out_valid2,
	equal,
	exceed,
	winner
); 
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input 		clk1, clk2, clk3, rst_n;
input 		in_valid1, in_valid2;
input [3:0]	user1, user2;

output reg	out_valid1, out_valid2;
output reg	equal, exceed, winner;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
genvar  idx;
//----clk1----
wire             in_valid;
wire       [3:0] user_in, card;
reg        [5:0] total_card;
reg signed [5:0] player1_to_21, player2_to_21;
reg        [4:0] card_to_21;
reg        [4:0] card_amount_table     [1:10];
wire       [5:0] exceed_amount_table   [1: 9];
reg        [6:0] equal_num; 
reg        [6:0] equal_prob;
reg        [6:0] exceed_num;
reg        [6:0] exceed_prob;
reg        [1:0] winner_clk1;
reg        [4:0] round_counter;
reg              out_valid1_clk1, out_valid2_clk1;
//----clk2----
wire             out_valid1_clk2, out_valid2_clk2;
//----clk3----
wire        out_valid1_clk3, out_valid2_clk3;
wire   [6:0] equal_clk3, exceed_clk3;
reg    [6:0] equal_buffer, exceed_buffer;
wire   [1:0] winner_clk3;
reg    [1:0] winner_buffer;
reg     [2:0] out_counter;
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
//----clk1----

//----clk2----

//----clk3----
reg [1:0] clk3_cstate, clk3_nstate;
parameter CLK3_IDLE = 0;
parameter CLK3_OUT  = 1;
parameter CLK3_WIN  = 2;
//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
//============================================
//   clk1 domain
//============================================
// cal winner
always @(posedge clk1 or negedge rst_n) begin
    if(!rst_n)
        winner_clk1 <= 0;
	else if(player1_to_21 < 0 && player2_to_21 < 0)
		winner_clk1 <= 0;
	else if(player1_to_21 < 0)
		winner_clk1 <= 3;
	else if(player2_to_21 < 0)
		winner_clk1 <= 2;
	else if(player1_to_21 < player2_to_21)
		winner_clk1 <= 2;
	else if(player1_to_21 > player2_to_21)
		winner_clk1 <= 3;
	else
		winner_clk1 <= 0;
end

// cal prob
always @(*) begin
    case (card_to_21)
        1 : equal_num = card_amount_table[1 ];
        2 : equal_num = card_amount_table[2 ];
        3 : equal_num = card_amount_table[3 ];
        4 : equal_num = card_amount_table[4 ];
        5 : equal_num = card_amount_table[5 ];
        6 : equal_num = card_amount_table[6 ];
        7 : equal_num = card_amount_table[7 ];
        8 : equal_num = card_amount_table[8 ];
        9 : equal_num = card_amount_table[9 ];
        10: equal_num = card_amount_table[10];
        default: equal_num = 0;
    endcase
end

always @(*) begin
	case (card_to_21)
        1 : exceed_num = exceed_amount_table[1 ];
        2 : exceed_num = exceed_amount_table[2 ];
        3 : exceed_num = exceed_amount_table[3 ];
        4 : exceed_num = exceed_amount_table[4 ];
        5 : exceed_num = exceed_amount_table[5 ];
        6 : exceed_num = exceed_amount_table[6 ];
        7 : exceed_num = exceed_amount_table[7 ];
        8 : exceed_num = exceed_amount_table[8 ];
        9 : exceed_num = exceed_amount_table[9 ];
        default: exceed_num = 0;
    endcase
end

always@(posedge clk1 or negedge rst_n) begin
    if(!rst_n)begin
        equal_prob <= 0;
    end
    else if(round_counter == 3 || round_counter == 4 || round_counter == 8 || round_counter == 9)
	    equal_prob <= equal_num*100/total_card;
end

always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n)begin
        exceed_prob <= 0;
    end
    else if(round_counter == 3 || round_counter == 4 || round_counter == 8 || round_counter == 9)begin
       if(card_to_21 == 0)begin
            exceed_prob <= 100;
        end
        else begin
            exceed_prob <= exceed_num*100/total_card;
        end 
    end
end

// card to 21 control
always @(*) begin
	if(round_counter == 3 || round_counter == 4)begin
		card_to_21 = (player1_to_21 < 0)? 0: player1_to_21[4:0];
	end
	else if(round_counter == 8 || round_counter == 9)begin
		card_to_21 = (player2_to_21 < 0)? 0: player2_to_21[4:0];
	end
	else begin
		card_to_21 = 0;
	end
end

always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n) begin
		player1_to_21 <= 21;
	end 
	else if(in_valid && round_counter == 0)begin
		player1_to_21 <= 21 - card;
	end
	else if(in_valid && round_counter < 5)begin
		player1_to_21 <= player1_to_21 - card;
	end
end

always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n) begin
		player2_to_21 <= 21;
	end 
	else if(in_valid && round_counter == 5)begin
		player2_to_21 <= 21 - card;
	end
	else if(in_valid && round_counter > 5)begin
		player2_to_21 <= player2_to_21 - card;
	end
end

// card amount
assign in_valid = (in_valid1||in_valid2);
assign user_in = (in_valid1)? user1: ((in_valid2)?user2 : 0);
assign card = (user_in>10)? 1 : user_in;

assign exceed_amount_table[9] = card_amount_table[10];
assign exceed_amount_table[8] = exceed_amount_table[9] + card_amount_table[9];
assign exceed_amount_table[7] = exceed_amount_table[8] + card_amount_table[8];
assign exceed_amount_table[6] = exceed_amount_table[7] + card_amount_table[7];
assign exceed_amount_table[5] = exceed_amount_table[6] + card_amount_table[6];
assign exceed_amount_table[4] = exceed_amount_table[5] + card_amount_table[5];
assign exceed_amount_table[3] = exceed_amount_table[4] + card_amount_table[4];
assign exceed_amount_table[2] = exceed_amount_table[3] + card_amount_table[3];
assign exceed_amount_table[1] = exceed_amount_table[2] + card_amount_table[2];

always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n) begin
		total_card <= 52;
	end else if(in_valid)begin
		total_card <= (total_card == 2)? 51: total_card - 1;
	end
end

generate
	for(idx=1; idx<=10; idx=idx+1)begin
		always@(posedge clk1 or negedge rst_n) begin
			if(!rst_n)begin
				if(idx==1)
					card_amount_table[idx] <= 16;
				else
					card_amount_table[idx] <= 4;
			end
			else if(in_valid && total_card == 2)begin
				if(card == idx)begin
					if(idx==1)
						card_amount_table[idx] <= 15;
					else
						card_amount_table[idx] <= 3;
				end
				else begin
					if(idx==1)
						card_amount_table[idx] <= 16;
					else
						card_amount_table[idx] <= 4;
				end	
			end
			else if(in_valid)begin
				if(card == idx)
					card_amount_table[idx] <= card_amount_table[idx] - 1;
			end
		end
	end
endgenerate

always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n) begin
		round_counter <= 0;
	end 
    else if(in_valid)begin
		round_counter <= (round_counter==9)? 0: round_counter + 1;
	end
end

// out valid at clk1
always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n)
        out_valid1_clk1 <= 0;
    else if(round_counter == 2 || round_counter == 3 || round_counter == 7 || round_counter == 8)begin
		out_valid1_clk1 <= 1;
	end
    else begin
        out_valid1_clk1 <= 0;
    end
end

always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n)
        out_valid2_clk1 <= 0;
    else  if(round_counter == 9)begin
		out_valid2_clk1 <= 1;
	end
    else begin
        out_valid2_clk1 <= 0;
    end
end
// always@(*) begin
// 	if(round_counter == 2 || round_counter == 3 || round_counter == 7 || round_counter == 8)begin
// 		out_valid1_clk1 = 1;
// 	end
//     else begin
//         out_valid1_clk1 = 0;
//     end
// end

// always@(*) begin
// 	if(round_counter == 9)begin
// 		out_valid2_clk1 = 1;
// 	end
//     else begin
//         out_valid2_clk1 = 0;
//     end
// end
//============================================
//   clk3 domain
//============================================
always@(posedge clk3 or negedge rst_n)begin
	if(!rst_n)begin
		equal_buffer  <= 0;
		exceed_buffer <= 0;
	end
    else if(out_valid1_clk3)begin
        equal_buffer  <= equal_prob;
		exceed_buffer <= exceed_prob;
        // equal_buffer  <= equal_clk3;
		// exceed_buffer <= exceed_clk3;
	end
	else begin
		equal_buffer  <= equal_buffer << 1;
		exceed_buffer <= exceed_buffer << 1;
	end
end

always@(posedge clk3 or negedge rst_n)begin
    if(!rst_n)begin
		winner_buffer <= 0;
	end
    else if(out_valid2_clk3)begin
        winner_buffer <= winner_clk1;
        // winner_buffer <= winner_clk3;
	end
	else begin
		winner_buffer <= winner_buffer << 1;
	end
end


//  Current State Block
always@(posedge clk3 or negedge rst_n)begin
    if(!rst_n)begin
        clk3_cstate <= CLK3_IDLE;
    end
    else begin
        clk3_cstate <= clk3_nstate;
    end
end

//  Next State Block
always@(*)begin
	if(!rst_n)
        clk3_nstate = CLK3_IDLE ;
    else begin
		case (clk3_cstate)
			CLK3_IDLE:begin
				if(out_valid1_clk3) clk3_nstate = CLK3_OUT;
				else if(out_valid2_clk3) clk3_nstate = CLK3_WIN;
				else clk3_nstate = CLK3_IDLE;
			end 
			CLK3_OUT: clk3_nstate = (out_counter == 6)? CLK3_IDLE: CLK3_OUT;
			CLK3_WIN: begin
				if(winner_buffer == 0 || out_counter == 1) clk3_nstate = CLK3_IDLE;
				else clk3_nstate = CLK3_WIN;
			end
			default: clk3_nstate = CLK3_IDLE ;
		endcase
	end
end

always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		out_counter <= 0;
	end 
	else if(clk3_cstate == CLK3_OUT) begin
		out_counter <= out_counter + 1;
	end
	else if(clk3_cstate == CLK3_WIN) begin
		out_counter <= out_counter + 1;
	end
	else begin
		out_counter <= 0;
	end
end

always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		out_valid1 <= 0;
	end 
	else if(clk3_cstate == CLK3_OUT) begin
		out_valid1 <= 1;
	end
	else begin
		out_valid1 <= 0;
	end 
end

always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		out_valid2 <= 0;
	end 
	else if(clk3_cstate == CLK3_WIN) begin
		out_valid2 <= 1;
	end
	else begin
		out_valid2 <= 0;
	end 
end

always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		equal  <= 0;
		exceed <= 0;
	end 
	else if(clk3_cstate == CLK3_OUT) begin
		equal  <= equal_buffer[6];
		exceed <= exceed_buffer[6];
	end
	else begin
		equal  <= 0;
		exceed <= 0;
	end
end

always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		winner <= 0;
	end 
	else if(clk3_cstate == CLK3_WIN) begin
		winner  <= winner_buffer[1];
	end
	else begin
		winner <= 0;
	end
end

//---------------------------------------------------------------------
//   syn_XOR
//---------------------------------------------------------------------
// synchronizer u_syn_outvalid1(.D(out_valid1_clk1),.Q(out_valid1_clk3),.clk(clk3),.rst_n(rst_n));
// synchronizer u_syn_outvalid2(.D(out_valid2_clk1),.Q(out_valid2_clk3),.clk(clk3),.rst_n(rst_n));

syn_XOR u_syn_outvalid1(.IN(out_valid1_clk1),.OUT(out_valid1_clk3),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));
syn_XOR u_syn_outvalid2(.IN(out_valid2_clk1),.OUT(out_valid2_clk3),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));

// syn_XOR u_syn_invalid1(.IN((in_valid1||in_valid2)),.OUT(in_valid_clk2),.TX_CLK(clk1),.RX_CLK(clk2),.RST_N(rst_n));
// syn_XOR u_syn_invalid2(.IN(in_valid2),.OUT(in_valid2_clk2),.TX_CLK(clk1),.RX_CLK(clk2),.RST_N(rst_n));

// generate
//     for(idx=0 ; idx<7 ; idx=idx+1)begin
//         synchronizer u_syn_equal(.D(equal_prob[idx]),.Q(equal_clk3[idx]),.clk(clk3),.rst_n(rst_n));
//         synchronizer u_syn_exceed(.D(exceed_prob[idx]),.Q(exceed_clk3[idx]),.clk(clk3),.rst_n(rst_n));
// 		// syn_XOR u_syn_equal  (.IN( equal_prob[idx]),.OUT( equal_clk3[idx]),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));
// 		// syn_XOR u_syn_exceed (.IN(exceed_prob[idx]),.OUT(exceed_clk3[idx]),.TX_CLK(clk2),.RX_CLK(clk3),.RST_N(rst_n));
// 	end
// 	for(idx=0 ; idx<2 ; idx=idx+1)begin
//         synchronizer u_syn_winner(.D(winner_clk1[idx]),.Q(winner_clk3[idx]),.clk(clk3),.rst_n(rst_n));
// 		// syn_XOR u_syn_winner (.IN( winner_clk1[idx]),.OUT(winner_clk3[idx]),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));
// 	end
// endgenerate

endmodule