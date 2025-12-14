module pwm_gen (
    input clk,
    input rst_n,
    input pwm_en,
    input[15:0] period,
    input[7:0] functions,
    input[15:0] compare1,
    input[15:0] compare2,
    input[15:0] count_val,
    output reg pwm_out
);

    // Shadow registers (active)
    reg [15:0] act_period;
    reg [7:0]  act_func;
    reg [15:0] act_comp1;
    reg [15:0] act_comp2;

    // We update on 0 or when counter is stopped
    wire update_now = (!pwm_en) || (count_val == 0); 

    // Parameters update block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_period <= 0; act_func <= 0; act_comp1 <= 0; act_comp2 <= 0;
        end else begin
            if (update_now) begin
                act_period <= period;
                act_func   <= functions;
                act_comp1  <= compare1;
                act_comp2  <= compare2;
            end
        end
    end

    // We use new values exactly at the moment when update_safe is active
    wire [15:0] eff_comp1 = update_now ? compare1  : act_comp1;
    wire [15:0] eff_comp2 = update_now ? compare2  : act_comp2;
    wire [1:0]  eff_func  = update_now ? functions[1:0] : act_func[1:0];

    // PWM generator block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out <= 0;
        end else if (!pwm_en) begin
            pwm_out <= 0;
        end else begin
            
            // If compare1 = compare2 we force pwm_out = 0 (Test 4)
            if (eff_comp1 == eff_comp2) begin
                pwm_out <= 1'b0;
            end 
            else begin
                case (eff_func)
                    // Align left
                    2'b00: begin 
                        // if compare1 = 0 (Test 5)
                        if (eff_comp1 == 0) 
                            pwm_out <= 1'b0;
                        else if (count_val <= eff_comp1) 
                            pwm_out <= 1'b1;
                        else 
                            pwm_out <= 1'b0;
                    end

                    // Align right
                    2'b01: begin 
                        if (count_val >= eff_comp1)
                            pwm_out <= 1'b1;
                        else
                            pwm_out <= 1'b0;
                    end

                    // Unaligned
                    2'b10: begin
                        // Interval: [compare1, compare2)
                        if ((count_val >= eff_comp1) && (count_val < eff_comp2))
                            pwm_out <= 1'b1;
                        else
                            pwm_out <= 1'b0;
                    end

                    default: pwm_out <= 0;
                endcase
            end
        end
    end

endmodule