module UT_TOP (
    // Input signals
    clk, 
    rst_n, 
    in_valid, 
    in_time,
    // Output signals
    out_valid, 
    out_display, 
    out_day
);
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input        clk, rst_n, in_valid;
input [30:0] in_time;

output reg       out_valid;
output reg [3:0] out_display;
output reg [2:0] out_day;
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
reg  [3:0]  current_state, next_state;
parameter IDLE       = 4'd0  ;
parameter INPUT      = 4'd1  ;
parameter CAL_16YEAR = 4'd2  ;
parameter CAL_4YEAR  = 4'd3  ;
parameter CAL_YEAR   = 4'd4  ;
parameter CAL_MONTH  = 4'd5  ;
parameter CAL_DAY    = 4'd6  ;
parameter CAL_4HOUR  = 4'd7  ;
parameter CAL_HOUR   = 4'd8  ;
parameter CAL_15MIN  = 4'd9  ;
parameter CAL_MIN    = 4'd10 ;
parameter CAL_SEC    = 4'd11 ;
parameter OUT        = 4'd12 ;

parameter time_16years      = 31'd504921600;  //(365*16+4)*86400
parameter time_4years       = 31'd126230400;  //(365*4+1)*86400
parameter time_common_years = 31'd31536000;   //365*86400
parameter time_leap_years   = 31'd31622400;   //366*86400
parameter time_odd_month    = 31'd2678400;    //31*86400
parameter time_even_month   = 31'd2592000;    //30*86400
parameter time_leap_month   = 31'd2505600;    //29*86400
parameter time_com_month    = 31'd2419200;    //28*86400
parameter time_day          = 31'd86400;      //86400
parameter time_4hour        = 31'd14400;      //4*60*60
parameter time_hour         = 31'd3600;       //60*60
parameter time_15minute     = 31'd900;        //15*60
parameter time_minute       = 31'd60;         //60
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
reg [3:0] counter;
reg [30:0] in_time_reg;

reg leap;

reg [10:0] year;
reg [3:0]  month;
reg [4:0]  day;
reg [4:0]  hour;
reg [5:0]  minute;
reg [5:0]  second;

wire [10:0] temp_year;
wire [3:0]  temp_month;
wire [2:0]  week;

reg  [10:0] Binary_code;
wire [15:0] BCD_code;

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
assign temp_year =  (month < 3)? year-1 : year;
assign temp_month = (month < 3)? month + 12 : month;
assign week = (day + 2*temp_month + 3*(temp_month + 1)/5 + temp_year + temp_year/4 - temp_year/100 + temp_year/400 + 1) % 7;

B2BCD_IP #(11, 4) I_B2BCD_IP ( .Binary_code(Binary_code), .BCD_code(BCD_code) );
always @(*)begin
    case (counter)
        0 : Binary_code = year; 
        1 : Binary_code = year;
        2 : Binary_code = year;
        3 : Binary_code = year;
        4 : Binary_code = {7'b0, month};
        5 : Binary_code = {7'b0, month};
        6 : Binary_code = {6'b0, day};
        7 : Binary_code = {6'b0, day};
        8 : Binary_code = {6'b0, hour};
        9 : Binary_code = {6'b0, hour};
        10: Binary_code = {5'b0, minute};
        11: Binary_code = {5'b0, minute};
        12: Binary_code = {5'b0, second};
        13: Binary_code = {5'b0, second};  
    endcase
end

always @(*) begin
    leap = (year[1:0] == 2'b00)? 1: 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        in_time_reg <= 0;
    end
    else if(in_valid)begin
        in_time_reg <= in_time;
    end
    else if(next_state == CAL_16YEAR)begin
        in_time_reg <= (in_time_reg < time_16years)? in_time_reg : in_time_reg - time_16years;
    end
    else if(next_state == CAL_4YEAR)begin
        in_time_reg <= (in_time_reg < time_4years)? in_time_reg : in_time_reg - time_4years;
    end
    else if(next_state == CAL_YEAR)begin
        if(leap)
            in_time_reg <= (in_time_reg < time_leap_years)? in_time_reg : in_time_reg - time_leap_years;
        else
            in_time_reg <= (in_time_reg < time_common_years)? in_time_reg : in_time_reg - time_common_years;
    end
    else if(next_state == CAL_MONTH)begin
        if(month == 2 && leap) 
            in_time_reg <= (in_time_reg < time_leap_month)? in_time_reg: in_time_reg - time_leap_month;
        else if(month == 2 && !leap) 
            in_time_reg <= (in_time_reg < time_com_month)? in_time_reg: in_time_reg - time_com_month;
        else if(month == 1 || month == 3 || month == 5  || month == 7 || month == 8 || month == 10 || month == 12) 
            in_time_reg <= (in_time_reg < time_odd_month)? in_time_reg: in_time_reg - time_odd_month;
        else 
            in_time_reg <= (in_time_reg < time_even_month)? in_time_reg: in_time_reg - time_even_month;
    end

    else if(next_state == CAL_DAY)begin
        in_time_reg <= (in_time_reg < time_day)? in_time_reg: in_time_reg - time_day;
    end
    else if(next_state == CAL_4HOUR)begin
        in_time_reg <= (in_time_reg < time_4hour)? in_time_reg: in_time_reg - time_4hour;
    end
    else if(next_state == CAL_HOUR)begin
        in_time_reg <= (in_time_reg < time_hour)? in_time_reg: in_time_reg - time_hour;
    end
    else if(next_state == CAL_15MIN)begin
        in_time_reg <= (in_time_reg < time_15minute)? in_time_reg: in_time_reg - time_15minute;
    end
    else if(next_state == CAL_MIN)begin
        in_time_reg <= (in_time_reg < time_minute)? in_time_reg: in_time_reg - time_minute;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        year <= 'd1970;
    end
    else if(next_state == CAL_16YEAR)begin
        year <= (in_time_reg < time_16years)? year: year + 'd16;
    end
    else if(next_state == CAL_4YEAR)begin
        year <= (in_time_reg < time_4years)? year: year + 'd4;
    end
    else if(next_state == CAL_YEAR)begin
        if(leap)
            year <= (in_time_reg < time_leap_years)? year: year + 'd1;
        else
            year <= (in_time_reg < time_common_years)? year: year + 'd1;
    end
    else if(next_state == IDLE)begin
        year <= 'd1970;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        month <= 'd1;
    end
    else if(next_state == CAL_MONTH)begin
        if(month == 2 && leap) 
            month <= (in_time_reg < time_leap_month)? month: month + 'd1;
        else if(month == 2 && !leap) 
            month <= (in_time_reg < time_com_month)? month: month + 'd1;
        else if(month == 1 || month == 3 || month == 5  || month == 7 || month == 8 || month == 10 || month == 12)
            month <= (in_time_reg < time_odd_month)? month: month + 'd1;
        else 
            month <= (in_time_reg < time_even_month)? month: month + 'd1;
    end
    else if(next_state == IDLE)begin
        month <= 'd1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        day <= 'd1;
    end
    else if(next_state == CAL_DAY)begin
        day <= (in_time_reg < time_day)? day : day + 'd1;
    end
    else if(next_state == IDLE)begin
        day <= 'd1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        hour <= 'd0;
    end
    else if(next_state == CAL_4HOUR)begin
        hour <= (in_time_reg < time_4hour)? hour : hour + 'd4;
    end
    else if(next_state == CAL_HOUR)begin
        hour <= (in_time_reg < time_hour)? hour : hour + 'd1;
    end
    else if(next_state == IDLE)begin
        hour <= 'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        minute <= 'd0;
    end
    else if(next_state == CAL_15MIN)begin
        minute <= (in_time_reg < time_15minute)? minute : minute + 'd15;
    end
    else if(next_state == CAL_MIN)begin
        minute <= (in_time_reg < time_minute)? minute : minute + 'd1;
    end
    else if(next_state == IDLE)begin
        minute <= 'd0;
    end
end

always @(*)begin
    second = in_time_reg[5:0];
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        counter <= 'd0;
    end
    else if(next_state == OUT)begin
        counter <= counter + 1;
    end
    else if(next_state == IDLE)begin
        counter <= 'd0;
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
            next_state = (!in_valid)? IDLE : INPUT;
        INPUT:
            next_state = CAL_16YEAR;
        CAL_16YEAR:
            next_state = (in_time_reg < time_16years)? CAL_4YEAR : CAL_16YEAR;
        CAL_4YEAR:
            next_state = (in_time_reg < time_4years)? CAL_YEAR : CAL_4YEAR;
        CAL_YEAR:begin
            if(leap) 
                next_state = (in_time_reg < time_leap_years)? CAL_MONTH : CAL_YEAR;
            else 
                next_state = (in_time_reg < time_common_years)? CAL_MONTH : CAL_YEAR;
        end
        CAL_MONTH:begin
            if(month == 2 && leap) 
                next_state = (in_time_reg < time_leap_month)? CAL_DAY : CAL_MONTH;
            else if(month == 2 && !leap) 
                next_state = (in_time_reg < time_com_month)? CAL_DAY : CAL_MONTH;
            else if(month == 1 || month == 3 || month == 5  || month == 7 || month == 8 || month == 10 || month == 12) 
                next_state = (in_time_reg < time_odd_month)? CAL_DAY : CAL_MONTH;
            else 
                next_state = (in_time_reg < time_even_month)? CAL_DAY : CAL_MONTH;
        end 
        CAL_DAY:
            next_state = (in_time_reg < time_day)? CAL_4HOUR : CAL_DAY;  
        CAL_4HOUR:
            next_state = (in_time_reg < time_4hour)? CAL_HOUR : CAL_4HOUR;
        CAL_HOUR:
            next_state = (in_time_reg < time_hour)? CAL_15MIN : CAL_HOUR;
        CAL_15MIN:
            next_state = (in_time_reg < time_15minute)? CAL_MIN : CAL_15MIN;
        CAL_MIN:
            next_state = (in_time_reg < time_minute)? OUT : CAL_MIN;
        OUT:
            next_state = (counter == 14)? IDLE : OUT;
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
    else if(next_state == OUT) out_valid <= 'd1;
	else out_valid <= 'd0; 
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) out_display <= 'd0;
    else if(next_state == OUT)begin
        case (counter)
            0 : out_display <= BCD_code[15:12];
            1 : out_display <= BCD_code[11:8];
            2 : out_display <= BCD_code[7:4];
            3 : out_display <= BCD_code[3:0];
            4 : out_display <= BCD_code[7:4];
            5 : out_display <= BCD_code[3:0];
            6 : out_display <= BCD_code[7:4];
            7 : out_display <= BCD_code[3:0];
            8 : out_display <= BCD_code[7:4];
            9 : out_display <= BCD_code[3:0];
            10: out_display <= BCD_code[7:4];
            11: out_display <= BCD_code[3:0];
            12: out_display <= BCD_code[7:4];
            13: out_display <= BCD_code[3:0];
        endcase
    end 
	else out_display <= 'd0;
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) out_day <= 'd0;
    else if(next_state == OUT) out_day <= week;
	else out_day <= 'd0;
end

endmodule

