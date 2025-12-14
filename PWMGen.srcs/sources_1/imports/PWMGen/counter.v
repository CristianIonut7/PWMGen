module counter (
    input clk,
    input rst_n,
    output reg [15:0] count_val, // Transform in reg
    input [15:0] period,
    input en,
    input count_reset,
    input upnotdown,
    input [7:0] prescale
);
    
    // Shadow registers (active)
    reg [15:0] active_period;
    reg [7:0]  active_prescale;
    reg active_upnotdown;
    
    // Prescaler logic
    reg [31:0] prescaler_cnt; 
    wire tick;
    
    // Prescaler count: 0 to (2^prescale - 1)
    // If prescale=0, limit=1, cnt goes from 0 to 0, tick=1 always.
    assign tick = (prescaler_cnt >= ((32'd1 << active_prescale) - 1));

    // Update logic condition
    wire safe_to_update;
    // Update at overflow or when it's stopped
    assign safe_to_update = (!en) || (count_val == active_period);

    // Block for parameteres update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_period    <= 0;
            active_prescale  <= 0;
            active_upnotdown <= 0;
        end else begin
            // We update when is stopped or on safe
            if ((!en) || (safe_to_update && tick)) begin
                active_period    <= period;
                active_prescale  <= prescale;
                active_upnotdown <= upnotdown;
            end
        end
    end

    // Prescaler block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) prescaler_cnt <= 0;
        else if (count_reset) prescaler_cnt <= 0;
        else if (en) begin
            if (tick) prescaler_cnt <= 0;
            else      prescaler_cnt <= prescaler_cnt + 1;
        end
    end

    // Counter block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_val <= 0;
        end else if (count_reset) begin
            count_val <= 0;
        end else if (en && tick) begin
            if (active_upnotdown) begin
                // Up counting
                if (count_val >= active_period) 
                    count_val <= 0;
                else 
                    count_val <= count_val + 1;
            end else begin
                // Down counting
                if (count_val == 0) 
                    count_val <= active_period;
                else 
                    count_val <= count_val - 1;
            end
        end
    end

endmodule