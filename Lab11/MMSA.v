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
input 		 matrix;
input [1:0]  matrix_size;
input 		 i_mat_idx, w_mat_idx;

output reg   out_valid;//
output reg	 out_value;//
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
reg  [2:0]  current_state, next_state;
parameter IDLE     = 3'd0 ;
parameter INPUT_M  = 3'd1 ;
parameter WAIT_IN2 = 3'd2 ;
parameter INPUT_I  = 3'd3 ;
parameter CAL      = 3'd4 ;
parameter STORE    = 3'd5 ;
parameter SHIFT    = 3'd6 ;
parameter OUTPUT   = 3'd7 ;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
reg [2:0] matrix_size_reg; 
reg [3:0] counter_column, counter_row, matrix_num;

reg [5:0] bit_counter;

reg [127:0] temp_a; // collect 1 row
reg [15:0]  temp_b; // collect 16 bit

reg [6:0] addr_control_i, addr_control_w;

reg [3:0] i_idx, w_idx;

reg  [15:0] ip_data [0:7][0:7];
reg  [15:0] w_data  [0:7][0:7];
wire [15:0] a_temp  [0:7][0:7];
wire [39:0] y_out   [0:7][0:7];

reg [39:0] bit_check;
// flow: 
// 1. summation of out_temp store in sum_buffer
// 2. check the sum_buffer length
// 3. shift the buffer than store in out_buffer
reg signed [39:0] out_temp[0:7] ;
reg  signed [39:0] sum_buffer;
reg  [599:0] out_buffer;
reg  [5:0]  out_length[0:14];

genvar i, j;
integer k;
//---------------------------------------------------------------------
//   SRAM CONTROL
//---------------------------------------------------------------------
reg  MEM_switch;      
reg MEM_wen_1, MEM_wen_3;
reg  [7:0] MEM_addr_1, MEM_addr_3;
reg  [127:0] MEM_in_1, MEM_in_3;
wire [127:0] MEM_out_1, MEM_out_3;

// store input matrix
RA1SH_128_128 SRAM_1(.Q(MEM_out_1), .CLK(clk), .CEN(1'b0), .WEN(MEM_wen_1), .A(MEM_addr_1), .D(MEM_in_1), .OEN(1'b0) );
// store weight matrix
RA1SH_128_128 SRAM_3(.Q(MEM_out_3), .CLK(clk), .CEN(1'b0), .WEN(MEM_wen_3), .A(MEM_addr_3), .D(MEM_in_3), .OEN(1'b0) );

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

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        MEM_wen_1 <= 1;
    else if(current_state == INPUT_M && !MEM_switch)begin
        if(counter_column == matrix_size_reg && bit_counter == 15)
            MEM_wen_1 <= 0;
        else 
            MEM_wen_1 <= 1;
    end
    else 
        MEM_wen_1 <= 1;
end

always @(*) begin
    MEM_addr_1 = addr_control_i;
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

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        MEM_wen_3 <= 1;
    else if(current_state == INPUT_M && MEM_switch)begin
        if(counter_column == matrix_size_reg && bit_counter == 15)
            MEM_wen_3 <= 0;
        else 
            MEM_wen_3 <= 1;
    end
    else 
        MEM_wen_3 <= 1;
end

always @(*) begin
    MEM_addr_3 = addr_control_w;
end

// MEM_switch
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        MEM_switch <= 0;
    else if(current_state == INPUT_M)begin
        if(counter_row == 0 && counter_column == 0 && matrix_num == 0 && !MEM_wen_1)
            MEM_switch <= 1;
        else
            MEM_switch <= MEM_switch;
    end
    else if(next_state == IDLE)begin
        MEM_switch <= 0;
    end
end
//---------------------------------------------------------------------
//   PE CONTROL
//---------------------------------------------------------------------
generate
    // construct systolic array with 256 pe
    for(i=0; i<8; i=i+1)begin
        for(j=0; j<8; j=j+1)begin
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
        for(k=0; k<8; k=k+1)begin
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
    end 
    else begin
        for(k=0; k<8; k=k+1)begin
            ip_data[k][k] <= 0;
        end
    end
end

// other position : only do shift
generate
    for(i=1; i<8; i=i+1)begin
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
    for(i=0; i<8; i=i+1)begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                for(k=0; k<8; k=k+1)begin
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
                end
            end
        end     
    end
endgenerate

// choose which y_out to output
always @(*) begin
    if(matrix_size_reg == 1)begin
        for(k=0; k<8; k=k+1)begin
            out_temp[k] = y_out[1][k];
        end
    end
    else if(matrix_size_reg == 3)begin
        for(k=0; k<8; k=k+1)begin
            out_temp[k] = y_out[3][k];
        end
    end
    else begin
        for(k=0; k<8; k=k+1)begin
            out_temp[k] = y_out[7][k];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        sum_buffer <= 0;
    end
    else if(current_state == STORE) begin
        sum_buffer <= out_temp[ 0] + out_temp[ 1] + out_temp[ 2] + out_temp[ 3] +
                      out_temp[ 4] + out_temp[ 5] + out_temp[ 6] + out_temp[ 7] ;
    end
end

always @(*) begin
    sum_buffer = out_temp[ 0] + out_temp[ 1] + out_temp[ 2] + out_temp[ 3] +
                 out_temp[ 4] + out_temp[ 5] + out_temp[ 6] + out_temp[ 7] ;
end

always @(*) begin
    for(k=39; k>=0; k=k-1)begin
        if(k==39)begin
            bit_check[k] = sum_buffer[k];
        end
        else begin
            bit_check[k] = bit_check[k+1] || sum_buffer[k];
        end
    end
end


generate   
    // out_buffer
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            out_buffer <= 0;
        end
        else if(current_state == STORE) begin
            case (bit_check)
                40'b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[39:0], out_buffer[599:40]}; 
                40'b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[38:0], out_buffer[599:39]}; 
                40'b0011_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[37:0], out_buffer[599:38]}; 
                40'b0001_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[36:0], out_buffer[599:37]}; 
                40'b0000_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[35:0], out_buffer[599:36]}; 
                40'b0000_0111_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[34:0], out_buffer[599:35]}; 
                40'b0000_0011_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[33:0], out_buffer[599:34]}; 
                40'b0000_0001_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[32:0], out_buffer[599:33]}; 
                40'b0000_0000_1111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[31:0], out_buffer[599:32]}; 
                40'b0000_0000_0111_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[30:0], out_buffer[599:31]}; 
                40'b0000_0000_0011_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[29:0], out_buffer[599:30]}; 
                40'b0000_0000_0001_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[28:0], out_buffer[599:29]}; 
                40'b0000_0000_0000_1111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[27:0], out_buffer[599:28]}; 
                40'b0000_0000_0000_0111_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[26:0], out_buffer[599:27]}; 
                40'b0000_0000_0000_0011_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[25:0], out_buffer[599:26]}; 
                40'b0000_0000_0000_0001_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[24:0], out_buffer[599:25]}; 
                40'b0000_0000_0000_0000_1111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[23:0], out_buffer[599:24]}; 
                40'b0000_0000_0000_0000_0111_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[22:0], out_buffer[599:23]}; 
                40'b0000_0000_0000_0000_0011_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[21:0], out_buffer[599:22]}; 
                40'b0000_0000_0000_0000_0001_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[20:0], out_buffer[599:21]}; 
                40'b0000_0000_0000_0000_0000_1111_1111_1111_1111_1111: out_buffer <= {sum_buffer[19:0], out_buffer[599:20]}; 
                40'b0000_0000_0000_0000_0000_0111_1111_1111_1111_1111: out_buffer <= {sum_buffer[18:0], out_buffer[599:19]}; 
                40'b0000_0000_0000_0000_0000_0011_1111_1111_1111_1111: out_buffer <= {sum_buffer[17:0], out_buffer[599:18]}; 
                40'b0000_0000_0000_0000_0000_0001_1111_1111_1111_1111: out_buffer <= {sum_buffer[16:0], out_buffer[599:17]}; 
                40'b0000_0000_0000_0000_0000_0000_1111_1111_1111_1111: out_buffer <= {sum_buffer[15:0], out_buffer[599:16]}; 
                40'b0000_0000_0000_0000_0000_0000_0111_1111_1111_1111: out_buffer <= {sum_buffer[14:0], out_buffer[599:15]}; 
                40'b0000_0000_0000_0000_0000_0000_0011_1111_1111_1111: out_buffer <= {sum_buffer[13:0], out_buffer[599:14]}; 
                40'b0000_0000_0000_0000_0000_0000_0001_1111_1111_1111: out_buffer <= {sum_buffer[12:0], out_buffer[599:13]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_1111_1111_1111: out_buffer <= {sum_buffer[11:0], out_buffer[599:12]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0111_1111_1111: out_buffer <= {sum_buffer[10:0], out_buffer[599:11]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0011_1111_1111: out_buffer <= {sum_buffer[ 9:0], out_buffer[599:10]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0001_1111_1111: out_buffer <= {sum_buffer[ 8:0], out_buffer[599: 9]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_1111_1111: out_buffer <= {sum_buffer[ 7:0], out_buffer[599: 8]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0111_1111: out_buffer <= {sum_buffer[ 6:0], out_buffer[599: 7]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0011_1111: out_buffer <= {sum_buffer[ 5:0], out_buffer[599: 6]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0001_1111: out_buffer <= {sum_buffer[ 4:0], out_buffer[599: 5]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0000_1111: out_buffer <= {sum_buffer[ 3:0], out_buffer[599: 4]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0111: out_buffer <= {sum_buffer[ 2:0], out_buffer[599: 3]}; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0011: out_buffer <= {sum_buffer[ 1:0], out_buffer[599: 2]}; 
                default                                              : out_buffer <= {sum_buffer[   0], out_buffer[599: 1]};  
            endcase
        end
        else if(current_state == OUTPUT)begin
            if(bit_counter > 5)begin
                if (out_length[0] > 0)begin
                    out_buffer <= out_buffer << 1;
                end
            end  
        end
    end

    // store the answer first then do shift to find the length of number
    // position 0
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            out_length[0] <= 0;
        end
        else if(current_state == STORE) begin
            case (bit_check)
                40'b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd40; 
                40'b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd39; 
                40'b0011_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd38; 
                40'b0001_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd37; 
                40'b0000_1111_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd36; 
                40'b0000_0111_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd35; 
                40'b0000_0011_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd34; 
                40'b0000_0001_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd33; 
                40'b0000_0000_1111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd32; 
                40'b0000_0000_0111_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd31; 
                40'b0000_0000_0011_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd30; 
                40'b0000_0000_0001_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd29; 
                40'b0000_0000_0000_1111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd28; 
                40'b0000_0000_0000_0111_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd27; 
                40'b0000_0000_0000_0011_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd26; 
                40'b0000_0000_0000_0001_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd25; 
                40'b0000_0000_0000_0000_1111_1111_1111_1111_1111_1111: out_length[0] <= 6'd24; 
                40'b0000_0000_0000_0000_0111_1111_1111_1111_1111_1111: out_length[0] <= 6'd23; 
                40'b0000_0000_0000_0000_0011_1111_1111_1111_1111_1111: out_length[0] <= 6'd22; 
                40'b0000_0000_0000_0000_0001_1111_1111_1111_1111_1111: out_length[0] <= 6'd21; 
                40'b0000_0000_0000_0000_0000_1111_1111_1111_1111_1111: out_length[0] <= 6'd20; 
                40'b0000_0000_0000_0000_0000_0111_1111_1111_1111_1111: out_length[0] <= 6'd19; 
                40'b0000_0000_0000_0000_0000_0011_1111_1111_1111_1111: out_length[0] <= 6'd18; 
                40'b0000_0000_0000_0000_0000_0001_1111_1111_1111_1111: out_length[0] <= 6'd17; 
                40'b0000_0000_0000_0000_0000_0000_1111_1111_1111_1111: out_length[0] <= 6'd16; 
                40'b0000_0000_0000_0000_0000_0000_0111_1111_1111_1111: out_length[0] <= 6'd15; 
                40'b0000_0000_0000_0000_0000_0000_0011_1111_1111_1111: out_length[0] <= 6'd14; 
                40'b0000_0000_0000_0000_0000_0000_0001_1111_1111_1111: out_length[0] <= 6'd13; 
                40'b0000_0000_0000_0000_0000_0000_0000_1111_1111_1111: out_length[0] <= 6'd12; 
                40'b0000_0000_0000_0000_0000_0000_0000_0111_1111_1111: out_length[0] <= 6'd11; 
                40'b0000_0000_0000_0000_0000_0000_0000_0011_1111_1111: out_length[0] <= 6'd10; 
                40'b0000_0000_0000_0000_0000_0000_0000_0001_1111_1111: out_length[0] <= 6'd9; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_1111_1111: out_length[0] <= 6'd8; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0111_1111: out_length[0] <= 6'd7; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0011_1111: out_length[0] <= 6'd6; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0001_1111: out_length[0] <= 6'd5; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0000_1111: out_length[0] <= 6'd4; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0111: out_length[0] <= 6'd3; 
                40'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0011: out_length[0] <= 6'd2; 
                default                                              : out_length[0] <= 6'd1; 
            endcase  
        end
        else if(current_state == OUTPUT)begin
            if(bit_counter > 5)begin
                if (out_length[0] == 1)begin
                    out_length[0] <= out_length[1];
                end
                else begin
                    out_length[0] <= out_length[0] - 1;
                end
            end  
        end
    end
    // position 1 ~ 13
    for(i=1; i<14; i=i+1)begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                out_length[i] <= 0;
            end
            else if(current_state == STORE) begin
                out_length[i] <= out_length[i-1];
            end
            else if(current_state == OUTPUT) begin
                if (bit_counter > 5 && out_length[0] == 1)begin
                    out_length[i] <= out_length[i+1];
                end
            end
        end
    end
    // position 14
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            out_length[14] <= 0;
        end
        else if(current_state == STORE) begin
            out_length[14] <= out_length[13];
        end
        else if(current_state == OUTPUT) begin
            if (bit_counter > 5 && out_length[0] == 1)begin
                out_length[14] <= 0;
            end
        end
    end
endgenerate
//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
// control input matrix SRAM addr
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        addr_control_i <= 0;
    else if(!MEM_wen_1)begin
        addr_control_i <= addr_control_i + 1;
    end
    else if(next_state == INPUT_I)begin
        addr_control_i <= {i_idx[2:0], i_mat_idx}*(matrix_size_reg+1);
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
    else if(!MEM_wen_3)begin
        addr_control_w <= addr_control_w + 1;
    end
    else if(next_state == INPUT_I)begin
        addr_control_w <= {w_idx[2:0], w_mat_idx}*(matrix_size_reg+1);
    end
    else if(next_state == CAL)begin
        addr_control_w <= addr_control_w + 1;
    end
    else if(next_state == IDLE)begin
        addr_control_w <= 0;
    end
end

// count SISO bit
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) bit_counter <= 0;
    else if(current_state == INPUT_M)begin
        bit_counter <= (bit_counter == 15)? 0: bit_counter + 1;
    end
    else if(current_state == OUTPUT)begin
        if(bit_counter < 6)begin
            bit_counter <= bit_counter + 1;
        end
        else if(out_length[0] == 1)begin
            bit_counter <= 0;
        end
    end
end

// collect 16 bit
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) temp_b <= 0;
    else if(next_state == INPUT_M) begin
        temp_b <= { temp_b[14:0], matrix};
    end
end

// collect 1 row
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) temp_a <= 0;
    else if(current_state == INPUT_M && bit_counter == 15) begin
        temp_a <= { temp_b, temp_a[127:16]};
    end
end

// collect idx
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) i_idx <= 0;
    else if(next_state == INPUT_I) begin
        i_idx <= { i_idx[2:0], i_mat_idx};
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) w_idx <= 0;
    else if(next_state == INPUT_I) begin
        w_idx <= { w_idx[2:0], w_mat_idx};
    end
end

// save matrix size
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        matrix_size_reg <= 1;
    else if(next_state == INPUT_M && current_state == IDLE)begin
        if(matrix_size == 0)      // 2*2
            matrix_size_reg <= 1;
        else if(matrix_size == 1) // 4*4
            matrix_size_reg <= 3;
        else                      // 8*8 
            matrix_size_reg <= 7;
    end
end

// 3 counter to count 16 matrices elements : column, row, matrix number
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        counter_column <= 0;
    else if(current_state == INPUT_M)begin
        if(bit_counter == 15)begin
            counter_column <= (counter_column == matrix_size_reg)? 0: counter_column + 1;
        end
        else
            counter_column <= counter_column;
    end
    // used to cal operation (2 4 or 8)
    else if(current_state == CAL)begin
        counter_column <= (counter_column == matrix_size_reg + 1)? 0: counter_column + 1;
    end
    // used to output operation (3 7 or 15)
    else if(current_state == STORE)begin
        counter_column <= counter_column + 1;
    end
    else if(current_state == OUTPUT)begin
        if(bit_counter > 5 && out_length[0] == 1)
            counter_column <= counter_column - 1;
    end
    else counter_column <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        counter_row <= 0;
    else if(current_state == INPUT_M)begin
        if(counter_column == matrix_size_reg && bit_counter == 15)begin
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
        matrix_num <= (counter_row == matrix_size_reg && counter_column == matrix_size_reg && bit_counter == 15)? matrix_num + 1: matrix_num;
    end
    // count if the last matrices multiplication or not
    else if(next_state == INPUT_I && current_state == WAIT_IN2)begin
        matrix_num <= matrix_num + 1;
    end 
    else if(next_state == IDLE)begin
        matrix_num <= 0;
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
            next_state = (counter_column == matrix_size_reg + 1)? STORE: CAL;
        STORE:begin
            if(matrix_size_reg == 1 && counter_column == 2)begin
                next_state = OUTPUT;
            end
            else if(matrix_size_reg == 3 && counter_column == 6)begin
                next_state = OUTPUT;
            end
            else if(matrix_size_reg == 7 && counter_column == 14)begin
                next_state = OUTPUT;
            end
            else begin
                next_state = STORE;
            end
        end
        // SHIFT:begin
        //     if(matrix_size_reg == 1 && msb_check_2) next_state = OUTPUT;
        //     else if(matrix_size_reg == 3 && msb_check_4) next_state = OUTPUT;
        //     else if(matrix_size_reg == 7 && msb_check_8) next_state = OUTPUT;
        //     else if(out_length[0] == 1) next_state = OUTPUT;
        //     else next_state = SHIFT;
        // end
        OUTPUT:begin
            if(counter_column == 1 && bit_counter > 5 && out_length[0] == 1)begin
                if(matrix_num == 15)
                    next_state = IDLE;
                else
                    next_state = WAIT_IN2;
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
        case (bit_counter)
            0: out_value <= out_length[0][5];
            1: out_value <= out_length[0][4];
            2: out_value <= out_length[0][3];
            3: out_value <= out_length[0][2];
            4: out_value <= out_length[0][1];
            5: out_value <= out_length[0][0];
            default: out_value <= out_buffer[599]; 
        endcase
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

