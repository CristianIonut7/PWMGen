module counter (
    input clk,
    input rst_n,
    output reg [15:0] count_val, // Facem reg direct
    input [15:0] period,
    input en,
    input count_reset,
    input upnotdown,
    input [7:0] prescale
);
    
    // Shadow registers (Active)
    reg [15:0] active_period;
    reg [7:0]  active_prescale;
    reg active_upnotdown;
    
    // Prescaler logic
    reg [31:0] prescaler_cnt; 
    wire tick;
    
    // Prescaler count: 0 to (2^prescale - 1)
    // Daca prescale=0, limit=1. cnt merge 0->0. tick=1 mereu.
    assign tick = (prescaler_cnt >= ((32'd1 << active_prescale) - 1));

    // Update logic condition
    wire safe_to_update;
    // Update la Overflow (cand se termina perioada) sau cand e oprit
    assign safe_to_update = (!en) || (count_val == active_period);

    // 1. Block Update Parametri
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_period    <= 0;
            active_prescale  <= 0;
            active_upnotdown <= 0;
        end else begin
            // Facem update cand e safe SI cand avem tick (sfarsit de ciclu)
            // Sau cand e oprit.
            if ((!en) || (safe_to_update && tick)) begin
                active_period    <= period;
                active_prescale  <= prescale;
                active_upnotdown <= upnotdown;
            end
        end
    end

    // 2. Block Prescaler
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) prescaler_cnt <= 0;
        else if (count_reset) prescaler_cnt <= 0;
        else if (en) begin
            if (tick) prescaler_cnt <= 0;
            else      prescaler_cnt <= prescaler_cnt + 1;
        end
    end

    // 3. Block Counter (Principal)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_val <= 0;
        end else if (count_reset) begin
            count_val <= 0;
        end else if (en && tick) begin
            if (active_upnotdown) begin
                // UP Counting: 0 -> Period
                if (count_val >= active_period) 
                    count_val <= 0;
                else 
                    count_val <= count_val + 1;
            end else begin
                // DOWN Counting: Period -> 0
                if (count_val == 0) 
                    count_val <= active_period;
                else 
                    count_val <= count_val - 1;
            end
        end
    end

endmodule