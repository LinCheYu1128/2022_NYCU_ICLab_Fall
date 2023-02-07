`include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype_FD.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
// parameters & integer
//================================================================
integer i, j;
integer i_pat, latency, total_latency;
integer hit;

parameter SEED   = 100;
parameter PATNUM = 5000;
parameter base_addr = 65536;
parameter DRAM_path = "../00_TESTBED/DRAM/dram.dat";


//================================================================
// wire & registers 
//================================================================
logic [7:0 ] golden_DRAM [base_addr:(base_addr+ (256*8) -1)];
logic [63:0] golden_out_info;

logic             golden_complete;
Action            golden_act;
Delivery_man_id   golden_d_id;
D_man_Info        golden_cur_d_man_info;
Restaurant_id     golden_res_id;
res_info          golden_res_info;
servings_of_food  golden_food_num;
servings_of_FOOD  golden_FOOD_num;
limit_of_orders   golden_limit_of_orders;
Customer_status   golden_cus_status;
Food_id           golden_food_id;
Error_Msg         golden_err_msg;


//================================================================
// random class 
//================================================================
class rand_hit;
    rand int hit;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {hit inside {[1:3]};}
endclass

class rand_gap;
    rand int gap;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {gap inside {[1:5]};}
endclass

class rand_delay;
    rand int delay;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {delay inside {[2:10]};}
endclass

class rand_action;
    rand Action action;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {action inside {Take, Deliver, Order, Cancel};}
endclass

class rand_cus_status;
    rand Customer_status cus_status;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {cus_status inside {Normal, VIP};}
endclass

class rand_food_id;
    rand Food_id food_id;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {food_id inside {FOOD1, FOOD2, FOOD3};}
endclass

class rand_d_id;
    rand Delivery_man_id d_id;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {d_id inside {[0:255]};}
endclass

class rand_r_id;
    rand Restaurant_id r_id;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {r_id inside {[0:255]};}
endclass

class rand_food_num;
    rand servings_of_food food_num;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit {food_num inside {[1:15]};}
endclass

rand_gap r_gap = new(SEED);
rand_hit r_hit = new(SEED);
rand_delay r_delay = new(SEED);
rand_action r_action = new(SEED);
rand_cus_status r_cus_status = new(SEED);
rand_food_id r_food_id = new(SEED);
rand_d_id r_d_id = new(SEED);
rand_r_id r_r_id = new(SEED);
rand_food_num r_food_num = new(SEED);

//================================================================
// initial
//================================================================
initial begin
    $readmemh(DRAM_path, golden_DRAM);
    latency = 0;
    total_latency = 0;
    reset_task;
    i_pat = 0;
    // for(i_pat = 0; i_pat < PATNUM; i_pat = i_pat + 1)begin
    for(j = 0 ; j < 256; j = j + 1)begin 
        golden_d_id = j;
        for(i = 0; i < 2; i = i+1)begin
           gap_task;
            // r_action.randomize();
            // golden_act = r_action.action;
            if     (i_pat % 16 ==  0) golden_act = Take;
            else if(i_pat % 16 ==  1) golden_act = Take;
            else if(i_pat % 16 ==  2) golden_act = Order;
            else if(i_pat % 16 ==  3) golden_act = Take;
            else if(i_pat % 16 ==  4) golden_act = Deliver;
            else if(i_pat % 16 ==  5) golden_act = Take;
            else if(i_pat % 16 ==  6) golden_act = Cancel;
            else if(i_pat % 16 ==  7) golden_act = Order;
            else if(i_pat % 16 ==  8) golden_act = Order;
            else if(i_pat % 16 ==  9) golden_act = Deliver;
            else if(i_pat % 16 == 10) golden_act = Order;
            else if(i_pat % 16 == 11) golden_act = Cancel;
            else if(i_pat % 16 == 12) golden_act = Deliver;
            else if(i_pat % 16 == 13) golden_act = Deliver;
            else if(i_pat % 16 == 14) golden_act = Cancel;
            else if(i_pat % 16 == 15) golden_act = Cancel;

            case(golden_act)
                Take: begin
                    input_take_task;
                    compute_take_task;
                end
                Deliver: begin
                    input_deliver_task;
                    compute_deliver_task;
                end
                Order: begin
                    input_order_task;
                    compute_order_task;
                end
                Cancel: begin
                    input_cancel_task;
                    compute_cancel_task;
                end
            endcase
            wait_out_valid_task;
            check_output_task;
            $display("\033[0;36mPASS PATTERN NO. %4d,\033[m \033[0;32mAction : %3d,\033[m \033[0;39;2mexecution cycle : %3d\033[m",i_pat ,golden_act ,latency);
            total_latency = total_latency + latency;
            delay_task;
            i_pat = i_pat + 1; 
        end
    end
    YOU_PASS_task;
end

task reset_task; begin
    inf.rst_n = 1'b1;
    inf.id_valid = 1'b0;
    inf.act_valid = 1'b0;
    inf.res_valid = 1'b0;
    inf.cus_valid = 1'b0;
    inf.food_valid = 1'b0;
    inf.D = 'bx;

    #8; inf.rst_n = 0;
    #8; inf.rst_n = 1;
    if(inf.out_valid!==1'b0 || inf.err_msg !== 'd0 || inf.complete !== 1'b0 || inf.out_info !== 'd0)begin
        $display("************************************************************");   
        $display("                          FAIL!                              ");   
        $display("*  Output signal should be 0 after initial RESET  at %8t   *",$time);
        $display("************************************************************");
        $finish;
    end    
end endtask

task delay_task; begin
    r_delay.randomize();
    repeat(r_delay.delay) @(negedge clk);
end endtask

task gap_task;begin
    r_gap.randomize();
    repeat(r_gap.gap) @(negedge clk);
end endtask

task input_take_task;begin
    // r_d_id.randomize();
    // golden_d_id = r_d_id.d_id;
    r_cus_status.randomize();
    golden_cus_status = r_cus_status.cus_status;
    r_r_id.randomize();
    golden_res_id = r_r_id.r_id;
    r_food_id.randomize();
    golden_food_id = r_food_id.food_id;
    r_food_num.randomize();
    golden_food_num = r_food_num.food_num;

    inf.act_valid = 1'b1;
    inf.D.d_act = golden_act;
    @(negedge clk);
    inf.act_valid = 1'b0;
    inf.D = 'bx;

    gap_task;

    inf.id_valid = 1'b1;
    inf.D.d_id = golden_d_id;
    @(negedge clk);
    inf.id_valid = 1'b0;
    inf.D = 'bx;

    gap_task;

    inf.cus_valid = 1'b1;
    // inf.D.d_ctm_info.ctm_status = golden_cus_status;
    // inf.D.d_ctm_info.res_ID = golden_res_id;
    // inf.D.d_ctm_info.food_ID = golden_food_id;
    // inf.D.d_ctm_info.ser_food = golden_food_num;
    inf.D.d_ctm_info = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
    @(negedge clk);
    inf.cus_valid = 1'b0;
    inf.D = 'bx;
end endtask

task input_deliver_task; begin
    // r_d_id.randomize();
    // golden_d_id = r_d_id.d_id;

    inf.act_valid = 1'b1;
    inf.D.d_act = golden_act;
    @(negedge clk);
    inf.act_valid = 1'b0;
    inf.D = 'bx;

    gap_task;

    inf.id_valid = 1'b1;
    inf.D.d_id = golden_d_id;
    @(negedge clk);
    inf.id_valid = 1'b0;
    inf.D = 'bx;
end endtask

task input_order_task; begin
    r_r_id.randomize();
    golden_res_id = r_r_id.r_id;
    r_food_id.randomize();
    golden_food_id = r_food_id.food_id;
    r_food_num.randomize();
    golden_food_num = r_food_num.food_num;

    inf.act_valid = 1'b1;
    inf.D.d_act = golden_act;
    @(negedge clk);
    inf.act_valid = 1'b0;
    inf.D = 'bx;

    gap_task;

    inf.res_valid = 1'b1;
    inf.D.d_res_id = golden_res_id;
    @(negedge clk);
    inf.res_valid = 1'b0;
    inf.D = 'bx;

    gap_task;

    inf.food_valid = 1'b1;
    // inf.D.food_ID_ser.d_food_ID = golden_food_id;
    // inf.D.food_ID_ser.d_ser_food = golden_food_num;
    inf.D.d_food_ID_ser = {golden_food_id, golden_food_num};
    @(negedge clk);
    inf.food_valid = 1'b0;
    inf.D = 'bx;
end endtask

task input_cancel_task; begin
    // r_r_id.randomize();
    // golden_res_id = r_r_id.r_id;
    // r_food_id.randomize();
    // golden_food_id = r_food_id.food_id;
    golden_cur_d_man_info = {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5], golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]};
    r_hit.randomize();
    hit = r_hit.hit;
    if(hit == 1)begin // hit wrong cancel
        r_r_id.randomize();
        golden_res_id = r_r_id.r_id;
        r_food_id.randomize();
        golden_food_id = r_food_id.food_id; 
    end
    // else if(hit == 2)begin // hit wrong res id
    //     r_r_id.randomize();
    //     golden_res_id = r_r_id.r_id;
    //     r_food_id.randomize();
    //     golden_food_id = r_food_id.food_id; 
    // end
    else begin
        golden_res_id = golden_cur_d_man_info.ctm_info1.res_ID;
        r_food_id.randomize();
        golden_food_id = r_food_id.food_id; 
    end
    // r_d_id.randomize();
    // golden_d_id = r_d_id.d_id;
    r_food_num.randomize();
    golden_food_num = r_food_num.food_num;

    inf.act_valid = 1'b1;
    inf.D.d_act = golden_act;
    @(negedge clk);
    inf.act_valid = 1'b0;
    inf.D = 'bx;

    gap_task;

    inf.res_valid = 1'b1;
    inf.D.d_res_id = golden_res_id;
    @(negedge clk);
    inf.res_valid = 1'b0;
    inf.D = 'bx;

    gap_task;

    inf.food_valid = 1'b1;
    // inf.D.d_food_ID_ser.d_food_ID = golden_food_id;
    // inf.D.d_food_ID_ser.d_ser_food = 'b0;
    inf.D.d_food_ID_ser = {golden_food_id, 4'd0};
    @(negedge clk);
    inf.food_valid = 1'b0;
    inf.D = 'bx;

    gap_task;

    inf.id_valid = 1'b1;
    inf.D.d_id = golden_d_id;
    @(negedge clk);
    inf.id_valid = 1'b0;
    inf.D = 'bx;
end endtask

task compute_take_task; begin
    golden_res_info = {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]};
    golden_cur_d_man_info = {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5], golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]};
    if(golden_cur_d_man_info.ctm_info1.ctm_status!=None && golden_cur_d_man_info.ctm_info2.ctm_status!=None)begin
        golden_complete = 1'b0;
        golden_out_info = 'd0;
        golden_err_msg = D_man_busy;
    end
    else begin
        if(golden_food_id==FOOD1 && golden_res_info.ser_FOOD1>=golden_food_num)begin //check food enough?
            if(golden_cus_status == VIP)begin //VIP
                if(golden_cur_d_man_info.ctm_info1.ctm_status==Normal && golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = golden_cur_d_man_info.ctm_info1;
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD1 = golden_res_info.ser_FOOD1-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else if(golden_cur_d_man_info.ctm_info1.ctm_status==VIP && golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD1 = golden_res_info.ser_FOOD1-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else begin
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD1 = golden_res_info.ser_FOOD1-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
            end
            else begin
                if(golden_cur_d_man_info.ctm_info1.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD1 = golden_res_info.ser_FOOD1-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else if(golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD1 = golden_res_info.ser_FOOD1-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else begin
                    golden_complete = 1'b0;
                    golden_out_info = 'd0;
                    golden_err_msg = D_man_busy;
                end
            end
        end
        else if(golden_food_id==FOOD2 && golden_res_info.ser_FOOD2>=golden_food_num)begin
            if(golden_cus_status == VIP)begin //VIP
                if(golden_cur_d_man_info.ctm_info1.ctm_status==Normal && golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = golden_cur_d_man_info.ctm_info1;
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD2 = golden_res_info.ser_FOOD2-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else if(golden_cur_d_man_info.ctm_info1.ctm_status==VIP && golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD2 = golden_res_info.ser_FOOD2-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else begin
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD2 = golden_res_info.ser_FOOD2-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
            end
            else begin
                if(golden_cur_d_man_info.ctm_info1.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD2 = golden_res_info.ser_FOOD2-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else if(golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD2 = golden_res_info.ser_FOOD2-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else begin
                    golden_complete = 1'b0;
                    golden_out_info = 'd0;
                    golden_err_msg = D_man_busy;
                end
            end
        end
        else if(golden_food_id==FOOD3 && golden_res_info.ser_FOOD3>=golden_food_num)begin
            if(golden_cus_status == VIP)begin //VIP
                if(golden_cur_d_man_info.ctm_info1.ctm_status==Normal && golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = golden_cur_d_man_info.ctm_info1;
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD3 = golden_res_info.ser_FOOD3-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else if(golden_cur_d_man_info.ctm_info1.ctm_status==VIP && golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD3 = golden_res_info.ser_FOOD3-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else begin
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD3 = golden_res_info.ser_FOOD3-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
            end
            else begin
                if(golden_cur_d_man_info.ctm_info1.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info1 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD3 = golden_res_info.ser_FOOD3-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else if(golden_cur_d_man_info.ctm_info2.ctm_status==None)begin
                    golden_cur_d_man_info.ctm_info2 = {golden_cus_status, golden_res_id, golden_food_id, golden_food_num};
                    golden_res_info.ser_FOOD3 = golden_res_info.ser_FOOD3-golden_food_num;
                    golden_complete = 1'b1;
                    golden_out_info = {golden_cur_d_man_info, golden_res_info};
                    golden_err_msg = No_Err;
                    {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
                    {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
                    {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
                end
                else begin
                    golden_complete = 1'b0;
                    golden_out_info = 'd0;
                    golden_err_msg = D_man_busy;
                end
            end
        end
        else begin //no food
            golden_complete = 1'b0;
            golden_out_info = 'd0;
            golden_err_msg = No_Food;
        end
    end
end endtask

task compute_deliver_task; begin
    golden_cur_d_man_info = {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5], golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]};
    if(golden_cur_d_man_info.ctm_info1.ctm_status[1:0] == None)begin //no customer
        golden_complete = 1'b0;
        golden_out_info = 'd0;
        golden_err_msg = No_customers;
    end
    else begin
        golden_cur_d_man_info.ctm_info1 = golden_cur_d_man_info.ctm_info2;
        golden_cur_d_man_info.ctm_info2 = 'd0;
        golden_complete = 1'b1;
        golden_out_info = {golden_cur_d_man_info, 32'd0};
        golden_err_msg = No_Err;
        {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
        {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
    end
end endtask

task compute_order_task; begin
    golden_res_info = {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]};
    if(golden_food_id==FOOD1)begin
        if(golden_res_info.limit_num_orders >= golden_res_info.ser_FOOD1+golden_res_info.ser_FOOD2+golden_res_info.ser_FOOD3+golden_food_num)begin
            golden_res_info.ser_FOOD1 = golden_res_info.ser_FOOD1 + golden_food_num;
            golden_complete = 1'b1; 
            golden_out_info = {32'd0, golden_res_info};
            golden_err_msg = No_Err;
            {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
        end
        else begin
            golden_complete = 1'b0;
            golden_err_msg = Res_busy;
            golden_out_info = 'd0;
        end
    end
    else if(golden_food_id==FOOD2)begin
        if(golden_res_info.limit_num_orders >= golden_res_info.ser_FOOD1+golden_res_info.ser_FOOD2+golden_res_info.ser_FOOD3+golden_food_num)begin
            golden_res_info.ser_FOOD2 = golden_res_info.ser_FOOD2 + golden_food_num;
            golden_complete = 1'b1; 
            golden_out_info = {32'd0, golden_res_info};
            golden_err_msg = No_Err;
            {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
        end
        else begin
            golden_complete = 1'b0;
            golden_err_msg = Res_busy;
            golden_out_info = 'd0;
        end
    end
    else if(golden_food_id==FOOD3)begin
        if(golden_res_info.limit_num_orders >= golden_res_info.ser_FOOD1+golden_res_info.ser_FOOD2+golden_res_info.ser_FOOD3+golden_food_num)begin
            golden_res_info.ser_FOOD3 = golden_res_info.ser_FOOD3 + golden_food_num;
            golden_complete = 1'b1;
            golden_out_info = {32'd0, golden_res_info};
            golden_err_msg = No_Err;
            {golden_DRAM[base_addr+golden_res_id*8], golden_DRAM[base_addr+golden_res_id*8+1], golden_DRAM[base_addr+golden_res_id*8+2], golden_DRAM[base_addr+golden_res_id*8+3]} = golden_res_info;
        end
        else begin
            golden_complete = 1'b0;
            golden_err_msg = Res_busy;
            golden_out_info = 'd0;
        end
    end
end endtask

task compute_cancel_task; begin
    golden_cur_d_man_info = {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5], golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]};
    // empty
     if(golden_cur_d_man_info.ctm_info1.ctm_status == None)begin
        golden_complete = 1'b0;
        golden_out_info = 'd0;
        golden_err_msg = Wrong_cancel;
    end
    else if(golden_cur_d_man_info.ctm_info1.res_ID == golden_res_id && golden_cur_d_man_info.ctm_info2.res_ID == golden_res_id)begin
        // cancel two info
        if(golden_cur_d_man_info.ctm_info1.food_ID == golden_food_id && golden_cur_d_man_info.ctm_info2.food_ID == golden_food_id)begin
            golden_cur_d_man_info = 'd0;
            golden_complete = 1'b1;
            golden_out_info = {golden_cur_d_man_info, 32'd0};
            golden_err_msg = No_Err;
            {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
            {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
        end
        // cancel ctm1 info
        else if(golden_cur_d_man_info.ctm_info1.food_ID == golden_food_id)begin
            golden_cur_d_man_info.ctm_info1 = golden_cur_d_man_info.ctm_info2;
            golden_cur_d_man_info.ctm_info2 = 'd0;
            golden_complete = 1'b1;
            golden_out_info = {golden_cur_d_man_info, 32'd0};
            golden_err_msg = No_Err;
            {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
            {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
        end
        // cancel ctm2 info
        else if(golden_cur_d_man_info.ctm_info2.food_ID == golden_food_id)begin
            golden_cur_d_man_info.ctm_info2 = 'd0;
            golden_complete = 1'b1;
            golden_out_info = {golden_cur_d_man_info, 32'd0};
            golden_err_msg = No_Err;
            {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
            {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
        end
        // Wrong_food_ID
        else begin
            golden_complete = 1'b0;
            golden_out_info = 'd0;
            golden_err_msg = Wrong_food_ID;
        end
    end
    // cancel info1
    else if(golden_cur_d_man_info.ctm_info1.res_ID == golden_res_id)begin
        if(golden_cur_d_man_info.ctm_info1.food_ID == golden_food_id)begin
            golden_cur_d_man_info.ctm_info1 = golden_cur_d_man_info.ctm_info2;
            golden_cur_d_man_info.ctm_info2 = 'd0;
            golden_complete = 1'b1;
            golden_out_info = {golden_cur_d_man_info, 32'd0};
            golden_err_msg = No_Err;
            {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
            {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
        end
        else begin
            golden_complete = 1'b0;
            golden_out_info = 'd0;
            golden_err_msg = Wrong_food_ID;
        end 
    end
    // ctm2 exist
    else if(golden_cur_d_man_info.ctm_info2.res_ID == golden_res_id)begin
        if(golden_cur_d_man_info.ctm_info2.food_ID == golden_food_id)begin
            golden_cur_d_man_info.ctm_info2 = 'd0;
            golden_complete = 1'b1;
            golden_out_info = {golden_cur_d_man_info, 32'd0};
            golden_err_msg = No_Err;
            {golden_DRAM[base_addr+golden_d_id*8+4], golden_DRAM[base_addr+golden_d_id*8+5]} = golden_cur_d_man_info.ctm_info1;
            {golden_DRAM[base_addr+golden_d_id*8+6], golden_DRAM[base_addr+golden_d_id*8+7]} = golden_cur_d_man_info.ctm_info2;
        end
        else begin
            golden_complete = 1'b0;
            golden_out_info = 'd0;
            golden_err_msg = Wrong_food_ID;
        end
    end
    else begin
        golden_complete = 1'b0;
        golden_out_info = 'd0;
        golden_err_msg = Wrong_res_ID;
    end
end endtask

task wait_out_valid_task; begin
    latency = 0;
    while(inf.out_valid !== 1'b1)begin
        latency = latency + 1;
        if(latency == 1200)begin
            $display("********************************************************");     
          	$display("                          FAIL!                              ");
          	$display("*  The execution latency are over 1200 cycles  at %8t   *",$time);//over max
          	$display("********************************************************");
			$finish;
        end
        @(negedge clk);
    end
end endtask

task check_output_task; begin
    if(inf.complete !== golden_complete)begin
        $display ("------------------------------------------------------------------------------------------------------------------------------------------");
        $display ("                                                                      FAIL!                                                               ");
        $display ("                                                                 Golden complete :          %d                                                   ",golden_complete); //show ans
        $display ("                                                                 Your complete :            %d                              ", inf.complete); //show output
        $display ("------------------------------------------------------------------------------------------------------------------------------------------");
        $finish;
    end
    if(inf.out_info !== golden_out_info)begin
        $display ("------------------------------------------------------------------------------------------------------------------------------------------");
        $display ("                                                                      FAIL!                                                               ");
        $display ("                                                                 Golden out_info :          %h                                                   ",golden_out_info); //show ans
        $display ("                                                                 Your out_info :            %h                              ", inf.out_info); //show output
        $display ("------------------------------------------------------------------------------------------------------------------------------------------");
        $finish;
    end
    if(inf.err_msg !== golden_err_msg)begin
        $display ("------------------------------------------------------------------------------------------------------------------------------------------");
        $display ("                                                                      FAIL!                                                               ");
        $display ("                                                                 Golden err_msg :          %d                                                   ",golden_err_msg); //show ans
        $display ("                                                                 Your err_msg :            %d                              ", inf.err_msg); //show output
        $display ("------------------------------------------------------------------------------------------------------------------------------------------");
        $finish;
    end
end endtask

task YOU_PASS_task;
    $display("                                                             \033[33m`-                                                                            ");        
    $display("                                                             /NN.                                                                           ");        
    $display("                                                            sMMM+                                                                           ");        
    $display(" .``                                                       sMMMMy                                                                           ");        
    $display(" oNNmhs+:-`                                               oMMMMMh                                                                           ");        
    $display("  /mMMMMMNNd/:-`                                         :+smMMMh                                                                           ");        
    $display("   .sNMMMMMN::://:-`                                    .o--:sNMy                                                                           ");        
    $display("     -yNMMMM:----::/:-.                                 o:----/mo                                                                           ");        
    $display("       -yNMMo--------://:.                             -+------+/                                                                           ");        
    $display("         .omd/::--------://:`                          o-------o.                                                                           ");        
    $display("           `/+o+//::-------:+:`                       .+-------y                                                                            ");        
    $display("              .:+++//::------:+/.---------.`          +:------/+                                                                            ");        
    $display("                 `-/+++/::----:/:::::::::::://:-.     o------:s.          \033[37m:::::----.           -::::.          `-:////:-`     `.:////:-.    \033[33m");        
    $display("                    `.:///+/------------------:::/:- `o-----:/o          \033[37m.NNNNNNNNNNds-       -NNNNNd`       -smNMMMMMMNy   .smNNMMMMMNh    \033[33m");        
    $display("                         :+:----------------------::/:s-----/s.          \033[37m.MMMMo++sdMMMN-     `mMMmMMMs      -NMMMh+///oys  `mMMMdo///oyy    \033[33m");        
    $display("                        :/---------------------------:++:--/++           \033[37m.MMMM.   `mMMMy     yMMM:dMMM/     +MMMM:      `  :MMMM+`     `    \033[33m");        
    $display("                       :/---///:-----------------------::-/+o`           \033[37m.MMMM.   -NMMMo    +MMMs -NMMm.    .mMMMNdo:.     `dMMMNds/-`      \033[33m");        
    $display("                      -+--/dNs-o/------------------------:+o`            \033[37m.MMMMyyyhNMMNy`   -NMMm`  sMMMh     .odNMMMMNd+`   `+dNMMMMNdo.    \033[33m");        
    $display("                     .o---yMMdsdo------------------------:s`             \033[37m.MMMMNmmmdho-    `dMMMdooosMMMM+      `./sdNMMMd.    `.:ohNMMMm-   \033[33m");        
    $display("                    -yo:--/hmmds:----------------//:------o              \033[37m.MMMM:...`       sMMMMMMMMMMMMMN-  ``     `:MMMM+ ``      -NMMMs   \033[33m");        
    $display("                   /yssy----:::-------o+-------/h/-hy:---:+              \033[37m.MMMM.          /MMMN:------hMMMd` +dy+:::/yMMMN- :my+:::/sMMMM/   \033[33m");        
    $display("                  :ysssh:------//////++/-------sMdyNMo---o.              \033[37m.MMMM.         .mMMMs       .NMMMs /NMMMMMMMMmh:  -NMMMMMMMMNh/    \033[33m");        
    $display("                  ossssh:-------ddddmmmds/:----:hmNNh:---o               \033[37m`::::`         .::::`        -:::: `-:/++++/-.     .:/++++/-.      \033[33m");        
    $display("                  /yssyo--------dhhyyhhdmmhy+:---://----+-                                                                                  ");        
    $display("                  `yss+---------hoo++oosydms----------::s    `.....-.                                                                       ");        
    $display("                   :+-----------y+++++++oho--------:+sssy.://:::://+o.                                                                      ");        
    $display("                    //----------y++++++os/--------+yssssy/:--------:/s-                                                                     ");        
    $display("             `..:::::s+//:::----+s+++ooo:--------+yssssy:-----------++                                                                      ");        
    $display("           `://::------::///+/:--+soo+:----------ssssys/---------:o+s.``                                                                    ");        
    $display("          .+:----------------/++/:---------------:sys+----------:o/////////::::-...`                                                        ");        
    $display("          o---------------------oo::----------::/+//---------::o+--------------:/ohdhyo/-.``                                                ");        
    $display("          o---------------------/s+////:----:://:---------::/+h/------------------:oNMMMMNmhs+:.`                                           ");        
    $display("          -+:::::--------------:s+-:::-----------------:://++:s--::------------::://sMMMMMMMMMMNds/`                                        ");        
    $display("           .+++/////////////+++s/:------------------:://+++- :+--////::------/ydmNNMMMMMMMMMMMMMMmo`                                        ");        
    $display("             ./+oo+++oooo++/:---------------------:///++/-   o--:///////::----sNMMMMMMMMMMMMMMMmo.                                          ");        
    $display("                o::::::--------------------------:/+++:`    .o--////////////:--+mMMMMMMMMMMMMmo`                                            ");        
    $display("               :+--------------------------------/so.       +:-:////+++++///++//+mMMMMMMMMMmo`                                              ");        
    $display("              .s----------------------------------+: ````` `s--////o:.-:/+syddmNMMMMMMMMMmo`                                                ");        
    $display("              o:----------------------------------s. :s+/////--//+o-       `-:+shmNNMMMNs.                                                  ");        
    $display("             //-----------------------------------s` .s///:---:/+o.               `-/+o.                                                    ");        
    $display("            .o------------------------------------o.  y///+//:/+o`                                                                          ");        
    $display("            o-------------------------------------:/  o+//s//+++`                                                                           ");        
    $display("           //--------------------------------------s+/o+//s`                                                                                ");        
    $display("          -+---------------------------------------:y++///s                                                                                 ");        
    $display("          o-----------------------------------------oo/+++o                                                                                 ");        
    $display("         `s-----------------------------------------:s   ``                                                                                 ");        
    $display("          o-:::::------------------:::::-------------o.                                                                                     ");        
    $display("          .+//////////::::::://///////////////:::----o`                                                                                     ");        
    $display("          `:soo+///////////+++oooooo+/////////////:-//                                                                                      ");        
    $display("       -/os/--:++/+ooo:::---..:://+ooooo++///////++so-`                                                                                     ");        
    $display("      syyooo+o++//::-                 ``-::/yoooo+/:::+s/.                                                                                  ");        
    $display("       `..``                                `-::::///:++sys:                                                                                ");        
    $display("                                                    `.:::/o+  \033[37m                                                                              ");   
    $display("********************************************************************");
    $display("                        \033[0;38;5;219mCongratulations!\033[m      ");
    $display("                 \033[0;38;5;219mYou have passed all patterns!\033[m");
    $display("                 \033[0;38;5;219mTOTAL LATENCY IS: %d\033[m",total_latency);    
    $display("********************************************************************");
    $finish;
endtask

task fail_task; 
    $display("wrong");      

endtask

endprogram