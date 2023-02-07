module HD(
	code_word1,
	code_word2,
	out_n
);
input  [6:0]code_word1, code_word2;
output reg signed[5:0] out_n;

wire temp1, temp2, temp3;
wire temp4, temp5, temp6;

reg code_word1_errorbit;
reg code_word2_errorbit;
reg signed [3:0] c1;
reg signed [3:0] c2;

wire signed [4:0] neg_c2 ;
wire signed [4:0] cc1;
wire signed [5:0] cc2;

// xor(temp1, code_word1[6], code_word1[3], code_word1[2], code_word1[1]);
// xor(temp2, code_word1[5], code_word1[3], code_word1[2], code_word1[0]);
// xor(temp3, code_word1[4], code_word1[3], code_word1[1], code_word1[0]);
// xor(temp4, code_word2[6], code_word2[3], code_word2[2], code_word2[1]);
// xor(temp5, code_word2[5], code_word2[3], code_word2[2], code_word2[0]);
// xor(temp6, code_word2[4], code_word2[3], code_word2[1], code_word2[0]);

wire a, b;
assign a = code_word1[3] ^ code_word1[2] ^ code_word1[1] ^code_word1[0];
assign b = code_word2[3] ^ code_word2[2] ^ code_word2[1] ^code_word2[0];

assign temp1 = code_word1[6] ^ code_word1[0] ^ a;
assign temp2 = code_word1[5] ^ code_word1[1] ^ a;
assign temp3 = code_word1[4] ^ code_word1[2] ^ a;
assign temp4 = code_word2[6] ^ code_word2[0] ^ b;
assign temp5 = code_word2[5] ^ code_word2[1] ^ b;
assign temp6 = code_word2[4] ^ code_word2[2] ^ b;

// assign temp1 = (code_word1[6] ^ code_word1[3]) ^ (code_word1[2] ^ code_word1[1]);
// assign temp2 = (code_word1[5] ^ code_word1[3]) ^ (code_word1[2] ^ code_word1[0]);
// assign temp3 = (code_word1[4] ^ code_word1[3]) ^ (code_word1[1] ^ code_word1[0]);
// assign temp4 = (code_word2[6] ^ code_word2[3]) ^ (code_word2[2] ^ code_word2[1]);
// assign temp5 = (code_word2[5] ^ code_word2[3]) ^ (code_word2[2] ^ code_word2[0]);
// assign temp6 = (code_word2[4] ^ code_word2[3]) ^ (code_word2[1] ^ code_word2[0]);

// wire and_1, and_2, xor_1, xor_2;
// assign and_1 = temp1 & temp2 & temp3;
// assign and_2 = temp4 & temp5 & temp6;
// assign xor_1 = temp1 ^ temp2 ^ temp3;
// assign xor_2 = temp4 ^ temp5 ^ temp6;

always @(*) begin
	// if(and_1)begin
	if(temp1 & temp2 & temp3)begin
		code_word1_errorbit = code_word1[3];
	// end else if (xor_1) begin
	end else if (temp1 ^ temp2 ^ temp3) begin
		if(temp1)begin
			code_word1_errorbit = code_word1[6];
		end else if (temp2)begin
			code_word1_errorbit = code_word1[5];
		end else begin
			code_word1_errorbit = code_word1[4];
		end
	end else if(!temp1)begin
		code_word1_errorbit = code_word1[0];
	end else if (!temp2) begin
		code_word1_errorbit = code_word1[1];
	end else begin
		code_word1_errorbit = code_word1[2];
	end
	// case ({temp1,temp2,temp3})
	// 	3'b011: begin
	// 		code_word1_errorbit = code_word1[0];
	// 	end
	// 	3'b101: begin
	// 		code_word1_errorbit = code_word1[1];
	// 	end
	// 	3'b110: begin
	// 		code_word1_errorbit = code_word1[2];
	// 	end
	// 	3'b111: begin
	// 		code_word1_errorbit = code_word1[3];
	// 	end
	// 	3'b001: begin
	// 		code_word1_errorbit = code_word1[4];
	// 	end
	// 	3'b010: begin
	// 		code_word1_errorbit = code_word1[5];
	// 	end
	// 	default: begin
	// 		code_word1_errorbit = code_word1[6];
	// 	end
	// endcase
end

always @(*) begin
	// if(and_1)begin
	if(temp1 & temp2 & temp3)begin
		c1 = {~code_word1[3],code_word1[2:0]};
	// end else if (xor_1) begin
	end else if (temp1 ^ temp2 ^ temp3) begin
		c1 = {code_word1[3:0]};
	end else if(!temp1)begin
		c1 = {code_word1[3:1],~code_word1[0]};
	end else if (!temp2) begin
		c1 = {code_word1[3:2],~code_word1[1],code_word1[0]};
	end else begin
		c1 = {code_word1[3],~code_word1[2],code_word1[1:0]};
	end
	// case ({temp1,temp2,temp3})
	// 	3'b011: begin
	// 		c1 = {code_word1[3:1],~code_word1[0]};
	// 	end
	// 	3'b101: begin
	// 		c1 = {code_word1[3:2],~code_word1[1],code_word1[0]};
	// 	end
	// 	3'b110: begin
	// 		c1 = {code_word1[3],~code_word1[2],code_word1[1:0]};
	// 	end
	// 	3'b111: begin
	// 		c1 = {~code_word1[3],code_word1[2:0]};
	// 	end
	// 	default:begin
	// 		c1 = {code_word1[3:0]};
	// 	end
	// endcase
end

always @(*) begin
	// if(and_2)begin
	if(temp4 & temp5 & temp6)begin
		code_word2_errorbit = code_word2[3];
	// end else if (xor_2) begin
	end else if (temp4 ^ temp5 ^ temp6) begin
		if(temp4)begin
			code_word2_errorbit = code_word2[6];
		end else if (temp5)begin
			code_word2_errorbit = code_word2[5];
		end else begin
			code_word2_errorbit = code_word2[4];
		end
	end else if(!temp4)begin
		code_word2_errorbit = code_word2[0];
	end else if (!temp5) begin
		code_word2_errorbit = code_word2[1];
	end else begin
		code_word2_errorbit = code_word2[2];
	end
	// case ({temp4,temp5,temp6})
	// 	3'b011: begin
	// 		code_word2_errorbit = code_word2[0];
	// 	end
	// 	3'b101: begin
	// 		code_word2_errorbit = code_word2[1];
	// 	end
	// 	3'b110: begin
	// 		code_word2_errorbit = code_word2[2];
	// 	end
	// 	3'b111: begin
	// 		code_word2_errorbit = code_word2[3];
	// 	end
	// 	3'b001: begin
	// 		code_word2_errorbit = code_word2[4];
	// 	end
	// 	3'b010: begin
	// 		code_word2_errorbit = code_word2[5];
	// 	end
	// 	default: begin
	// 		code_word2_errorbit = code_word2[6];
	// 	end
	// endcase
end

always @(*) begin
	// if(and_2)begin
	if(temp4 & temp5 & temp6)begin
		c2 = {~code_word2[3],code_word2[2:0]};
	// end else if (xor_2) begin
	end else if (temp4 ^ temp5 ^ temp6) begin
		c2 = {code_word2[3:0]};
	end else if(!temp4)begin
		c2 = {code_word2[3:1],~code_word2[0]};
	end else if (!temp5) begin
		c2 = {code_word2[3:2],~code_word2[1],code_word2[0]};
	end else begin
		c2 = {code_word2[3],~code_word2[2],code_word2[1:0]};
	end
	// case ({temp4,temp5,temp6})
	// 	3'b011: begin
	// 		c2 = {code_word2[3:1],~code_word2[0]};
	// 	end
	// 	3'b101: begin
	// 		c2 = {code_word2[3:2],~code_word2[1],code_word2[0]};
	// 	end
	// 	3'b110: begin
	// 		c2 = {code_word2[3],~code_word2[2],code_word2[1:0]};
	// 	end
	// 	3'b111: begin
	// 		c2 = {~code_word2[3],code_word2[2:0]};
	// 	end
	// 	default: begin
	// 		c2 = {code_word2[3:0]};
	// 	end
	// endcase
end

assign cc1 = (!code_word1_errorbit)? c1<<1: c1;
assign neg_c2 = (code_word1_errorbit^code_word2_errorbit)? -c2:c2;
assign cc2 = (code_word1_errorbit)? neg_c2<<1: neg_c2;


always @(*) begin
	out_n = cc1 + cc2;
	// if(code_word1_errorbit^code_word2_errorbit)begin
	// 	out_n = cc1 - cc2;
	// end	
	// else begin
	// 	out_n = cc1 + cc2;
	// end 	
end
endmodule

