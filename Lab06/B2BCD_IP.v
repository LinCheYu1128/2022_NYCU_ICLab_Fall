module B2BCD_IP #(parameter WIDTH = 4, parameter DIGIT = 2)(
    Binary_code,
    BCD_code
);

input  [WIDTH-1: 0]   Binary_code;
output [4*DIGIT-1: 0]    BCD_code;

wire [4*DIGIT-1: 0] shift_result [2:WIDTH-1];
wire [4*DIGIT-1: 0]   add_result [2:WIDTH-2];

genvar i, j;
generate
    for(i=2; i<WIDTH; i=i+1)begin : loop_shift
        if(i==2)begin
            assign shift_result[i] = {{(4*DIGIT-3){1'b0}}, Binary_code[WIDTH-1 : WIDTH-3]};
        end
        else begin
            assign shift_result[i] = {add_result[i-1][4*DIGIT-2: 0], Binary_code[WIDTH-i-1]};
        end   
    end
    for(i=2; i<WIDTH-1; i=i+1)begin : loop_add1
        for(j=0; j<DIGIT; j=j+1)begin
            assign add_result[i][4*j+3:4*j] = (shift_result[i][4*j+3:4*j] > 4)? shift_result[i][4*j+3:4*j] + 3 : shift_result[i][4*j+3:4*j]; 
        end      
    end
endgenerate

assign BCD_code = shift_result[WIDTH-1];
	
endmodule