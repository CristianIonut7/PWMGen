module spi_bridge (
    input clk,
    input rst_n,
    
    // SPI Signals
    input sclk,
    input cs_n,
    input mosi,
    output reg miso,

    // Internal Interface
    output reg byte_sync,
    output reg [7:0] data_in,
    input [7:0] data_out
);

    // Contor si Shift Register
    reg [2:0] bit_cnt;
    reg [7:0] shift_rx;
    reg [7:0] shift_tx;

    // --- RECEPTIE (RX) ---
    // Logica: Resetam pe CS_N high. In rest, pe frontul SCLK facem treaba.
    always @(posedge sclk or posedge cs_n) begin
        if (cs_n) begin
            bit_cnt   <= 3'd0;
            shift_rx  <= 8'h00;
            byte_sync <= 1'b0;
            // Nu resetam data_in aici ca sa putem citi valoarea in debug dupa CS
        end else begin
            // 1. Shiftam bitul curent (MSB First)
            // Formam byte-ul temporar
            shift_rx <= {shift_rx[6:0], mosi};
            
            // 2. Verificam daca e ultimul bit (bitul 7, adica al 8-lea puls)
            if (bit_cnt == 3'd7) begin
                // LATCH FINAL:
                // Scriem direct in data_in valoarea shiftata ANTERIOR + bitul curent (mosi)
                data_in   <= {shift_rx[6:0], mosi}; 
                byte_sync <= 1'b1;       // Activam sync
                bit_cnt   <= 3'd0;       // Resetam contorul pentru urmatorul byte
            end else begin
                byte_sync <= 1'b0;
                bit_cnt   <= bit_cnt + 1;
            end
        end
    end

    // --- TRANSMISIE (TX) ---
    // Datele se schimba pe front descrescator (negedge sclk)
    always @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            miso     <= 1'b0;
            shift_tx <= data_out; // Pre-incarcam datele
        end else begin
            if (bit_cnt == 3'd0) begin
                // Inceput de byte nou
                miso     <= data_out[7];
                shift_tx <= {data_out[6:0], 1'b0};
            end else begin
                // Shiftam
                miso     <= shift_tx[7];
                shift_tx <= {shift_tx[6:0], 1'b0};
            end
        end
    end

endmodule