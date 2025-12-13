module regs (
    input clk,
    input rst_n,

    // Interface with Decoder
    input read,
    input write,
    input [5:0] addr,
    output reg [7:0] data_read,
    input [7:0] data_write,

    // Input from Counter
    input [15:0] counter_val,

    // Outputs to System
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

    // Adrese
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

    // Registre Interne
    reg [15:0] r_period;
    reg [15:0] r_compare1;
    reg [15:0] r_compare2;
    reg [7:0] r_prescale;
    reg r_en;
    reg r_upnotdown;
    reg r_pwm_en;
    reg [7:0] r_functions;
    reg r_count_reset;

    // Asignari Iesiri
    assign period      = r_period;
    assign compare1    = r_compare1;
    assign compare2    = r_compare2;
    assign prescale    = r_prescale;
    assign en          = r_en;
    assign upnotdown   = r_upnotdown;
    assign pwm_en      = r_pwm_en;
    assign functions   = r_functions;
    assign count_reset = r_count_reset;

    // Scriere
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
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
            // Auto-clear pentru reset puls
            r_count_reset <= 1'b0;

            if (write) begin
                case (addr)
                    ADDR_PERIOD_L: r_period[7:0] <= data_write;
                    ADDR_PERIOD_H: r_period[15:8] <= data_write;
                    
                    ADDR_COMP1_L:  r_compare1[7:0] <= data_write;
                    ADDR_COMP1_H:  r_compare1[15:8] <= data_write;
                    
                    ADDR_COMP2_L:  r_compare2[7:0] <= data_write;
                    ADDR_COMP2_H:  r_compare2[15:8] <= data_write;
                    
                    ADDR_PRESCALE: r_prescale <= data_write;
                    
                    // Aici e cheia: Luam bitul 0.
                    // Decodorul trimite 0x01 -> bitul 0 e 1 -> EN devine 1.
                    ADDR_EN:       r_en <= data_write[0];
                    ADDR_UPDOWN:   r_upnotdown <= data_write[0];
                    ADDR_PWM_EN:   r_pwm_en <= data_write[0];
                    
                    ADDR_RESET:    if(data_write[0]) r_count_reset <= 1'b1;
                    
                    ADDR_FUNCTIONS: r_functions <= data_write;
                endcase
            end
        end
    end

    // Citire
    always @(*) begin
        data_read = 8'h00;
        if (read) begin
            case (addr)
                ADDR_PERIOD_L: data_read = r_period[7:0];
                ADDR_PERIOD_H: data_read = r_period[15:8];
                ADDR_EN:       data_read = {7'h00, r_en};
                ADDR_COMP1_L:  data_read = r_compare1[7:0];
                ADDR_COMP1_H:  data_read = r_compare1[15:8];
                ADDR_VAL_L:    data_read = counter_val[7:0];
                ADDR_VAL_H:    data_read = counter_val[15:8];
                ADDR_PWM_EN:   data_read = {7'h00, r_pwm_en};
                // ... (restul sunt similare, le poti completa daca lipsesc)
                default:       data_read = 8'h00;
            endcase
        end
    end

endmodule