module FD(input clk, INF.FD_inf inf);
import usertype::*;

//===========================================================================
// parameter 
//===========================================================================

//===========================================================================
// logic 
//===========================================================================
State current_state, next_state;

Delivery_man_id	 d_man_id;
Action		     action;
Ctm_Info         cus_info;
Restaurant_id	 res_id;
food_ID_servings food;

res_info res_id_info;  // total_food & food_num(max 255)*3
D_man_Info man_info;               // Ctm_Info & Ctm_Info

logic info_switch;
logic bridge_busy;
logic res_info_request, man_info_request;
logic [31:0] res_temp_data, man_temp_data;

logic [8:0] total_food;
//================================================================
// AXI 
//================================================================

// bridge_busy
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)		     bridge_busy <= 0;
    else if(inf.C_in_valid)  bridge_busy <= 1;
    else if(inf.C_out_valid) bridge_busy <= 0;
end


// inf.C_addr
always_comb begin
    if(info_switch == 0)begin
        inf.C_addr = res_id;
    end
    else if(info_switch == 1)begin
        inf.C_addr = d_man_id;
    end   
end


// inf.C_r_wb
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)	inf.C_r_wb <= 0 ;
    else if (current_state == IDLE) inf.C_r_wb <= 1;
    else if (current_state == EXE)  inf.C_r_wb <= 0 ;
end


// inf.C_in_valid
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) inf.C_in_valid <= 0 ;
    else if(!bridge_busy && !inf.C_in_valid)begin
        if(res_info_request || man_info_request) inf.C_in_valid <= 1;
        else inf.C_in_valid <= 0;
    end
    else inf.C_in_valid <= 0;
end


// res_info_request
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)	                                                     res_info_request <= 0;
    else if((inf.res_valid && action == Order) || inf.cus_valid)         res_info_request <= 1;
    else if(info_switch == 0 && inf.C_out_valid)                         res_info_request <= 0;
    else if(current_state == EXE && (action == Take || action == Order)) res_info_request <= 1;
end


// man_info_request
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)	                             man_info_request <= 0;
    else if(inf.id_valid)                        man_info_request <= 1;
    else if(info_switch == 1 && inf.C_out_valid) man_info_request <= 0;
    else if(current_state == EXE && (action == Take || action == Deliver || action == Cancel)) man_info_request <= 1;
end


// info_switch
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)		                      info_switch <= 0;
    else if(res_info_request && !bridge_busy) info_switch <= 0;
    else if(man_info_request && !bridge_busy) info_switch <= 1;
end


// inf.C_data_w
always_comb begin
    if(action == Take && res_id == d_man_id)begin
        inf.C_data_w[7:0]                          = res_id_info.limit_num_orders;
        inf.C_data_w[15:8]                         = res_id_info.ser_FOOD1;
        inf.C_data_w[23:16]                        = res_id_info.ser_FOOD2;
        inf.C_data_w[31:24]                        = res_id_info.ser_FOOD3;
        inf.C_data_w[39:38]                        = man_info.ctm_info1.ctm_status;
        {inf.C_data_w[37:32], inf.C_data_w[47:46]} = man_info.ctm_info1.res_ID; 
        inf.C_data_w[45:44]                        = man_info.ctm_info1.food_ID;
        inf.C_data_w[43:40]                        = man_info.ctm_info1.ser_food; 
        inf.C_data_w[55:54]                        = man_info.ctm_info2.ctm_status;
        {inf.C_data_w[53:48], inf.C_data_w[63:62]} = man_info.ctm_info2.res_ID;
        inf.C_data_w[61:60]                        = man_info.ctm_info2.food_ID;
        inf.C_data_w[59:56]                        = man_info.ctm_info2.ser_food;
    end
    else begin
    if(info_switch == 0)begin
        inf.C_data_w[7:0]   = res_id_info.limit_num_orders;
        inf.C_data_w[15:8]  = res_id_info.ser_FOOD1;
        inf.C_data_w[23:16] = res_id_info.ser_FOOD2;
        inf.C_data_w[31:24] = res_id_info.ser_FOOD3;
        inf.C_data_w[63:32] = res_temp_data;
    end
    else begin
        inf.C_data_w[39:38]                        = man_info.ctm_info1.ctm_status;
        {inf.C_data_w[37:32], inf.C_data_w[47:46]} = man_info.ctm_info1.res_ID; 
        inf.C_data_w[45:44]                        = man_info.ctm_info1.food_ID;
        inf.C_data_w[43:40]                        = man_info.ctm_info1.ser_food; 
        inf.C_data_w[55:54]                        = man_info.ctm_info2.ctm_status;
        {inf.C_data_w[53:48], inf.C_data_w[63:62]} = man_info.ctm_info2.res_ID;
        inf.C_data_w[61:60]                        = man_info.ctm_info2.food_ID;
        inf.C_data_w[59:56]                        = man_info.ctm_info2.ser_food;
        inf.C_data_w[31:0]                         = man_temp_data;
    end
    end
end

//================================================================
// Design
//================================================================

// res_temp_data
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) res_temp_data <= 0;
    else if (inf.C_out_valid && inf.C_r_wb && !info_switch)begin
        res_temp_data <= inf.C_data_r[63:32];
    end
    else if(inf.C_out_valid && !inf.C_r_wb && !info_switch)begin
        res_temp_data <= inf.C_data_w[63:32];
    end
end

// man_temp_data
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) man_temp_data <= 0;
    else if (inf.C_out_valid && inf.C_r_wb && info_switch)begin
        man_temp_data <= inf.C_data_r[31:0];
    end
    else if(inf.C_out_valid && !inf.C_r_wb && info_switch)begin
        man_temp_data <= inf.C_data_w[31:0];
    end
end

// man_info.ctm_info
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) man_info <= 0 ;
    else if (inf.C_out_valid && inf.C_r_wb && info_switch)begin
        man_info.ctm_info1.ctm_status <= inf.C_data_r[39:38];
        man_info.ctm_info1.res_ID     <= {inf.C_data_r[37:32], inf.C_data_r[47:46]};
        man_info.ctm_info1.food_ID    <= inf.C_data_r[45:44];
        man_info.ctm_info1.ser_food   <= inf.C_data_r[43:40];
        man_info.ctm_info2.ctm_status <= inf.C_data_r[55:54];
        man_info.ctm_info2.res_ID     <= {inf.C_data_r[53:48], inf.C_data_r[63:62]};
        man_info.ctm_info2.food_ID    <= inf.C_data_r[61:60];
        man_info.ctm_info2.ser_food   <= inf.C_data_r[59:56];
    end
    else if(next_state == EXE)begin
        case (action)
        Take:begin
            if(man_info.ctm_info1.ctm_status == None)begin
                man_info.ctm_info1 <= cus_info;
            end
            else begin
                if(cus_info.ctm_status == VIP && man_info.ctm_info1.ctm_status == Normal)begin
                    man_info.ctm_info1 <= cus_info;
                    man_info.ctm_info2 <= man_info.ctm_info1;
                end
                else begin
                    man_info.ctm_info2 <= cus_info;
                end
            end
        end 
        Deliver:begin
            man_info.ctm_info1 <= man_info.ctm_info2;
            man_info.ctm_info2 <= 0;
        end
        Order:begin
            // info no change
        end
        Cancel:begin
            // cancel cus 1 & 2
            if(man_info.ctm_info1.res_ID == res_id && man_info.ctm_info1.food_ID == food.d_food_ID &&
               man_info.ctm_info2.res_ID == res_id && man_info.ctm_info2.food_ID == food.d_food_ID )begin
                man_info.ctm_info1 <= 0;
                man_info.ctm_info2 <= 0;
            end
            // cancel cus 1
            else if(man_info.ctm_info1.res_ID == res_id && man_info.ctm_info1.food_ID == food.d_food_ID)begin
                man_info.ctm_info1 <= man_info.ctm_info2;
                man_info.ctm_info2 <= 0;
            end
            // cancel cus 2
            else begin
                man_info.ctm_info2 <= 0;
            end
        end
        endcase
    end
end


// res_id_info
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) res_id_info <= 0 ;
    else if (inf.C_out_valid && inf.C_r_wb && !info_switch)begin
        res_id_info.limit_num_orders <= inf.C_data_r[7:0];
        res_id_info.ser_FOOD1        <= inf.C_data_r[15:8];
        res_id_info.ser_FOOD2        <= inf.C_data_r[23:16];
        res_id_info.ser_FOOD3        <= inf.C_data_r[31:24];
    end
    else if(next_state == EXE)begin
        case (action)
        Take:begin
            case (cus_info.food_ID)
            FOOD1: res_id_info.ser_FOOD1 <= res_id_info.ser_FOOD1 - cus_info.ser_food;
            FOOD2: res_id_info.ser_FOOD2 <= res_id_info.ser_FOOD2 - cus_info.ser_food;
            FOOD3: res_id_info.ser_FOOD3 <= res_id_info.ser_FOOD3 - cus_info.ser_food;
            endcase
        end 
        Deliver:begin
            // info no change
        end
        Order:begin
            case (food.d_food_ID)
            FOOD1: res_id_info.ser_FOOD1 <= res_id_info.ser_FOOD1 + food.d_ser_food;
            FOOD2: res_id_info.ser_FOOD2 <= res_id_info.ser_FOOD2 + food.d_ser_food;
            FOOD3: res_id_info.ser_FOOD3 <= res_id_info.ser_FOOD3 + food.d_ser_food;
            endcase
        end
        Cancel:begin
            // info no change
        end
        endcase
    end
end

//================================================================
// Input valid 
//================================================================
// d_man_id
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)	       d_man_id <= 0 ;
    else if (inf.id_valid) d_man_id <= inf.D.d_id[0];
end

// action
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)	        action <= No_action ;
    else if (inf.act_valid) action <= inf.D.d_act[0];
end

// cus_information
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)	        cus_info <= 0 ;
    else if (inf.cus_valid) cus_info <= inf.D.d_ctm_info[0];
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)	        res_id <= 0 ;
    else if (inf.res_valid) res_id <= inf.D.d_res_id[0];
    else if (inf.cus_valid) res_id <= inf.D.d_ctm_info[0].res_ID;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)	         food <= 0 ;
    else if (inf.food_valid) food <= inf.D.d_food_ID_ser[0];
end

//================================================================
// Finite State Machine 
//================================================================
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)		current_state <= IDLE ;
    else 				current_state <= next_state ;
end

always_comb begin
    if (!inf.rst_n)	next_state = IDLE;
    else begin
        case (current_state)
            IDLE: begin
                if(inf.act_valid) next_state = GET_ACT;
                else next_state = IDLE; 
            end 
            GET_ACT: begin
                if(action == Take && inf.cus_valid) next_state = WAIT;
                else if(action == Deliver && inf.id_valid) next_state = WAIT;
                else if(action == Order && inf.food_valid) next_state = WAIT;
                // else if(action == Order && inf.food_valid) next_state = (res_info_request)? WAIT : EXE;
                else if(action == Cancel && inf.id_valid) next_state = WAIT;
                else next_state = GET_ACT;
            end
            WAIT: begin
                if(!res_info_request && !man_info_request) next_state = CHECK_ERR;
                else next_state = WAIT;
            end
            CHECK_ERR: begin
                if (inf.err_msg != No_Err) next_state = OUT;
                else next_state = EXE;
                // else next_state = CHECK_ERR;
            end
            EXE: next_state = WRITE_B;
            WRITE_B: next_state = (!res_info_request && !man_info_request)? OUT : WRITE_B;
            OUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
end
//================================================================
// Output Logic 
//================================================================
assign total_food = res_id_info.ser_FOOD1 + res_id_info.ser_FOOD2 + res_id_info.ser_FOOD3 + food.d_ser_food;

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) inf.err_msg <= No_Err ;
    else if(next_state == CHECK_ERR)begin
        case (action)
        Take:begin
            if(man_info.ctm_info2.ctm_status != None)begin
                inf.err_msg <= D_man_busy;
            end
            else begin
                case (cus_info.food_ID)
                FOOD1: begin
                    if(res_id_info.ser_FOOD1 < cus_info.ser_food)begin
                        inf.err_msg <= No_Food; 
                    end
                    else begin
                        inf.err_msg <= No_Err;
                    end
                end
                FOOD2: begin
                    if(res_id_info.ser_FOOD2 < cus_info.ser_food)begin
                        inf.err_msg <= No_Food; 
                    end
                    else begin
                        inf.err_msg <= No_Err;
                    end
                end
                FOOD3: begin
                    if(res_id_info.ser_FOOD3 < cus_info.ser_food)begin
                        inf.err_msg <= No_Food; 
                    end
                    else begin
                        inf.err_msg <= No_Err;
                    end
                end
                endcase
            end
        end 
        Deliver:begin
            if(man_info.ctm_info1.ctm_status == None)begin
                inf.err_msg <= No_customers;
            end
            else begin
                inf.err_msg <= No_Err;
            end
        end
        Order:begin
            if(res_id_info.limit_num_orders < total_food)begin
                inf.err_msg <= Res_busy;
            end
            else begin
                inf.err_msg <= No_Err;
            end
        end
        Cancel:begin
           if(man_info.ctm_info1.ctm_status == None)begin
                inf.err_msg <= Wrong_cancel; 
            end
            else begin
                if(man_info.ctm_info2.ctm_status == None)begin
                    if(man_info.ctm_info1.res_ID != res_id)begin
                        inf.err_msg <= Wrong_res_ID;
                    end
                    else begin
                        if(man_info.ctm_info1.res_ID == res_id && man_info.ctm_info1.food_ID == food.d_food_ID)begin
                            inf.err_msg <= No_Err;
                        end
                        else inf.err_msg <= Wrong_food_ID;
                    end
                end
                else begin
                    if(man_info.ctm_info1.res_ID != res_id && man_info.ctm_info2.res_ID != res_id)begin
                        inf.err_msg <= Wrong_res_ID;
                    end
                    else begin
                        if(man_info.ctm_info1.res_ID == res_id && man_info.ctm_info1.food_ID == food.d_food_ID)begin
                            inf.err_msg <= No_Err;
                        end
                        else if(man_info.ctm_info2.res_ID == res_id && man_info.ctm_info2.food_ID == food.d_food_ID)begin
                            inf.err_msg <= No_Err;
                        end 
                        else inf.err_msg <= Wrong_food_ID;
                    end
                end
            end
        end
        default: inf.err_msg <= No_Err ;
        endcase
    end
    else if(current_state == IDLE) inf.err_msg <= No_Err ;
end

// inf.complete
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) inf.complete <= 0 ;
    else if(inf.err_msg == No_Err) inf.complete <= 1;
    else inf.complete <= 0;
end

// inf.out_valid
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) inf.out_valid <= 0 ;
    else if(next_state == OUT) inf.out_valid <= 1;
    else inf.out_valid <= 0;
end

// inf.out_info
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) inf.out_info <= 0 ;
    else if(next_state == OUT && inf.err_msg == No_Err)begin
        case (action)
        Take:    inf.out_info <= {man_info , res_id_info};
        Deliver: inf.out_info <= {man_info , 32'd0};
        Order:   inf.out_info <= {32'd0 , res_id_info};
        Cancel:  inf.out_info <= {man_info , 32'd0};
        endcase
    end
    else inf.out_info <= 0 ;
end
endmodule