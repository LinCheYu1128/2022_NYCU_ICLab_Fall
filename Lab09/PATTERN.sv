`include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype_FD.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter SEED = 67 ;

int PATNUM, patcount, i, j, k, cycles, total_latency;
//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM[ ((65536+256*8)-1) : (65536+0)];

Error_Msg golden_err;
Action golden_act;
Ctm_Info golden_customer;     // status & res_id & food_id & food_num(max 15)
food_ID_servings golden_food, cancel_food; // food_id & food_num(max 15)
// id
Restaurant_id golden_res_id;
Delivery_man_id golden_man_id;
// current information
res_info golden_res_info, take_res_info;    // total_food & food_num(max 255)*3
D_man_Info golden_man_info;  // Ctm_Info & Ctm_Info

logic change_res_id, change_man_id; // change id flag
logic golden_complete;
//================================================================
// class random
//================================================================
class rand_gap;	
	rand int gap;
	function new (int seed);
		this.srandom(seed);		
	endfunction 
	constraint limit { gap inside {[1:5]}; }
endclass

class rand_delay;	
	rand int delay;
	function new (int seed);
		this.srandom(seed);		
	endfunction 
	constraint limit { delay inside {[1:9]}; }
endclass

class rand_food;	
	rand Food_id food_id;
    rand servings_of_food food_num;
	function new (int seed);
		this.srandom(seed);		
	endfunction 
	constraint limit { food_id inside {FOOD1, FOOD2, FOOD3}; food_num inside {[1:15]};}
endclass

class rand_act;	
	rand Action act;
	function new (int seed);
		this.srandom(seed);		
	endfunction 
	constraint limit { act inside {Take, Deliver, Order, Cancel}; }
endclass

class rand_res_id;	
	rand Restaurant_id res_id;
	function new (int seed);
		this.srandom(seed);		
	endfunction 
	constraint limit { res_id inside {[0:255]}; }
endclass

class rand_man_id;	
	rand Delivery_man_id man_id;
	function new (int seed);
		this.srandom(seed);		
	endfunction 
	constraint limit { man_id inside {[0:255]}; }
endclass

class rand_cus;	
	rand Customer_status ctm_status;
    rand Restaurant_id res_id;
    rand Food_id food_id;
    rand servings_of_food food_num;
	function new (int seed);
		this.srandom(seed);		
	endfunction 
	constraint limit { 
        ctm_status inside {VIP, Normal}; 
        res_id inside {[0:255]};
        food_id inside {FOOD1, FOOD2, FOOD3}; 
        food_num inside {[1:15]};
    }
endclass

rand_gap    r_gap   = new(SEED);
rand_delay  r_delay = new(SEED);
rand_food   r_food  = new(SEED);
rand_act    r_act   = new(SEED);
rand_res_id r_r_id  = new(SEED);
rand_man_id r_m_id  = new(SEED);
rand_cus    r_cus   = new(SEED);

//================================================================
// initial
//================================================================
initial  $readmemh(DRAM_p_r, golden_DRAM);
initial begin
    inf.rst_n = 1'b1 ;
	inf.id_valid = 1'b0 ;
	inf.act_valid = 1'b0 ;
    inf.res_valid = 1'b0 ;
	inf.cus_valid = 1'b0 ;
	inf.food_valid = 1'b0 ;
	inf.D = 'bx;
    force clk = 0 ;
    reset_task;
    total_latency = 0;

    @(negedge clk);
    // patcount = 0;
    change_res_id = 0; change_man_id = 0;
    for(j=0; j<256; j=j+1)begin
        // change restuarant id every 5 iteration
        if(j % 1 == 0)begin
            // r_r_id.randomize();
            golden_res_id = j;//r_r_id.res_id;
            change_res_id = 1;
        end else begin
            change_res_id = 0;
        end
        // change deliver man id every 7 iteration
        if(j % 1 == 0)begin
            // r_m_id.randomize();
            golden_man_id = j;//r_m_id.man_id;
            change_man_id = 1;
        end else begin
            change_man_id = 0;
        end

        // four action by turn
        // TAKE (act -> man_id(if needed) -> cus_info)
        if(j % 4 == 0)begin
            // act
            golden_act = Take;
            give_action_task;
            // man
            get_man_info_task;
            if(change_man_id)begin 
                give_man_task;
            end
            // cus
            r_cus.randomize();
            golden_customer.ctm_status = r_cus.ctm_status;
            golden_customer.res_ID = r_cus.res_id;
            golden_customer.food_ID = r_cus.food_id;
            golden_customer.ser_food = r_cus.food_num;
            get_res_info_task;
            give_cus_task;
        end 
        // DELIVER (act -> man_id)
        else if(j % 4 == 1)begin
            // act
            golden_act = Deliver;
            give_action_task;
            // man
            get_man_info_task;
            give_man_task;
        end 
        // ORDER (act -> res_id(if needed) -> food)
        else if(j % 4 == 2)begin
            // act
            golden_act = Order;
            give_action_task;
            // res
            get_res_info_task;
            if(change_res_id)begin 
                give_res_task;
            end
            // food
            r_food.randomize();
            golden_food.d_food_ID = r_food.food_id;
            golden_food.d_ser_food = r_food.food_num;
            give_food_task;
        end 
        // CANCEL (act -> res_id -> food -> man_id)
        else if(j % 4 == 3)begin
            // prepare man info
            get_man_info_task;
            // act
            golden_act = Cancel;
            give_action_task;
            // res
            give_res_task;
            // food
            r_food.randomize();
            golden_food.d_food_ID = r_food.food_id;
            golden_food.d_ser_food = 0;
            give_food_task;
            // man
            give_man_task;
        end
        cal_ans_task;
        wait_outvalid_task;
        write_back_task;
        rand_delay_task; 
    end
    YOU_PASS_task;
    $finish;
end

task cal_ans_task; begin
    case (golden_act)
    Take:begin
        if(golden_man_info.ctm_info2.ctm_status != None)begin
            golden_complete = 0;
            golden_err = D_man_busy;
        end
        else begin
            case (golden_customer.food_ID)
            FOOD1: begin
                if(golden_res_info.ser_FOOD1 - golden_customer.ser_food < 0)begin
                    golden_complete = 0;
                    golden_err = No_Food; 
                end
                else begin
                    golden_complete = 1;
                    golden_err = No_Err;
                    golden_res_info.ser_FOOD1 = golden_res_info.ser_FOOD1 - golden_customer.ser_food;
                    if(golden_man_info.ctm_info1.ctm_status == None)begin
                        golden_man_info.ctm_info1 = golden_customer;
                    end
                    else if(golden_man_info.ctm_info2.ctm_status == None)begin
                        if(golden_customer.ctm_status == VIP && golden_man_info.ctm_info1.ctm_status == Normal)begin
                            golden_man_info.ctm_info2 = golden_man_info.ctm_info1;
                            golden_man_info.ctm_info1 = golden_customer;
                        end
                        else begin
                            golden_man_info.ctm_info2 = golden_customer;
                        end
                    end
                end
            end
            FOOD2: begin
                if(golden_res_info.ser_FOOD2 - golden_customer.ser_food < 0)begin
                    golden_complete = 0;
                    golden_err = No_Food; 
                end
                else begin
                    golden_complete = 1;
                    golden_err = No_Err;
                    golden_res_info.ser_FOOD2 = golden_res_info.ser_FOOD2 - golden_customer.ser_food;
                    if(golden_man_info.ctm_info1.ctm_status == None)begin
                        golden_man_info.ctm_info1 = golden_customer;
                    end
                    else if(golden_man_info.ctm_info2.ctm_status == None)begin
                        if(golden_customer.ctm_status == VIP && golden_man_info.ctm_info1.ctm_status == Normal)begin
                            golden_man_info.ctm_info2 = golden_man_info.ctm_info1;
                            golden_man_info.ctm_info1 = golden_customer;
                        end
                        else begin
                            golden_man_info.ctm_info2 = golden_customer;
                        end
                    end
                end
            end
            FOOD3: begin
                if(golden_res_info.ser_FOOD3 - golden_customer.ser_food < 0)begin
                    golden_complete = 0;
                    golden_err = No_Food; 
                end
                else begin
                    golden_complete = 1;
                    golden_err = No_Err;
                    golden_res_info.ser_FOOD3 = golden_res_info.ser_FOOD3 - golden_customer.ser_food;
                    if(golden_man_info.ctm_info1.ctm_status == None)begin
                        golden_man_info.ctm_info1 = golden_customer;
                    end
                    else if(golden_man_info.ctm_info2.ctm_status == None)begin
                        if(golden_customer.ctm_status == VIP && golden_man_info.ctm_info1.ctm_status == Normal)begin
                            golden_man_info.ctm_info2 = golden_man_info.ctm_info1;
                            golden_man_info.ctm_info1 = golden_customer;
                        end
                        else begin
                            golden_man_info.ctm_info2 = golden_customer;
                        end
                    end
                end
            end
            endcase
        end
    end 
    Deliver:begin
        if(golden_man_info.ctm_info1.ctm_status == None)begin
            golden_complete = 0;
            golden_err = No_customers;
        end
        else begin
            golden_complete = 1;
            golden_err = No_Err;
            golden_man_info.ctm_info1 = golden_man_info.ctm_info2;
            golden_man_info.ctm_info2 = 0;
        end
    end
    Order:begin
        if(golden_res_info.limit_num_orders < 
        (golden_res_info.ser_FOOD1 + golden_res_info.ser_FOOD1 + 
        golden_res_info.ser_FOOD1 + golden_food.d_ser_food))begin
            golden_complete = 0;
            golden_err = Res_busy;
        end
        else begin
            golden_complete = 1;
            golden_err = No_Err;
            case (golden_food.d_food_ID)
            FOOD1: golden_res_info.ser_FOOD1 = golden_res_info.ser_FOOD1 + golden_food.d_ser_food;
            FOOD2: golden_res_info.ser_FOOD2 = golden_res_info.ser_FOOD2 + golden_food.d_ser_food;
            FOOD3: golden_res_info.ser_FOOD3 = golden_res_info.ser_FOOD3 + golden_food.d_ser_food;
            endcase
        end
    end
    Cancel:begin
        if(golden_man_info.ctm_info1.ctm_status == None)begin
            golden_complete = 0;
            golden_err = Wrong_cancel; 
        end
        else if(golden_man_info.ctm_info1.res_ID != golden_res_id && golden_man_info.ctm_info2.res_ID != golden_res_id)begin
            golden_complete = 0;
            golden_err = Wrong_res_ID;
        end
        else if(golden_man_info.ctm_info1.res_ID == golden_res_id && golden_man_info.ctm_info1.food_ID == golden_food.d_food_ID)begin
            golden_complete = 1;
            golden_err = No_Err;
            golden_man_info.ctm_info1 = golden_man_info.ctm_info2;
            golden_man_info.ctm_info2 = 0;
        end
        else if(golden_man_info.ctm_info2.res_ID == golden_res_id && golden_man_info.ctm_info2.food_ID == golden_food.d_food_ID)begin
            golden_complete = 1;
            golden_err = No_Err;
            golden_man_info.ctm_info2 = 0;
        end
        else begin
            golden_complete = 0;
            golden_err = Wrong_food_ID;
        end
    end
    endcase
end endtask

task wait_outvalid_task; begin
    cycles = 0 ;
	while (inf.out_valid!==1) begin
		cycles = cycles + 1 ;
		if (cycles==1200) begin
            $display("Wrong Answer");
            // $display ("--------------------------------------------------------------------------------------------------------------------------------------------");
            // $display ("                                             The execution latency is limited in 1200 cycles.                                               ");
            // $display ("--------------------------------------------------------------------------------------------------------------------------------------------");
            // #(100);
            $finish;
		end
		@(negedge clk);
	end
    total_latency = total_latency + cycles ;

end endtask

task write_back_task; begin
    if(golden_complete)begin
        case (golden_act)
        Take:begin
            {golden_DRAM[65536+golden_man_id*8 + 4], golden_DRAM[65536+golden_man_id*8 + 5]} = golden_man_info.ctm_info1;
            {golden_DRAM[65536+golden_man_id*8 + 6], golden_DRAM[65536+golden_man_id*8 + 7]} = golden_man_info.ctm_info2;
            golden_DRAM[65536+golden_customer.res_ID*8 + 0] = golden_res_info.limit_num_orders;
            golden_DRAM[65536+golden_customer.res_ID*8 + 1] = golden_res_info.ser_FOOD1       ;
            golden_DRAM[65536+golden_customer.res_ID*8 + 2] = golden_res_info.ser_FOOD2       ;
            golden_DRAM[65536+golden_customer.res_ID*8 + 3] = golden_res_info.ser_FOOD3       ;
        end
        Deliver: begin
            {golden_DRAM[65536+golden_man_id*8 + 4], golden_DRAM[65536+golden_man_id*8 + 5]} = golden_man_info.ctm_info1;
            {golden_DRAM[65536+golden_man_id*8 + 6], golden_DRAM[65536+golden_man_id*8 + 7]} = golden_man_info.ctm_info2;
        end
        Order:begin
            golden_DRAM[65536+golden_res_id*8 + 0] = golden_res_info.limit_num_orders;
            golden_DRAM[65536+golden_res_id*8 + 1] = golden_res_info.ser_FOOD1       ;
            golden_DRAM[65536+golden_res_id*8 + 2] = golden_res_info.ser_FOOD2       ;
            golden_DRAM[65536+golden_res_id*8 + 3] = golden_res_info.ser_FOOD3       ;
        end 
        Cancel:begin
            {golden_DRAM[65536+golden_man_id*8 + 4], golden_DRAM[65536+golden_man_id*8 + 5]} = golden_man_info.ctm_info1;
            {golden_DRAM[65536+golden_man_id*8 + 6], golden_DRAM[65536+golden_man_id*8 + 7]} = golden_man_info.ctm_info2;
        end
        endcase
    end
    
end endtask

task get_res_info_task; begin
    if(golden_act == Take)begin
        golden_res_info.limit_num_orders = golden_DRAM[65536+golden_customer.res_ID*8 + 0];
        golden_res_info.ser_FOOD1        = golden_DRAM[65536+golden_customer.res_ID*8 + 1];
        golden_res_info.ser_FOOD2        = golden_DRAM[65536+golden_customer.res_ID*8 + 2];
        golden_res_info.ser_FOOD3        = golden_DRAM[65536+golden_customer.res_ID*8 + 3];
    end
    else begin
        golden_res_info.limit_num_orders = golden_DRAM[65536+golden_res_id*8 + 0];
        golden_res_info.ser_FOOD1        = golden_DRAM[65536+golden_res_id*8 + 1];
        golden_res_info.ser_FOOD2        = golden_DRAM[65536+golden_res_id*8 + 2];
        golden_res_info.ser_FOOD3        = golden_DRAM[65536+golden_res_id*8 + 3];
    end
end endtask
task get_man_info_task; begin
    golden_man_info.ctm_info1 = {golden_DRAM[65536+golden_man_id*8 + 4], golden_DRAM[65536+golden_man_id*8 + 5]};
    golden_man_info.ctm_info2 = {golden_DRAM[65536+golden_man_id*8 + 6], golden_DRAM[65536+golden_man_id*8 + 7]};
end endtask
//================================================================
// input task
//================================================================
task give_action_task; begin
    rand_gap_task;
	inf.act_valid = 1'b1 ;
	inf.D = { 12'd0 , golden_act } ;
	@(negedge clk);
	inf.act_valid = 1'b0 ;
	inf.D = 'bx ;
end endtask

task give_res_task; begin
    rand_gap_task;
	inf.res_valid = 1'b1 ;
	inf.D = { 8'd0 , golden_res_id } ;
	@(negedge clk);
	inf.res_valid = 1'b0 ;
	inf.D = 'bx ;
end endtask

task give_man_task; begin
    rand_gap_task;
	inf.id_valid = 1'b1 ;
	inf.D = { 8'd0 , golden_man_id } ;
	@(negedge clk);
	inf.id_valid = 1'b0 ;
	inf.D = 'bx ;
end endtask

task  give_food_task; begin
    rand_gap_task;
    inf.food_valid = 1'b1;
    inf.D = { 10'd0 , golden_food.d_food_ID, golden_food.d_ser_food} ;
    @(negedge clk);
	inf.food_valid = 1'b0 ;
	inf.D = 'bx ;
end endtask

task give_cus_task; begin
    rand_gap_task;
	inf.cus_valid = 1'b1 ;
	inf.D = { golden_customer.ctm_status, golden_customer.res_ID, golden_customer.food_ID, golden_customer.ser_food } ;
	@(negedge clk);
	inf.cus_valid = 1'b0 ;
	inf.D = 'bx ;
end endtask

//================================================================
// delay task
//================================================================
task rand_gap_task; begin
    r_gap.randomize();
    // $display("gap = %01d", r_gap.gap);
    repeat(r_gap.gap) @(negedge clk);
    // repeat(1) @(negedge clk);
end endtask

task rand_delay_task; begin
    r_delay.randomize();
    // $display("gap = %01d", r_gap.gap);
    repeat(r_delay.delay) @(negedge clk);
    // repeat(1) @(negedge clk);
end endtask

//================================================================
// PASS FAIL task
//================================================================
task reset_task ; begin
	#(20);	inf.rst_n = 0 ;
	#(20);
	// if (inf.out_valid!==0 || inf.err_msg!==0 || inf.complete!==0 || inf.out_info!==0) begin
    //     // $display ("--------------------------------------------------------------------------------------------------------------------------------------------");
    //     // $display ("                                                                RESET FAIL!                                                                 ");
    //     // $display ("--------------------------------------------------------------------------------------------------------------------------------------------");
    //     // #(100);
    //     $finish;
	// end
	#(10);	inf.rst_n = 1 ;
    #(6);   release clk;
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
    $display("\033[33m	                                                         .:                                                                                         ");      
    $display("                                                   .:                                                                                                 ");
    $display("                                                  --`                                                                                                 ");
    $display("                                                `--`                                                                                                  ");
    $display("                 `-.                            -..        .-//-                                                                                      ");
    $display("                  `.:.`                        -.-     `:+yhddddo.                                                                                    ");
    $display("                    `-:-`             `       .-.`   -ohdddddddddh:                                                                                   ");
    $display("                      `---`       `.://:-.    :`- `:ydddddhhsshdddh-                       \033[31m.yhhhhhhhhhs       /yyyyy`       .yhhy`   +yhyo           \033[33m");
    $display("                        `--.     ./////:-::` `-.--yddddhs+//::/hdddy`                      \033[31m-MMMMNNNNNNh      -NMMMMMs       .MMMM.   sMMMh           \033[33m");
    $display("                          .-..   ////:-..-// :.:oddddho:----:::+dddd+                      \033[31m-MMMM-......     `dMMmhMMM/      .MMMM.   sMMMh           \033[33m");
    $display("                           `-.-` ///::::/::/:/`odddho:-------:::sdddh`                     \033[31m-MMMM.           sMMM/.NMMN.     .MMMM.   sMMMh           \033[33m");
    $display("             `:/+++//:--.``  .--..+----::://o:`osss/-.--------::/dddd/             ..`     \033[31m-MMMMysssss.    /MMMh  oMMMh     .MMMM.   sMMMh           \033[33m");
    $display("             oddddddddddhhhyo///.-/:-::--//+o-`:``````...------::dddds          `.-.`      \033[31m-MMMMMMMMMM-   .NMMN-``.mMMM+    .MMMM.   sMMMh           \033[33m");
    $display("            .ddddhhhhhddddddddddo.//::--:///+/`.````````..``...-:ddddh       `.-.`         \033[31m-MMMM:.....`  `hMMMMmmmmNMMMN-   .MMMM.   sMMMh           \033[33m");
    $display("            /dddd//::///+syhhdy+:-`-/--/////+o```````.-.......``./yddd`   `.--.`           \033[31m-MMMM.        oMMMmhhhhhhdMMMd`  .MMMM.   sMMMh```````    \033[33m");
    $display("            /dddd:/------:://-.`````-/+////+o:`````..``     `.-.``./ym.`..--`              \033[31m-MMMM.       :NMMM:      .NMMMs  .MMMM.   sMMMNmmmmmms    \033[33m");
    $display("            :dddd//--------.`````````.:/+++/.`````.` `.-      `-:.``.o:---`                \033[31m.dddd`       yddds        /dddh. .dddd`   +ddddddddddo    \033[33m");
    $display("            .ddddo/-----..`........`````..```````..  .-o`       `:.`.--/-      ``````````` \033[31m ````        ````          ````   ````     ``````````     \033[33m");
    $display("             ydddh/:---..--.````.`.-.````````````-   `yd:        `:.`...:` `................`                                                         ");
    $display("             :dddds:--..:.     `.:  .-``````````.:    +ys         :-````.:...```````````````..`                                                       ");
    $display("              sdddds:.`/`      ``s.  `-`````````-/.   .sy`      .:.``````-`````..-.-:-.````..`-                                                       ");
    $display("              `ydddd-`.:       `sh+   /:``````````..`` +y`   `.--````````-..---..``.+::-.-``--:                                                       ");
    $display("               .yddh``-.        oys`  /.``````````````.-:.`.-..`..```````/--.`      /:::-:..--`                                                       ");
    $display("                .sdo``:`        .sy. .:``````````````````````````.:```...+.``       -::::-`.`                                                         ");
    $display(" ````.........```.++``-:`        :y:.-``````````````....``.......-.```..::::----.```  ``                                                              ");
    $display("`...````..`....----:.``...````  ``::.``````.-:/+oosssyyy:`.yyh-..`````.:` ````...-----..`                                                             ");
    $display("                 `.+.``````........````.:+syhdddddddddddhoyddh.``````--              `..--.`                                                          ");
    $display("            ``.....--```````.```````.../ddddddhhyyyyyyyhhhddds````.--`             ````   ``                                                          ");
    $display("         `.-..``````-.`````.-.`.../ss/.oddhhyssssooooooossyyd:``.-:.         `-//::/++/:::.`                                                          ");
    $display("       `..```````...-::`````.-....+hddhhhyssoo+++//////++osss.-:-.           /++++o++//s+++/                                                          ");
    $display("     `-.```````-:-....-/-``````````:hddhsso++/////////////+oo+:`             +++::/o:::s+::o            \033[31m     `-/++++:-`                              \033[33m");
    $display("    `:````````./`  `.----:..````````.oysso+///////////////++:::.             :++//+++/+++/+-            \033[31m   :ymMMMMMMMMms-                            \033[33m");
    $display("    :.`-`..```./.`----.`  .----..`````-oo+////////////////o:-.`-.            `+++++++++++/.             \033[31m `yMMMNho++odMMMNo                           \033[33m");
    $display("    ..`:..-.`.-:-::.`        `..-:::::--/+++////////////++:-.```-`            +++++++++o:               \033[31m hMMMm-      /MMMMo  .ssss`/yh+.syyyyyyyyss. \033[33m");
    $display("     `.-::-:..-:-.`                 ```.+::/++//++++++++:..``````:`          -++++++++oo                \033[31m:MMMM:        yMMMN  -MMMMdMNNs-mNNNNNMMMMd` \033[33m");
    $display("        `   `--`                        /``...-::///::-.`````````.: `......` ++++++++oy-                \033[31m+MMMM`        +MMMN` -MMMMh:--. ````:mMMNs`  \033[33m");
    $display("           --`                          /`````````````````````````/-.``````.::-::::::/+                 \033[31m:MMMM:        yMMMm  -MMMM`       `oNMMd:    \033[33m");
    $display("          .`                            :```````````````````````--.`````````..````.``/-                 \033[31m dMMMm:`    `+MMMN/  -MMMN       :dMMNs`     \033[33m");
    $display("                                        :``````````````````````-.``.....````.```-::-.+                  \033[31m `yNMMMdsooymMMMm/   -MMMN     `sMMMMy/////` \033[33m");
    $display("                                        :.````````````````````````-:::-::.`````-:::::+::-.`             \033[31m   -smNMMMMMNNd+`    -NNNN     hNNNNNNNNNNN- \033[33m");
    $display("                                `......../```````````````````````-:/:   `--.```.://.o++++++/.           \033[31m      .:///:-`       `----     ------------` \033[33m");
    $display("                              `:.``````````````````````````````.-:-`      `/````..`+sssso++++:                                                        ");
    $display("                              :`````.---...`````````````````.--:-`         :-````./ysoooss++++.                                                       ");
    $display("                              -.````-:/.`.--:--....````...--:/-`            /-..-+oo+++++o++++.                                                       ");
    $display("             `:++/:.`          -.```.::      `.--:::::://:::::.              -:/o++++++++s++++                                                        ");
    $display("           `-+++++++++////:::/-.:.```.:-.`              :::::-.-`               -+++++++o++++.                                                        ");
    $display("           /++osoooo+++++++++:`````````.-::.             .::::.`-.`              `/oooo+++++.                                                         ");
    $display("           ++oysssosyssssooo/.........---:::               -:::.``.....`     `.:/+++++++++:                                                           ");
    $display("           -+syoooyssssssyo/::/+++++/+::::-`                 -::.``````....../++++++++++:`                                                            ");
    $display("             .:///-....---.-..-.----..`                        `.--.``````````++++++/:.                                                               ");
    $display("                                                                   `........-:+/:-.`                                                            \033[37m      ");
endtask

endprogram