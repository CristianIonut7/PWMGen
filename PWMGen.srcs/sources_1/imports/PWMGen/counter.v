module counter (
    // peripheral clock signals
    input clk,
    input rst_n,
    // register facing signals
    output[15:0] count_val,
    input[15:0] period,
    input en,
    input count_reset,
    input upnotdown,
    input[7:0] prescale
);
    
    //values used for counting, they modify only on !en or on overflow/underflow
    reg [15:0] active_period;
    reg [7:0]  active_prescale;
    reg active_upnotdown;
    
    
    reg [31:0] prescaler_cnt; //internal counter for prescale 
    wire [31:0] prescaler_limit; //the number of cicles for counter
    wire tick; // the signal for counter
    
    assign prescaler_limit = (32'd1 << active_prescale); //2^prescale 

    assign tick = (prescaler_cnt >= (prescaler_limit - 1)); //tick is true if internal counter is equal to the counter_limit - 1
    
    wire safe_to_update;
    assign safe_to_update = (!en) || (count_val == 1 && active_upnotdown == 0) || (count_val == active_period - 1 && active_upnotdown == 1);
    
   
    // Block for updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_period    <= 0;
            active_prescale  <= 0;
            active_upnotdown <= 0;
        end else begin
            if (safe_to_update && (tick || !en)) begin
                active_period    <= period;
                active_prescale  <= prescale;
                active_upnotdown <= upnotdown;
            end
        end
    end
    // Block for prescale
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin //reset
            prescaler_cnt <= 0;
        end else if (count_reset) begin
            prescaler_cnt <= 0; //internal reset
        end else if (en) begin
            if (tick) begin
                prescaler_cnt <= 0; //limit 
            end else begin
                prescaler_cnt <= prescaler_cnt + 1;
            end
        end
    end
    
    
    reg[15:0] val; // auxiliary variable for modifying the counter_val
    assign count_val = val;

    //Block for counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            val <= 0; //reset
        end else if (count_reset) begin
            val <= 0; //internal reset
        end else if (en && tick) begin
            if (active_upnotdown) begin
                //incrementation
                if (val >= active_period - 1 || active_period == 0) begin
                    val <= 0; //period reset
                end else begin
                    val <= val + 1;
                end
            end else begin
                //decrementation
                if (val == 0) begin
                    val <= active_period - 1; //period reset
                end else begin
                    val <= val - 1;
                end
                if(active_period == 0) begin
                    val = 0;
                end
            end
        end
    end
endmodule