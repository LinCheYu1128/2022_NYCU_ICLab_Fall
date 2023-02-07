module NN(
           // Input signals
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
           // Output signals
           out_valid,
           out
       );

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 2;
parameter inst_arch_type = 0;

reg  [1:0]   current_state, next_state;
parameter IDLE   = 2'd0 ;
parameter INPUT  = 2'd1 ;
parameter CAL    = 2'd2 ;
parameter OUTPUT = 2'd3 ;
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input  clk, rst_n, in_valid_u, in_valid_w, in_valid_v, in_valid_x;
input  [inst_sig_width+inst_exp_width : 0] weight_u, weight_w, weight_v;
input  [inst_sig_width+inst_exp_width : 0] data_x;
output reg  out_valid;
output reg [inst_sig_width+inst_exp_width : 0] out;

//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
genvar i, j;

reg [3:0] counter;

reg  [inst_sig_width+inst_exp_width : 0]  U_matrix [8:0];
reg  [inst_sig_width+inst_exp_width : 0]  W_matrix [8:0];
reg  [inst_sig_width+inst_exp_width : 0]  V_matrix [8:0];
reg  [inst_sig_width+inst_exp_width : 0]  X_matrix [8:0];

reg  [inst_sig_width+inst_exp_width : 0]   H_matrix [2:0];
reg  [inst_sig_width+inst_exp_width : 0]  UX_matrix [2:0];
reg  [inst_sig_width+inst_exp_width : 0]  WH_matrix [2:0];
reg  [inst_sig_width+inst_exp_width : 0]   Y_matrix [2:1];
//---------------------------------------------------------------------
//   IP DECLARATION
//---------------------------------------------------------------------
reg  [inst_sig_width+inst_exp_width : 0]   MAT_A [8:0]; 
reg  [inst_sig_width+inst_exp_width : 0]   MAT_B [2:0];  
wire [inst_sig_width+inst_exp_width : 0] MUL_MAT [2:0];

reg  [inst_sig_width+inst_exp_width : 0]   MAT_C [2:0];
reg  [inst_sig_width+inst_exp_width : 0]   MAT_D [2:0];
wire [inst_sig_width+inst_exp_width : 0] ADD_MAT [2:0];

reg  [inst_sig_width+inst_exp_width : 0]   EXP_IN  [2:0];
wire [inst_sig_width+inst_exp_width : 0]  EXP_OUT  [2:0];
wire [inst_sig_width+inst_exp_width : 0] PLUS_EXP  [2:0];
wire [inst_sig_width+inst_exp_width : 0]  SIGMOID  [2:0];

wire [inst_sig_width+inst_exp_width:0] one;
assign one   = 32'b00111111100000000000000000000000;

// matrix mult
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
    MUL1 ( .a(MAT_A[0]), .b(MAT_B[0]), .c(MAT_A[1]), .d(MAT_B[1]), .e(MAT_A[2]), .f(MAT_B[2]), .rnd(3'b000), .z(MUL_MAT[0]));
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
    MUL2 ( .a(MAT_A[3]), .b(MAT_B[0]), .c(MAT_A[4]), .d(MAT_B[1]), .e(MAT_A[5]), .f(MAT_B[2]), .rnd(3'b000), .z(MUL_MAT[1]));
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
    MUL3 ( .a(MAT_A[6]), .b(MAT_B[0]), .c(MAT_A[7]), .d(MAT_B[1]), .e(MAT_A[8]), .f(MAT_B[2]), .rnd(3'b000), .z(MUL_MAT[2]));

// plus
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    ADD4 ( .a(MAT_C[0]), .b(MAT_D[0]), .rnd(3'b000), .z(ADD_MAT[0]));
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    ADD5 ( .a(MAT_C[1]), .b(MAT_D[1]), .rnd(3'b000), .z(ADD_MAT[1]));
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    ADD6 ( .a(MAT_C[2]), .b(MAT_D[2]), .rnd(3'b000), .z(ADD_MAT[2]));

// exp(-x)
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    EXPNX1(.a({~EXP_IN[0][31], EXP_IN[0][30:0]}), .z(EXP_OUT[0]));
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    EXPNX2(.a({~EXP_IN[1][31], EXP_IN[1][30:0]}), .z(EXP_OUT[1]));
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    EXPNX3(.a({~EXP_IN[2][31], EXP_IN[2][30:0]}), .z(EXP_OUT[2]));
// 1 + exp(-x)
// DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
//     ADD1(.a(((switch)?MAT_C[0] : EXP_OUT[0])), .b(((switch)?MAT_D[0] : one)), .rnd(3'b000), .z(PLUS_EXP[0]) );
// DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
//     ADD2(.a(((switch)?MAT_C[0] : EXP_OUT[1])), .b(((switch)?MAT_D[0] : one)), .rnd(3'b000), .z(PLUS_EXP[1]) );
// DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
//     ADD3(.a(((switch)?MAT_C[0] : EXP_OUT[2])), .b(((switch)?MAT_D[0] : one)), .rnd(3'b000), .z(PLUS_EXP[2]) );
// sigmoid(x) = 1/(1+exp(-x))
DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    DIV1(.a(one), .b(ADD_MAT[0]), .z(SIGMOID[0]), .rnd(3'b000));
DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    DIV2(.a(one), .b(ADD_MAT[1]), .z(SIGMOID[1]), .rnd(3'b000));
DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    DIV3(.a(one), .b(ADD_MAT[2]), .z(SIGMOID[2]), .rnd(3'b000));

//---------------------------------------------------------------------
//   DESIGN BLOCK
//---------------------------------------------------------------------
// result save
generate
    for(i=0; i<3; i=i+1)begin
        // H_matrix
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                H_matrix[i] <= 0;
            end
            else if(next_state == CAL)begin
                if(counter == 2 || counter == 5 || counter == 8)begin
                    H_matrix[i] <= SIGMOID[i];
                end
            end
        end
        // UX_matrix
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                UX_matrix[i] <= 0;
            end
            else if(next_state == CAL)begin
                if(counter == 2 || counter == 5)begin
                    UX_matrix[i] <= MUL_MAT[i];
                end
            end
        end
        // WH_matrix
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                WH_matrix[i] <= 0;
            end
            else if(next_state == CAL)begin
                if(counter == 3 || counter == 6)begin
                    WH_matrix[i] <= MUL_MAT[i];
                end
            end
        end
    end
    for(i=1; i<3; i=i+1)begin
        // Y_matrix
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                Y_matrix[i] <= 0;
            end
            else if(next_state == CAL)begin
                if(counter == 4 || counter == 7 || counter == 10)begin
                    Y_matrix[i] <= MUL_MAT[i];
                end
            end
        end
    end
endgenerate

generate
    // MAT_A
    for(i=0; i<9; i=i+1)begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                MAT_A[i] <= 0;
            end
            else if(next_state == CAL)begin
                if(counter == 0 || counter == 1 || counter == 4)begin
                    MAT_A[i] <= U_matrix[i];
                end
                else if(counter == 2 || counter == 5)begin
                    MAT_A[i] <= W_matrix[i];
                end
                else begin
                    MAT_A[i] <= V_matrix[i];
                end
            end
        end
    end
    // MAT_B
    for(i=0; i<3; i=i+1)begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                MAT_B[i] <= 0;
            end
            else if(next_state == CAL)begin
                if(counter == 0)begin
                    MAT_B[i] <= X_matrix[i];
                end
                else if(counter == 1)begin
                    MAT_B[i] <= X_matrix[3+i];
                end
                else if(counter == 2 || counter == 5)begin
                    MAT_B[i] <= SIGMOID[i];
                end
                else if(counter == 3 || counter == 6 || counter == 9)begin
                    MAT_B[i] <= H_matrix[i];
                end
                else if(counter == 4)begin
                    MAT_B[i] <= X_matrix[6+i];
                end
            end
        end
        // MAT_C
        always @(*) begin
            if(counter == 2 || counter == 5 || counter == 8)begin
                MAT_C[i] = EXP_OUT[i];
            end
            else begin
                MAT_C[i] = UX_matrix[i];
            end
        end
        // MAT_D
        always @(*) begin
            if(counter == 2 || counter == 5 || counter == 8)begin
                MAT_D[i] = one;
            end
            else begin
                MAT_D[i] = WH_matrix[i];
            end
        end
        // EXP_IN 
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                EXP_IN[i] <= 0;
            end
            else if(next_state == CAL)begin
                if(counter == 1)begin
                    EXP_IN[i] <= MUL_MAT[i];
                end
                else if(counter == 4 || counter == 7)begin
                    EXP_IN[i] <= ADD_MAT[i];
                end
            end
        end
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        counter <= 0;
    end 
    else if(in_valid_u)begin
        counter <= (counter == 8)? 0: counter + 1;
    end
    else if(next_state == CAL)begin
        counter <= counter + 1;
    end
    else if(next_state == IDLE)begin
        counter <= 0;
    end
end

generate
    for(i=0; i<9; i=i+1)begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                U_matrix[i] <= 0;
            end
            else if(in_valid_u && i == counter)begin
                U_matrix[i] <= weight_u;
            end
        end
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                W_matrix[i] <= 0;
            end
            else if(in_valid_u && i == counter)begin
                W_matrix[i] <= weight_w;
            end
        end
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                V_matrix[i] <= 0;
            end
            else if(in_valid_u && i == counter)begin
                V_matrix[i] <= weight_v;
            end
        end
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                X_matrix[i] <= 0;
            end
            else if(in_valid_u && i == counter)begin
                X_matrix[i] <= data_x;
            end
        end               
    end
endgenerate

//---------------------------------------------------------------------
//   OUTPUT BLOCK
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 'd0;
	else if(next_state == CAL) begin
        if(counter == 4)
		    out_valid <= 'd1;
	end 
	else out_valid <= 'd0; 
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) out <= 32'b0;
	else if(next_state == CAL) begin
        if(counter == 4 || counter == 7 || counter == 10)begin
            out <= (MUL_MAT[0][31])? 0: MUL_MAT[0];
        end
        else if(counter == 5 || counter == 8 || counter == 11)begin
            out <= (Y_matrix[1][31])? 0: Y_matrix[1];
        end
		else if(counter == 6 || counter == 9 || counter == 12)begin
            out <= (Y_matrix[2][31])? 0: Y_matrix[2];
        end
        else out <= 32'b0;
	end
	else out <= 32'b0;
end

//---------------------------------------------------------------------
//   FSM BLOCK
//---------------------------------------------------------------------
//  Current State Block
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        current_state <= IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

//  Next State Block
always@(*)begin
    if(!rst_n)
        next_state = IDLE ;
    else begin
        case(current_state)
        IDLE:
            next_state = (!in_valid_u) ? IDLE  : INPUT  ;
        INPUT:
            next_state = (in_valid_u)  ? INPUT : CAL ;
        CAL:
            next_state = (counter == 13) ? IDLE : CAL;
        default :
            next_state = IDLE ;
        endcase
    end
end
endmodule
// evince /RAID2/EDA/synopsys/synthesis/cur/dw/doc/manuals/dwbb_userguide.pdf &