module regs (
    // peripheral clock signals
    input clk,
    input rst_n,
    // decoder facing signals
    input read,
    input write,
    input[5:0] addr,
    output[7:0] data_read,
    input[7:0] data_write,
    // counter programming signals
    input[15:0] counter_val,
    output[15:0] period,
    output en,
    output count_reset,
    output upnotdown,
    output[7:0] prescale,
    // PWM signal programming values
    output pwm_en,
    output[7:0] functions,
    output[15:0] compare1,
    output[15:0] compare2
);

/*
    All registers that appear in this block should be similar to this. Please try to abide
    to sizes as specified in the architecture documentation.
*/
reg[15:0] period;

// Adresele lips? sunt deduse ca fiind octetul High (H) al registrului precedent.
localparam ADDR_PERIOD_L    = 6'h00; // PERIOD [7:0]
localparam ADDR_PERIOD_H    = 6'h01; // PERIOD [15:8]

localparam ADDR_EN          = 6'h02; // COUNTER_EN

localparam ADDR_COMP1_L     = 6'h03; // COMPARE1 [7:0]
localparam ADDR_COMP1_H     = 6'h04; // COMPARE1 [15:8]

localparam ADDR_COMP2_L     = 6'h05; // COMPARE2 [7:0]
localparam ADDR_COMP2_H     = 6'h06; // COMPARE2 [15:8]

localparam ADDR_RESET       = 6'h07; // COUNTER_RESET

localparam ADDR_VAL_L       = 6'h08; // COUNTER_VAL [7:0]
localparam ADDR_VAL_H       = 6'h09; // COUNTER_VAL [15:8]

localparam ADDR_PRESCALE    = 6'h0A; // PRESCALE
localparam ADDR_UPDOWN      = 6'h0B; // UPNOTDOWN
localparam ADDR_PWM_EN      = 6'h0C; // PWM_EN
localparam ADDR_FUNCTIONS   = 6'h0D; // FUNCTIONS

// Modeleaz? Flip-Flop-urile, sensibile la ceas ?i la reset.
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        period <= 16'h0000;
        compare1 <= 16'h0000;
        compare2 <= 16'h0000;
        prescale <= 16'h0000;
        
        en <= 1'b0;
        upnotdown <= 1'b0;
        pwm_en <= 1'b0;
        functions <= 8'h00;        
        
        count_reset <= 1'b0; // Reset pulse starts low
    end else begin
        // Reset?m pulsul de reset al contorului implicit la 0,
        // pentru a genera un puls de o singur? durat? de ceas (ceea ce e standard).
        count_reset <= 1'b0;
        
        //LOGICA DE SCRIERE (WRITE)
        if(write) begin
            case(addr)// 16-bit Registers (Scriere pe octe?i)
                ADDR_PERIOD_L: period[7:0] <= data_write;
                ADDR_PERIOD_H: period[15:8] <= data_write;
                
                ADDR_COMP1_L: compare1[7:0] <= data_write;
                ADDR_COMP1_H: compare1[15:8] <= data_write;

                ADDR_COMP2_L: compare2[7:0] <= data_write;
                ADDR_COMP2_H: compare2[15:8] <= data_write;
                
                // 8-bit Register
                ADDR_PRESCALE: prescale <= data_write;
                
                // 1-bit Registers (Lu?m doar bitul 0)
                ADDR_EN: en <= data_write[0]; 
                ADDR_UPDOWN: upnotdown <= data_write[0];
                ADDR_PWM_EN: pwm_en <= data_write[0];
                
                // COUNTER_RESET (Write-Only - genereaz? un puls de 1 ciclu de ceas)
                ADDR_RESET: begin
                    if (data_write[0]) begin // Resetul se genereaz? la scrierea unui '1'
                        count_reset <= 1'b1;
                    end
                end

                // 2-bit Register
                ADDR_FUNCTIONS: functions[1:0] <= data_write[1:0];

                default: ; // Ignor? scrierile c?tre adrese nedefinite
            endcase
        end
    end
end

// PARTEA COMBINATORIE (Citire - Multiplexor) ---
// Acest bloc decide ce date sunt returnate pe data_read.
always @(*) begin
data_read = 8'h00; // Valoare implicit? (pentru a evita latch-urile)

    if (read) begin
        case (addr)
            // 16-bit Registers (Citire pe octe?i)
            ADDR_PERIOD_L: data_read = period[7:0];
            ADDR_PERIOD_H: data_read = period[15:8];

            ADDR_COMP1_L: data_read = compare1[7:0];
            ADDR_COMP1_H: data_read = compare1[15:8];

            ADDR_COMP2_L: data_read = compare2[7:0];
            ADDR_COMP2_H: data_read = compare2[15:8];

            // COUNTER_VAL (Read Only - se cite?te intrarea counter_val)
            ADDR_VAL_L: data_read = counter_val[7:0];
            ADDR_VAL_H: data_read = counter_val[15:8];

            // 8-bit Register
            ADDR_PRESCALE: data_read = prescale;

            // 1-bit Registers (Return?m bitul relevant)
            ADDR_EN: data_read = {7'h00, en};
            ADDR_UPDOWN: data_read = {7'h00, upnotdown};
            ADDR_PWM_EN: data_read = {7'h00, pwm_en};
            
            // Other Registers
            ADDR_FUNCTIONS: data_read = {6'h00, functions[1:0]};
            
            default: data_read = 8'h00; // Adresele W-Only sau nedefinite returneaz? 0
        endcase
    end
end


endmodule