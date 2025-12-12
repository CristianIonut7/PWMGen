module instr_dcd (
    // Ceas si Reset
    input clk,
    input rst_n,
    
    // Intrare dinspre SPI Bridge
    input byte_sync,      // Puls care anunta ca a venit un octet nou
    input [7:0] data_in,  // Octetul primit (poate fi Comanda sau Date)
    output reg [7:0] data_out, // Ce trimitem inapoi (pentru citire)

    // Iesire catre Registri
    output reg read,
    output reg write,
    output reg [5:0] addr,
    input [7:0] data_read,
    output reg [7:0] data_write
);

    // --- Definirea Starilor FSM ---
    localparam STATE_CMD  = 1'b0; // Asteptam comanda (Primul Byte: 0xC2)
    localparam STATE_DATA = 1'b1; // Asteptam datele (Al doilea Byte: 0x01)

    reg state, next_state;

    // Flag-uri interne pentru a retine tipul comenzii
    reg rw_flag; // 1 = Write, 0 = Read
    reg hl_flag; // High/Low byte

    // --- 1. Registrul de Stare ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            state <= STATE_CMD;
        else 
            state <= next_state;
    end

    // --- 2. Logica Tranzitiei (Next State) ---
    always @(*) begin
        case (state)
            STATE_CMD: begin
                // Daca vine un byte_sync, inseamna ca am primit Comanda (0xC2).
                // Trecem in starea DATA sa asteptam valoarea.
                if (byte_sync) next_state = STATE_DATA;
                else           next_state = STATE_CMD;
            end

            STATE_DATA: begin
                // Daca vine un byte_sync AICI, inseamna ca am primit Datele (0x01).
                // Dupa ce le procesam, ne intoarcem la CMD pentru urmatoarea tranzactie.
                if (byte_sync) next_state = STATE_CMD;
                else           next_state = STATE_DATA;
            end
            
            default: next_state = STATE_CMD;
        endcase
    end

    // --- 3. Logica de Iesire (Output Logic) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read       <= 0;
            write      <= 0;
            addr       <= 0;
            data_write <= 0;
            data_out   <= 0;
            rw_flag    <= 0;
            hl_flag    <= 0;
        end else begin
            // Resetam pulsul de scriere/citire la fiecare ciclu (default 0)
            write <= 0;
            read  <= 0;

            // Logica depinde de starea CURENTA
            case (state)
                // --------------------------------------------------------
                // CAZUL 1: Suntem in faza de COMANDA (Primim 0xC2)
                // --------------------------------------------------------
                STATE_CMD: begin
                    if (byte_sync) begin
                        // Aici DOAR salvam informatiile despre comanda
                        // NU scriem nimic in registri inca!
                        rw_flag <= data_in[7];   // Bitul de Write
                        hl_flag <= data_in[6];   // Bitul High/Low
                        addr    <= data_in[5:0]; // Adresa (ex: 0x02)
                        
                        // Debug visual: data_write ramane vechi sau 0, nu conteaza
                        // Important e ca write ramane 0.
                    end
                end

                // --------------------------------------------------------
                // CAZUL 2: Suntem in faza de DATE (Asteptam 0x01)
                // --------------------------------------------------------
                STATE_DATA: begin
                    if (rw_flag) begin
                        // --- ESTE O OPERATIE DE SCRIERE ---
                        if (byte_sync) begin
                            // BINGO! A venit al doilea octet (0x01).
                            // Acum activam semnalul de scriere.
                            write      <= 1;       
                            data_write <= data_in; // data_in este acum 0x01
                        end
                    end else begin
                        // --- ESTE O OPERATIE DE CITIRE ---
                        // La citire, activam semnalul imediat ce intram in stare
                        // ca sa avem datele pregatite pentru SPI.
                        read <= 1;
                        // Selectam ce trimitem inapoi
                        data_out <= data_read; 
                    end
                end
            endcase
        end
    end

endmodule