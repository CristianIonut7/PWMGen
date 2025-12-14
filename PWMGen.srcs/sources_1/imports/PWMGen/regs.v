module regs (
    input clk, // semnal de ceas
    input rst_n, //semnal de reset asincron

    // Interfata cu Decoderul (pentru acces la registre dinspre CPU/Bus)
    input read, // semnal de citire
    input write, // semnal de scriere
    input [5:0] addr, // adresa registrului
    output reg [7:0] data_read, //datele de citire
    input [7:0] data_write, // datele de scris

    // Intrare dinspre Numarator
    input [15:0] counter_val, // valoare curenta a numaratorului

    // Iesiri catre modulul PWM
    output [15:0] period, // perioada totala a semnalului PWM
    output en, // semnal de activare numarator
    output count_reset, // semnal de resetare a numaratorului
    output upnotdown, //directia numaratorului (1= UP, 0 = DOWN)
    output [7:0] prescale, // valoarea de prescalare a ceasului
    output pwm_en, // semnal de activare a iesirii PWM
    output [7:0] functions, // bitii de functionare
    output [15:0] compare1, // valoarea de comparatie 1
    output [15:0] compare2 // valoarea de comparatie 2
);

    // Adrese (Conform tabelului de registre)
    localparam ADDR_PERIOD_L    = 6'h00; // Perioda LSB (bi?ii [7:0])
    localparam ADDR_PERIOD_H    = 6'h01; // Perioda MSB (bi?ii [15:8])
    localparam ADDR_EN          = 6'h02; // activare numarator
    localparam ADDR_COMP1_L     = 6'h03; // comparatie 1 LSB
    localparam ADDR_COMP1_H     = 6'h04; // comparatie 1 MSB
    localparam ADDR_COMP2_L     = 6'h05; // comparatie 2 LSB
    localparam ADDR_COMP2_H     = 6'h06; // comparatie 2 MSB
    localparam ADDR_RESET       = 6'h07; // resetare numarator
    localparam ADDR_VAL_L       = 6'h08; // valoare numarator LSB
    localparam ADDR_VAL_H       = 6'h09; // valoare numarator MSB
    localparam ADDR_PRESCALE    = 6'h0A; // valoare prescalare
    localparam ADDR_UPDOWN      = 6'h0B; // directie numarator
    localparam ADDR_PWM_EN      = 6'h0C; // activare iesire PWM
    localparam ADDR_FUNCTIONS   = 6'h0D; //biti functii

    // Registre Interne
    reg [15:0] r_period;
    reg [15:0] r_compare1;
    reg [15:0] r_compare2;
    reg [7:0] r_prescale;
    reg r_en;
    reg r_upnotdown;
    reg r_pwm_en;
    reg [7:0] r_functions;
    reg r_count_reset; //registrul temporar pentru semnalul de reset

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

    // Logica de scriere (controlata de ceas si reset)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            //valori initiale la resetare(asincron)
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
            // logica pentru resetare automata a pulsului de reset
            r_count_reset <= 1'b0;

            if (write) begin
                //executa scrierea sincronizata cu ceasul
                case (addr)
                    ADDR_PERIOD_L: r_period[7:0] <= data_write;
                    ADDR_PERIOD_H: r_period[15:8] <= data_write;
                    
                    ADDR_COMP1_L:  r_compare1[7:0] <= data_write;
                    ADDR_COMP1_H:  r_compare1[15:8] <= data_write;
                    
                    ADDR_COMP2_L:  r_compare2[7:0] <= data_write;
                    ADDR_COMP2_H:  r_compare2[15:8] <= data_write;
                    
                    ADDR_PRESCALE: r_prescale <= data_write;
                    
                    // scriere 1-bit(se foloseste bitul 0 din data_write)
                    // Decodorul trimite 0x01 -> bitul 0 e 1 -> EN devine 1.
                    ADDR_EN:       r_en <= data_write[0];
                    ADDR_UPDOWN:   r_upnotdown <= data_write[0];
                    ADDR_PWM_EN:   r_pwm_en <= data_write[0];
                    
                    // Dac? se scrie '1' (data_write[0] este 1), pulsul de reset este activat.
                    ADDR_RESET:    if(data_write[0]) r_count_reset <= 1'b1;
                    
                    // Scriere 8-bi?i pentru func?ii
                    ADDR_FUNCTIONS: r_functions <= data_write;
                endcase
            end
        end
    end

    //logica de citire (combinationala)
    always @(*) begin
    // Valoarea implicit? la citirea unei adrese nevalide
        data_read = 8'h00;
        if (read) begin
            case (addr)
            // Citire 16-bi?i (prin dou? adrese de 8 bi?i)
                ADDR_PERIOD_L: data_read = r_period[7:0];
                ADDR_PERIOD_H: data_read = r_period[15:8];
                ADDR_EN:       data_read = {7'h00, r_en};
                ADDR_COMP1_L:  data_read = r_compare1[7:0];
                ADDR_COMP1_H:  data_read = r_compare1[15:8];
                ADDR_VAL_L:    data_read = counter_val[7:0];
                ADDR_VAL_H:    data_read = counter_val[15:8];
                ADDR_PWM_EN:   data_read = {7'h00, r_pwm_en};
                
                default:       data_read = 8'h00; // Returneaz? 0x00 pentru adrese neimplementate
            endcase
        end
    end

endmodule