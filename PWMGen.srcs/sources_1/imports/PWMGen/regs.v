module regs (
    // Semnale de ceas ?i reset
    input clk,
    input rst_n,

    // Interfa?a cu Decodorul (Bus Interface)
    input read,
    input write,
    input [5:0] addr,
    output reg [7:0] data_read, // Portul de citire trebuie s? fie reg pentru always @(*)
    input [7:0] data_write,

    // Semnale de intrare (pentru citirea valorii curente a num?r?torului)
    input [15:0] counter_val,

    // Semnale de Ie?ire c?tre Num?r?tor ?i PWM
    output [15:0] period,
    output en,
    output count_reset,
    output upnotdown,
    output [7:0] prescale,
    output pwm_en,
    output [7:0] functions, 
    output [15:0] compare1,
    output [15:0] compare2
);

// --- 1. Declara?ii de Adrese (Bytes) ---
localparam ADDR_PERIOD_L    = 6'h00; 
localparam ADDR_PERIOD_H    = 6'h01; 

localparam ADDR_EN          = 6'h02; 

localparam ADDR_COMP1_L     = 6'h03; 
localparam ADDR_COMP1_H     = 6'h04; 

localparam ADDR_COMP2_L     = 6'h05; 
localparam ADDR_COMP2_H     = 6'h06; 

localparam ADDR_RESET       = 6'h07; 

localparam ADDR_VAL_L       = 6'h08; 
localparam ADDR_VAL_H       = 6'h09; 

localparam ADDR_PRESCALE    = 6'h0A; 
localparam ADDR_UPDOWN      = 6'h0B; 
localparam ADDR_PWM_EN      = 6'h0C; 
localparam ADDR_FUNCTIONS   = 6'h0D; 


// --- 2. Registre Interne (D-Flip-Flop-uri) ---
// Folosim prefixul 'r_' pentru a stoca valorile intern
reg [15:0] r_period;
reg [15:0] r_compare1;
reg [15:0] r_compare2;
reg [7:0] r_prescale; 
reg r_en;
reg r_upnotdown;
reg r_pwm_en;
reg [7:0] r_functions;
reg r_count_reset;


// --- 3. Atribuiri c?tre Porturile de Ie?ire ---
// Conecteaz? registrele interne (reg) la porturile de ie?ire (wire)
assign period      = r_period;
assign compare1    = r_compare1;
assign compare2    = r_compare2;
assign prescale    = r_prescale;
assign en          = r_en;
assign upnotdown   = r_upnotdown;
assign pwm_en      = r_pwm_en;
assign functions   = r_functions;
assign count_reset = r_count_reset; 

// --- 4. Logica Secven?ial? (Scriere ?i Reset) ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset asincron - folosind r_*
        r_period    <= 16'h0000;
        r_compare1  <= 16'h0000;
        r_compare2  <= 16'h0000;
        r_prescale  <= 8'h00;
        r_en        <= 1'b0;
        r_upnotdown <= 1'b0;
        r_pwm_en    <= 1'b0;
        r_functions <= 8'h00;
        r_count_reset <= 1'b0;
    end else begin
        // Reset-ul contorului este implicit 0, se seteaz? la 1 doar la scriere
        r_count_reset <= 1'b0; 

        // Logica de Scrierea (WRITE)
        if (write) begin
            case (addr)
                // 16-bit Registers (Scriere pe octe?i: Low/High)
                ADDR_PERIOD_L: r_period[7:0] <= data_write;
                ADDR_PERIOD_H: r_period[15:8] <= data_write;

                ADDR_COMP1_L: r_compare1[7:0] <= data_write;
                ADDR_COMP1_H: r_compare1[15:8] <= data_write;

                ADDR_COMP2_L: r_compare2[7:0] <= data_write;
                ADDR_COMP2_H: r_compare2[15:8] <= data_write;

                // 8-bit Register
                ADDR_PRESCALE: r_prescale <= data_write;

                // 1-bit Registers (Folosim data_write[0])
                ADDR_EN:       r_en <= data_write[0];
                ADDR_UPDOWN:   r_upnotdown <= data_write[0];
                ADDR_PWM_EN:   r_pwm_en <= data_write[0];

                // COUNTER_RESET (Write-Only, genereaz? puls de 1 ciclu de ceas)
                ADDR_RESET: begin
                    if (data_write[0]) begin
                        r_count_reset <= 1'b1; // Seteaz? pulsul la 1 (activ)
                    end
                end

                // 8-bit Register 
                ADDR_FUNCTIONS: r_functions <= data_write;

                default: ; // Ignor? scrierile c?tre adrese nedefinite
            endcase
        end
    end
end

// --- 5. Logica Combinatorie (Citire) ---
// Decide ce date sunt returnate pe data_read (Multiplexor)
always @(*) begin
    data_read = 8'h00; // Valoare implicit? (pentru a evita latch-urile)

    if (read) begin
        case (addr)
            // 16-bit Registers (Citire pe octe?i)
            ADDR_PERIOD_L: data_read = r_period[7:0];
            ADDR_PERIOD_H: data_read = r_period[15:8];

            ADDR_COMP1_L: data_read = r_compare1[7:0];
            ADDR_COMP1_H: data_read = r_compare1[15:8];

            ADDR_COMP2_L: data_read = r_compare2[7:0];
            ADDR_COMP2_H: data_read = r_compare2[15:8];

            // COUNTER_VAL (Read Only - cite?te intrarea counter_val)
            ADDR_VAL_L: data_read = counter_val[7:0];
            ADDR_VAL_H: data_read = counter_val[15:8];

            // 8-bit Register
            ADDR_PRESCALE: data_read = r_prescale;

            // 1-bit Registers (Returneaz? bitul relevant extins la 8 bi?i)
            ADDR_EN: data_read = {7'h00, r_en};
            ADDR_UPDOWN: data_read = {7'h00, r_upnotdown};
            ADDR_PWM_EN: data_read = {7'h00, r_pwm_en};
            
            // 8-bit Register
            ADDR_FUNCTIONS: data_read = r_functions;
            
            ADDR_RESET: data_read = 8'h00; 
            default: data_read = 8'h00;
        endcase
    end
end

endmodule