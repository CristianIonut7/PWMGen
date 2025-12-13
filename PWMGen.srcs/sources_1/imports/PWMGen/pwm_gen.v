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

    // Registre interne (Shadow)
    reg [15:0] act_period;
    reg [7:0]  act_func;
    reg [15:0] act_comp1;
    reg [15:0] act_comp2;

    // Semnal de update (la 0 sau cand e oprit)
    wire update_now = (!pwm_en) || (count_val == 0); 

    // --- 1. Update Parametri ---
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

    // --- 2. Selectia Parametrilor Efectivi (FORWARDING) ---
    // Asta rezolva problema glitch-ului la count==0.
    // Daca suntem in momentul de update, folosim direct intrarile.
    // Daca nu, folosim registrele interne.
    wire [15:0] eff_comp1 = update_now ? compare1  : act_comp1;
    wire [15:0] eff_comp2 = update_now ? compare2  : act_comp2;
    wire [1:0]  eff_func  = update_now ? functions[1:0] : act_func[1:0];

    // --- 3. Generare PWM (STATELESS) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out <= 0;
        end else if (!pwm_en) begin
            pwm_out <= 0;
        end else begin
            case (eff_func)
                // --- ALIGN LEFT (0..Comp1 High) ---
                2'b00: begin 
                    // Test 5 Fix: Daca Comp1 e 0, iesirea e 0.
                    if (eff_comp1 == 0) 
                        pwm_out <= 1'b0;
                    // Test 1 Logic: 0,1,2,3 -> High (4 ticks)
                    else if (count_val <= eff_comp1) 
                        pwm_out <= 1'b1;
                    else 
                        pwm_out <= 1'b0;
                end

                // --- ALIGN RIGHT (Starts 0, rises at Comp1) ---
                2'b01: begin 
                    // Test 3 Logic: 5,6,7 -> High (3 ticks)
                    if (count_val >= eff_comp1)
                        pwm_out <= 1'b1;
                    else
                        pwm_out <= 1'b0;
                end

                // --- RANGE BETWEEN COMPARES ([Comp1, Comp2)) ---
                2'b10: begin
                    // Test 2 & 4 Logic: Interval matematic strict.
                    // High daca suntem >= C1 SI < C2.
                    // Asta elimina orice ambiguitate sau latch gresit.
                    if ((count_val >= eff_comp1) && (count_val < eff_comp2))
                        pwm_out <= 1'b1;
                    else
                        pwm_out <= 1'b0;
                end

                default: pwm_out <= 0;
            endcase
        end
    end

endmodule