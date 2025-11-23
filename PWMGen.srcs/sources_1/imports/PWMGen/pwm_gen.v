module pwm_gen (
    // peripheral clock signals
    input clk,
    input rst_n,
    // PWM signal register configuration
    input pwm_en,
    input[15:0] period,
    input[7:0] functions,
    input[15:0] compare1,
    input[15:0] compare2,
    input[15:0] count_val,
    // top facing signals
    output pwm_out
);

    reg [15:0] active_compare1;
    reg [15:0] active_compare2;
    reg [7:0]  active_functions;
    reg [15:0] active_period;
    
    reg first_allign;
    wire safe_to_update;
    
    reg out;
    assign pwm_out = out;
    assign safe_to_update = (!pwm_en) || (count_val == (active_period ? active_period - 1 : 0));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_compare1  <= 16'd0;
            active_compare2  <= 16'd0;
            active_functions <= 8'd0;
            active_period <= 16'd0;
            out <= 0;
        end else begin
            if (safe_to_update) begin
                active_compare1  <= compare1;
                active_compare2  <= compare2;
                active_functions <= functions;
                active_period <= period;
                if(active_period != period || compare1 != active_compare1 || compare2 != active_compare2 || functions != active_functions) begin
                    if(functions[1] == 1) begin
                        out <= 0;
                    end else begin
                        if(functions[0] == 1) begin
                            out <= 0;
                        end else begin
                            out <= 1;
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out <= 1'b0;
        end else begin
            if (!pwm_en) begin
                out <= 1'b0;
            end else begin
                if (active_functions[1] == 1'b1) begin
                    if (count_val == (active_compare1 ? active_compare1 - 1 : active_period - 1)) begin
                        out <= 1'b1;
                    end else if (count_val == (active_compare2 ? active_compare2 - 1 : active_period - 1)) begin
                        out <= 1'b0;
                    end
                end else if (count_val == (active_compare1 ? active_compare1 - 1 : active_period - 1)) begin
                    out <= ~out;
                end
            end
        end
    end
endmodule