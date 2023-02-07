module TT(
           //Input Port
           clk,
           rst_n,
           in_valid,
           source,
           destination,

           //Output Port
           out_valid,
           cost
       );

input               clk, rst_n, in_valid;
input       [3:0]   source;  //0-15
input       [3:0]   destination;

output reg          out_valid;
output reg  [3:0]   cost;

//==============================================//
//             Parameter and Integer            //
//==============================================//

reg      exe_end;
reg  [15:0]matrix [15:0]; //16 x 16 matrix

reg       [3:0]   count;
integer   i ,j ,k;
reg  [3:0] temp_source;
reg  [3:0] temp_dest;
wire [15:0]array_comb;

//==============================================//
//            FSM State Declaration             //
//==============================================//

parameter IDLE = 2'd0 ;
parameter MAP  = 2'd1 ;
parameter EXE  = 2'd2 ;
parameter OUT  = 2'd3 ;

//==============================================//
//                 reg declaration              //
//==============================================//

reg [1:0]  current_state;
reg [1:0]  next_state;
reg [15:0] array;


//==============================================//
//                   Debug                      //
//==============================================//

wire array_debug [15:0];
wire matrix_debug[15:0][15:0] ;
genvar a,b;

generate
    for(a=0;a<16;a=a+1)
    begin
        assign array_debug[a] = array[a];

    end
endgenerate

generate
    for(a=0;a<16;a=a+1)
    begin
        for(b=0;b<16;b=b+1)
        begin
            assign matrix_debug[a][b] = matrix[a][b];
        end
    end
endgenerate

//==============================================//
//             Current State Block              //
//==============================================//

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        current_state <= IDLE; /* initial state */
    else
        current_state <= next_state;
end

//==============================================//
//              Next State Block                //
//==============================================//

always@(*)
begin
    if(!rst_n)
        next_state = IDLE ;
    else
    begin
        case(current_state)
            IDLE:
                next_state = (!in_valid)? IDLE : MAP ;
            MAP:
                next_state = (!in_valid)? EXE  : MAP ;
            EXE :
                next_state = (!exe_end) ? EXE  : OUT ;
            OUT :
                next_state = IDLE ;
            default :
                next_state = IDLE ;
        endcase
    end
end

//==============================================//
//                  Input Block                 //
//==============================================//


//save source and destination
always@(posedge clk or negedge rst_n)
begin
    if(current_state == IDLE && next_state == MAP)
    begin
        temp_source <= source;
        temp_dest <=  destination;
    end
end


//matrix
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) //reset matrix
    begin
        for(i=0; i<16 ; i= i+1)
        begin
            for(j=0; j<16 ; j= j+1)
            begin
                matrix[i][j] <= 0;
            end
        end
    end
    else if(current_state == MAP) //diagonal = 1
    begin
        for(i=0; i<16 ; i= i+1)
        begin
            begin
                matrix[i][i] <= 1;
            end
        end
        matrix[source][destination] <= 1;
        matrix[destination][source] <= 1;
    end

    else if(next_state == IDLE)  //reset matrix
    begin
        for(i=0; i<16 ; i= i+1)
        begin
            for(j=0; j<16 ; j= j+1)
            begin
                matrix[i][j] <= 0;
            end
        end
    end
end

//==============================================//
//              Calculation Block               //
//==============================================//

//array calculate
generate
    for(a=0;a<16;a=a+1)
    begin
        assign array_comb[a] = | (matrix[a] & array);
    end
endgenerate

//array
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        array <= 0; //reset
    end
    else if(next_state == MAP && current_state == IDLE)
    begin
        array <= 0; //reset
    end
    else if(in_valid)
    begin
        array[temp_source] <= 1'b1;
    end
    else
    begin
        if (array != array_comb) // different means connect to other
        begin                    // but not destination
            array <= array_comb;
        end
    end
end



//cost
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        cost <= 0;
    end
    else if(next_state == MAP && current_state == IDLE)
    begin
        cost <= 0;
    end
    else if(in_valid)
    begin
        array[source] <= 1'b1;
        cost <= 0;
    end
    else // un in_valad
    begin
        if (array != array_comb)
        begin
            cost <= cost +1;
        end
        else //array == array_comb means isolate or loop
        begin
            cost <= 0;
        end

    end
end


//exe_end
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        exe_end <= 0;
    end
    else if(next_state == MAP && current_state == IDLE)
    begin
        exe_end <= 0;
    end
    else if(in_valid)
    begin
        if (array[temp_dest] == 1)  //exe end
        begin
            exe_end <= 1;
        end
    end
    else // un in_valad
    begin
        if (current_state == EXE)
        begin
            if (array != array_comb)
            begin
                exe_end <= 0;
            end
            else //array == array_comb means isolate or loop
            begin
                exe_end <= 1;
            end
        end
    end
end



//==============================================//
//                Output Block                  //
//==============================================//

//out_valid
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        out_valid <= 0;
    end
    else if(next_state == OUT)
    begin
        out_valid <= 1;
    end
    else
    begin
        out_valid <= 0;
    end
end

endmodule
