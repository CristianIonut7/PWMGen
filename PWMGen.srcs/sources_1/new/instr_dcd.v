module instr_dcd (
    // Semnale de ceas si reset
    input clk,
    input rst_n,
    
    // Interfata catre SPI Bridge
    input byte_sync,        // Puls de 1 ciclu CLK la sosirea unui byte
    input [7:0] data_in,    // Byte-ul primit de la Master (comanda sau date)
    output reg [7:0] data_out,   // Byte-ul de raspuns catre Master (MISO data)
    
    // Interfata catre Bancul de Registre (Memoria Interna)
    output reg read,
    output reg write,
    output reg [5:0] addr,
    input [7:0] data_read,  // Date citite din registru (de la bancul de registre)
    output reg [7:0] data_write // Date de scris in registru (catre bancul de registre)
);

// --- STARII FSM ---
localparam S_SETUP = 2'b00; // Starea initiala: Asteapta byte-ul de comanda
localparam S_DATA  = 2'b01; // Asteapta sau trimite byte-ul de date
reg [1:0] state;

// --- REGISTRE INTERNE PENTRU STOCAREA INSTRUCTIUNII (intre faze) ---
// Acestea retin informatia din primul byte (SETUP)
reg op_reg;          // data_in[7]: 1=Write, 0=Read
reg sel_reg;         // data_in[6]: 1=High Byte [15:8], 0=Low Byte [7:0]
reg [5:0] addr_reg;  // data_in[5:0]: Adresa pe 6 biti

// --- PARAMETRI DE DECODARE ---
localparam OP_WRITE = 1'b1;
localparam OP_READ  = 1'b0;

// ----------------------------------------------------------------------
// 1. LOGICA STARII FSM (Sequential)
// ----------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset asincron (Initializare a tuturor registrelor la o valoare cunoscuta)
        state <= S_SETUP;
        op_reg <= OP_WRITE;
        sel_reg <= 1'b0;
        addr_reg <= 6'h00;
        
        // Resetare semnale de IESIRE (pentru a preveni starea 'X' / rosu)
        read <= 1'b0;
        write <= 1'b0;
        addr <= 6'h00;
        data_write <= 8'h00;
        data_out <= 8'h00; 
        
    end else begin
        // Reseteaza semnalele de control in fiecare ciclu
        read  <= 1'b0;
        write <= 1'b0;

        // Tranzitiile de stare si executia se fac doar la byte_sync (puls de 1 CLK)
        if (byte_sync) begin
            case (state)
                S_SETUP: begin
                    // --------------------------------------------------
                    // FAZA 1: DECODARE INSTRUCTIUNI (SETUP BYTE PRIMIT)
                    // --------------------------------------------------
                    
                    // Stocheaza parametrii din data_in pentru a fi folositi in Faza de Date
                    op_reg      <= data_in[7];
                    sel_reg     <= data_in[6];
                    addr_reg    <= data_in[5:0];
                    
                    // Adresa (data_in[5:0]) este afisata pe bus-ul addr
                    addr <= data_in[5:0];
                    
                    // Decodorul trece la faza DATA
                    state <= S_DATA; 
                    
                end
                
                S_DATA: begin
                    // --------------------------------------------------
                    // FAZA 2: EXECUTIE (DATA BYTE PRIMIT)
                    // --------------------------------------------------
                    
                    // Adresa (stocata anterior) este mentinuta pe bus-ul addr
                    addr <= addr_reg; 

                    if (op_reg == OP_WRITE) begin
                        // --------------------------------
                        // OPERATIE DE SCRIERE
                        // --------------------------------
                        
                        // data_write primeste datele de la Master
                        data_write <= data_in; 
                        
                        // Activeaza semnalul WRITE pentru un ciclu CLK
                        write <= 1'b1;
                        
                        // Setarea lui data_out (raspuns catre Master)
                        data_out <= 8'h01; // ACK

                    end else begin // OP_READ
                        // --------------------------------
                        // OPERATIE DE CITIRE
                        // --------------------------------
                        
                        // Activeaza semnalul READ pentru un ciclu CLK
                        read <= 1'b1;
                        
                        // data_out primeste byte-ul citit de pe data_read
                        data_out <= data_read;
                    end
                    
                    // Operatia in 2 etape este completa. Incepe o noua comanda.
                    state <= S_SETUP; 
                    
                end
                
                default: state <= S_SETUP;
            endcase
        end
    end
end

endmodule