module MMSA(
// input signals
    clk,
    rst_n,
    in_valid,
	in_valid2,
    matrix,
	matrix_size,
    i_mat_idx,
    w_mat_idx,
	
// output signals
    out_valid,
    out_value
);
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input        clk, rst_n, in_valid, in_valid2;
input [15:0] matrix;
input [1:0]  matrix_size;
input [3:0]  i_mat_idx, w_mat_idx;

output reg       	     out_valid;
output reg signed [39:0] out_value;
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
reg  [2:0]  current_state, next_state;
parameter IDLE     = 3'd0 ;
parameter INPUT_M  = 3'd1 ;
parameter WAIT_IN2 = 3'd2 ;
parameter INPUT_I  = 3'd3 ;
parameter CAL      = 3'd4 ;
parameter OUTPUT   = 3'd5 ;

integer k;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
reg [4:0] counter_column;
reg [3:0] counter_row, matrix_num;
reg [3:0] matrix_size_reg; 

reg [127:0] temp_a;

reg [7:0] addr_control_i, addr_control_w;
reg signed [39:0] out_temp[0:15] ;

reg  [15:0] ip_data [0:15][0:15];
reg  [15:0] w_data  [0:15][0:15];
wire [15:0] a_temp  [0:15][0:15];
wire [39:0] y_out   [0:15][0:15];

genvar i, j;
//---------------------------------------------------------------------
//   SRAM CONTROL
//---------------------------------------------------------------------
reg  MEM_switch;      
reg MEM_wen_1, MEM_wen_2, MEM_wen_3, MEM_wen_4;
reg  [7:0] MEM_addr_1, MEM_addr_2, MEM_addr_3, MEM_addr_4;
reg  [127:0] MEM_in_1, MEM_in_2, MEM_in_3, MEM_in_4;
wire [127:0] MEM_out_1, MEM_out_2, MEM_out_3, MEM_out_4;

// store input matrix
RA1SH_128_256 SRAM_1(.Q(MEM_out_1), .CLK(clk), .CEN(1'b0), .WEN(MEM_wen_1), .A(MEM_addr_1), .D(MEM_in_1), .OEN(1'b0) );
RA1SH_128_256 SRAM_2(.Q(MEM_out_2), .CLK(clk), .CEN(1'b0), .WEN(MEM_wen_2), .A(MEM_addr_2), .D(MEM_in_2), .OEN(1'b0) );
// store weight matrix
RA1SH_128_256 SRAM_3(.Q(MEM_out_3), .CLK(clk), .CEN(1'b0), .WEN(MEM_wen_3), .A(MEM_addr_3), .D(MEM_in_3), .OEN(1'b0) );
RA1SH_128_256 SRAM_4(.Q(MEM_out_4), .CLK(clk), .CEN(1'b0), .WEN(MEM_wen_4), .A(MEM_addr_4), .D(MEM_in_4), .OEN(1'b0) );

// SRAM 1
always @(*) begin
    if(matrix_size_reg == 1) begin
        MEM_in_1 = {96'b0 , temp_a[127:96]} ;
    end 
    else if(matrix_size_reg == 3) begin
        MEM_in_1 = {64'b0 , temp_a[127:64]} ;
    end
    else begin
        MEM_in_1 = temp_a ;
    end
end

always @(*) begin
    if(current_state == INPUT_M && !MEM_switch)begin
        if(matrix_size_reg == 15)begin
            if(counter_column == 7)
                MEM_wen_1 = 0;
            else
                MEM_wen_1 = 1;
        end
        else begin
            if(counter_column == matrix_size_reg)
                MEM_wen_1 = 0;
            else 
                MEM_wen_1 = 1;
        end 
    end
    else 
        MEM_wen_1 = 1;
end

always @(*) begin
    MEM_addr_1 = addr_control_i;
end

// SRAM 2
always @(*) begin
    if(matrix_size_reg == 15) begin
        MEM_in_2 = temp_a ;
    end 
    else begin
        MEM_in_2 = 128'b0 ;
    end
end

always @(*) begin
    if(current_state == INPUT_M && counter_column == matrix_size_reg && !MEM_switch)
        MEM_wen_2 = 0;
    else 
        MEM_wen_2 = 1;
end

always @(*) begin
    MEM_addr_2 = addr_control_i;
end

// SRAM 3
always @(*) begin
    if(matrix_size_reg == 1) begin
        MEM_in_3 = {96'b0 , temp_a[127:96]} ;
    end 
    else if(matrix_size_reg == 3) begin
        MEM_in_3 = {64'b0 , temp_a[127:64]} ;
    end
    else begin
        MEM_in_3 = temp_a ;
    end
end

always @(*) begin
    if(current_state == INPUT_M && MEM_switch)begin
        if(matrix_size_reg == 15)begin
            if(counter_column == 7)
                MEM_wen_3 = 0;
            else
                MEM_wen_3 = 1;
        end
        else begin
            if(counter_column == matrix_size_reg)
                MEM_wen_3 = 0;
            else 
                MEM_wen_3 = 1;
        end 
    end
    else 
        MEM_wen_3 = 1;
end

always @(*) begin
    MEM_addr_3 = addr_control_w;
end

// SRAM 4
always @(*) begin
    if(matrix_size_reg == 15) begin
        MEM_in_4 = temp_a ;
    end 
    else begin
        MEM_in_4 = 128'b0 ;
    end
end

always @(*) begin
    if(current_state == INPUT_M && counter_column == matrix_size_reg && MEM_switch)
        MEM_wen_4 = 0;
    else 
        MEM_wen_4 = 1;
end

always @(*) begin
    MEM_addr_4 = addr_control_w;
end

// MEM_switch
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        MEM_switch <= 0;
    else if(next_state == INPUT_M)begin
        if(counter_row == matrix_size_reg && counter_column == matrix_size_reg && matrix_num == 15)
            MEM_switch <= 1;
        else
            MEM_switch <= MEM_switch;
    end
    else if(next_state == IDLE)begin
        MEM_switch <= 0;
    end
end

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------

// control input matrix SRAM addr
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        addr_control_i <= 0;
    else if(next_state == INPUT_M && counter_column == matrix_size_reg)begin
        addr_control_i <= addr_control_i + 1;
    end
    else if(next_state == INPUT_I)begin
        addr_control_i <= i_mat_idx*(matrix_size_reg+1);
    end
    else if(next_state == CAL)begin
        addr_control_i <= addr_control_i + 1;
    end
    else if(next_state == IDLE)begin
        addr_control_i <= 0;
    end
end

// control weight matrix SRAM addr
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        addr_control_w <= 0;
    else if(next_state == INPUT_M && counter_column == matrix_size_reg)begin
        addr_control_w <= (counter_row == matrix_size_reg && counter_column == matrix_size_reg && matrix_num == 15)? 0: addr_control_w + 1;
    end
    else if(next_state == INPUT_I)begin
        addr_control_w <= w_mat_idx*(matrix_size_reg+1);
    end
    else if(next_state == CAL)begin
        addr_control_w <= addr_control_w + 1;
    end
    else if(next_state == IDLE)begin
        addr_control_w <= 0;
    end
end

// store temp data from input
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) temp_a <= 0;
    else if(next_state == INPUT_M) begin
        temp_a <= { matrix, temp_a[127:16]};
    end
end

// 3 counter to count 16 matrices elements : column, row, matrix number
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        counter_column <= 0;
    else if(current_state == INPUT_M)begin
        counter_column <= (counter_column == matrix_size_reg)? 0: counter_column + 1;
    end
    // used to cal operation (2 4 8 or 16)
    else if(current_state == CAL)begin
        counter_column <= (counter_column == matrix_size_reg + 1)? 0: counter_column + 1;
    end
    // used to output operation (3 7 15 or 31)
    else if(current_state == OUTPUT)begin
        counter_column <= counter_column + 1;
    end
    else counter_column <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        counter_row <= 0;
    else if(current_state == INPUT_M)begin
        if(counter_column == matrix_size_reg)begin
            if(counter_row == matrix_size_reg)
                counter_row <= 0;
            else 
                counter_row <= counter_row + 1;
        end
        else begin
            counter_row <= counter_row;
        end
    end
    else counter_row <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        matrix_num <= 0;
    else if(next_state == INPUT_M)begin
        matrix_num <= (counter_row == matrix_size_reg && counter_column == matrix_size_reg)? matrix_num + 1: matrix_num;
    end
    // count if the last matrices multiplication or not
    else if(next_state == INPUT_I)begin
        matrix_num <= matrix_num + 1;
    end 
    else if(next_state == IDLE)begin
        matrix_num <= 0;
    end
end

// save matrix size
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        matrix_size_reg <= 1;
    else if(next_state == INPUT_M && current_state == IDLE)begin
        if(matrix_size == 0) 
            matrix_size_reg <= 1;
        else if(matrix_size == 1)
            matrix_size_reg <= 3;
        else if(matrix_size == 2)
            matrix_size_reg <= 7;
        else
            matrix_size_reg <= 15;
    end
end

//---------------------------------------------------------------------
//   PE CONTROL
//---------------------------------------------------------------------
generate
    // construct systolic array with 256 pe
    for(i=0; i<16; i=i+1)begin
        for(j=0; j<16; j=j+1)begin
            // first row and first column pe : x data from input,and psum is 0
            if(i == 0 && j== 0)begin
                PE pe1(.clk(clk), .rst_n(rst_n), .a(ip_data[i][0]), .b(w_data[i][j]), .psum(40'b0), .a_out(a_temp[i][j]), .out(y_out[i][j]));
            end
            // first row and first column pe : x data from left pe's a_out,and psum is 0
            else if(i == 0)begin
                PE pe2(.clk(clk), .rst_n(rst_n), .a(a_temp[i][j-1]), .b(w_data[i][j]), .psum(40'b0), .a_out(a_temp[i][j]), .out(y_out[i][j]));
            end 
            // first row and first column pe : x data from input,and psum is upper row pe's y_out
            else if(j == 0)begin
                PE pe2(.clk(clk), .rst_n(rst_n), .a(ip_data[i][0]), .b(w_data[i][j]), .psum(y_out[i-1][j]), .a_out(a_temp[i][j]), .out(y_out[i][j]));
            end
            // first row and first column pe : x data from left pe's a_out, and psum is upper row pe's y_out
            else begin
                PE pe3(.clk(clk), .rst_n(rst_n), .a(a_temp[i][j-1]), .b(w_data[i][j]), .psum(y_out[i-1][j]), .a_out(a_temp[i][j]), .out(y_out[i][j]));
            end           
        end
    end
endgenerate

// ip_data will make some delay when input it to PE(first column: no delay; second column: 1 delay; third column: 2 delay...)
// diagonal position : load data from sram to ip_data buffer
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        for(k=0; k<16; k=k+1)begin
            ip_data[k][k] <= 0;
        end
    end
    else if(current_state == CAL && counter_column <= matrix_size_reg)begin
        ip_data[ 0][ 0] <= MEM_out_1[ 15:  0];
        ip_data[ 1][ 1] <= MEM_out_1[ 31: 16]; 
        ip_data[ 2][ 2] <= MEM_out_1[ 47: 32];
        ip_data[ 3][ 3] <= MEM_out_1[ 63: 48]; 
        ip_data[ 4][ 4] <= MEM_out_1[ 79: 64]; 
        ip_data[ 5][ 5] <= MEM_out_1[ 95: 80]; 
        ip_data[ 6][ 6] <= MEM_out_1[111: 96]; 
        ip_data[ 7][ 7] <= MEM_out_1[127:112]; 
        ip_data[ 8][ 8] <= MEM_out_2[ 15:  0]; 
        ip_data[ 9][ 9] <= MEM_out_2[ 31: 16]; 
        ip_data[10][10] <= MEM_out_2[ 47: 32]; 
        ip_data[11][11] <= MEM_out_2[ 63: 48]; 
        ip_data[12][12] <= MEM_out_2[ 79: 64]; 
        ip_data[13][13] <= MEM_out_2[ 95: 80]; 
        ip_data[14][14] <= MEM_out_2[111: 96]; 
        ip_data[15][15] <= MEM_out_2[127:112]; 
    end 
    else begin
        for(k=0; k<16; k=k+1)begin
            ip_data[k][k] <= 0;
        end
    end
end

// other position : only do shift
generate
    for(i=1; i<16; i=i+1)begin
        for(j=i-1; j>=0; j=j-1)begin
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n)begin
                    ip_data[i][j] <= 0;
                end
                else begin
                    ip_data[i][j] <= ip_data[i][j+1];
                end
            end     
        end
    end
endgenerate

// give weight
generate
    for(i=0; i<16; i=i+1)begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                for(k=0; k<16; k=k+1)begin
                    w_data[i][k] <= 0;
                end
            end
            else if(current_state == CAL && counter_column <= matrix_size_reg)begin
                if(i == counter_column)begin
                    w_data[i][ 0] <= MEM_out_3[ 15:  0];
                    w_data[i][ 1] <= MEM_out_3[ 31: 16];
                    w_data[i][ 2] <= MEM_out_3[ 47: 32];
                    w_data[i][ 3] <= MEM_out_3[ 63: 48];
                    w_data[i][ 4] <= MEM_out_3[ 79: 64];
                    w_data[i][ 5] <= MEM_out_3[ 95: 80];
                    w_data[i][ 6] <= MEM_out_3[111: 96];
                    w_data[i][ 7] <= MEM_out_3[127:112];
                    w_data[i][ 8] <= MEM_out_4[ 15:  0];
                    w_data[i][ 9] <= MEM_out_4[ 31: 16];
                    w_data[i][10] <= MEM_out_4[ 47: 32];
                    w_data[i][11] <= MEM_out_4[ 63: 48];
                    w_data[i][12] <= MEM_out_4[ 79: 64];
                    w_data[i][13] <= MEM_out_4[ 95: 80];
                    w_data[i][14] <= MEM_out_4[111: 96];
                    w_data[i][15] <= MEM_out_4[127:112];
                end
            end
        end     
    end
endgenerate

// choose which y_out to output
always @(*) begin
    if(matrix_size_reg == 1)begin
        for(k=0; k<16; k=k+1)begin
            out_temp[k] = y_out[1][k];
        end
    end
    else if(matrix_size_reg == 3)begin
        for(k=0; k<16; k=k+1)begin
            out_temp[k] = y_out[3][k];
        end
    end
    else if(matrix_size_reg == 7)begin
        for(k=0; k<16; k=k+1)begin
            out_temp[k] = y_out[7][k];
        end
    end
    else begin
        for(k=0; k<16; k=k+1)begin
            out_temp[k] = y_out[15][k];
        end
    end
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
            next_state = (!in_valid)? IDLE : INPUT_M ;
        INPUT_M:
            next_state = (!in_valid) ? WAIT_IN2 : INPUT_M ;
        WAIT_IN2:
            next_state = (!in_valid2)? WAIT_IN2 : INPUT_I;
        INPUT_I:
            next_state = (!in_valid2)? CAL : INPUT_I;
        CAL:
            next_state = (counter_column == matrix_size_reg + 1)? OUTPUT: CAL;
        OUTPUT:begin
            if(matrix_size_reg == 1 && counter_column == 2)begin
                next_state = (matrix_num == 15)? IDLE : WAIT_IN2;
            end
            else if(matrix_size_reg == 3 && counter_column == 6)begin
                next_state = (matrix_num == 15)? IDLE : WAIT_IN2;
            end
            else if(matrix_size_reg == 7 && counter_column == 14)begin
                next_state = (matrix_num == 15)? IDLE : WAIT_IN2;
            end
            else if(matrix_size_reg == 15 && counter_column == 30)begin
                next_state = (matrix_num == 15)? IDLE : WAIT_IN2;
            end
            else begin
                next_state = OUTPUT;
            end
        end
        default :
            next_state = IDLE ;
        endcase
    end
end

//---------------------------------------------------------------------
//   OUTPUT BLOCK
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 'd0;
    else if(current_state == OUTPUT) out_valid <= 'd1;
	else out_valid <= 'd0; 
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) out_value <= 'd0;
    // summation along antidiagonal direction will always equal to the summation of out_temp 0 ~ 15
    else if(current_state == OUTPUT)begin
        out_value <= out_temp[ 0] + out_temp[ 1] + out_temp[ 2] + out_temp[ 3] +
                     out_temp[ 4] + out_temp[ 5] + out_temp[ 6] + out_temp[ 7] +
                     out_temp[ 8] + out_temp[ 9] + out_temp[10] + out_temp[11] +
                     out_temp[12] + out_temp[13] + out_temp[14] + out_temp[15] ; 
    end 
	else out_value <= 'd0;
end

endmodule

module PE (
    input             clk,
    input             rst_n,
    input signed      [15:0] a,
    input signed      [15:0] b,
    input signed      [39:0] psum,
    output reg signed [15:0] a_out,
    output reg signed [39:0] out
);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out <= 40'b0;
        a_out <= 16'b0;
    end 
    else begin 
        out <= (a * b) + psum;
        a_out <= a;
    end
end

endmodule
