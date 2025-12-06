module spi_bridge (
    // peripheral clock signals
    input clk,     // Ceasul perifericului (de exemplu, 100MHz)
    input rst_n,   // Reset activ-low
    
    // SPI master facing signals
    input sclk,    // Ceasul SPI (sincron cu clk)
    input cs_n,    // Chip Select activ-low
    input mosi,    // Master Out Slave In (Data RX)
    output miso,   // Master In Slave Out (Data TX)
    
    // internal facing (catre Decodorul de Instructiuni)
    output reg byte_sync,      // Semnal: un byte a fost primit/transferat
    output wire [7:0] data_in, // Date primite (catre Decodor)
    input [7:0] data_out       // Date de transmis (din Decodor)
);

// Declaratii interne
reg [7:0] mosi_shift_reg;     // Shift register pentru receptie (RX)
reg [7:0] miso_shift_reg;     // Shift register pentru transmisie (TX)
reg [2:0] bit_counter;        // Contor pentru a urmari cei 8 biti (0 la 7)

// ----------------------------------------------------
// Logica de Detectare a Fronturilor SCLK (Sincron cu CLK)
// ----------------------------------------------------
// Aceasta inlocuieste $rose si $fell
reg sclk_d0, sclk_d1;
wire sclk_rise = (sclk_d1 == 1'b0) & (sclk_d0 == 1'b1); // Front Crescator
wire sclk_fall = (sclk_d1 == 1'b1) & (sclk_d0 == 1'b0); // Front Descrescator

// Sincronizare SCLK cu CLK si inregistrarea starii
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sclk_d0 <= 1'b0;
        sclk_d1 <= 1'b0;
    end else begin
        sclk_d0 <= sclk;
        sclk_d1 <= sclk_d0;
    end
end

// ----------------------------------------------------
// 1. Logica de Receptie (RX) - MOSI -> data_in
// Citire pe frontul crescator (sclk_rise) - CPOL=0, CPHA=0
// ----------------------------------------------------

assign data_in = mosi_shift_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mosi_shift_reg <= 8'h00;
        bit_counter    <= 3'b000;
        byte_sync      <= 1'b0;
    end else begin
        // Reseteaza byte_sync in ciclul urmator dupa ce a fost activat
        byte_sync <= 1'b0; 

        if (cs_n == 1'b0) begin // CS activ (LOW)
            
            if (sclk_rise) begin // Citire pe frontul Crescator (Detectat de circuitul de mai sus)
                
                // Shift: Bitul curent de pe MOSI intra in LSB.
                // Atentie: Daca se doreste MSB-first in shift, formula este: 
                // mosi_shift_reg <= {mosi_shift_reg[6:0], mosi};
                // Daca se doreste LSB-first:
                mosi_shift_reg <= {mosi, mosi_shift_reg[7:1]};
                
                // Contorizare si byte_sync
                if (bit_counter == 3'd7) begin 
                    byte_sync <= 1'b1; // Seteaza semnalul catre Decodor
                    bit_counter <= 3'b000; // Reseteaza contorul
                end else begin
                    bit_counter <= bit_counter + 3'b001;
                end
            end
        end else begin
            // Cand CS nu este activ, reseteaza contorul 
            bit_counter <= 3'b000; 
        end
    end
end

// ----------------------------------------------------
// 2. Logica de Transmisie (TX) - data_out -> MISO
// Plasare pe linie pe frontul descrescator (sclk_fall)
// ----------------------------------------------------

assign miso = miso_shift_reg[7]; // MISO este bitul curent (MSB)

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        miso_shift_reg <= 8'h00;
    end else begin
        if (cs_n == 1'b0) begin // CS activ (LOW)
            
            // Incarca datele de transmis in registrul intern la inceputul transferului
            if (bit_counter == 3'd0 && sclk_fall) begin 
                miso_shift_reg <= data_out;
            end
            
            // Logica de Transmisie pe frontul Descrescator al SCLK
            if (sclk_fall) begin 
                // Shift: Decalarea pentru a trimite bitul urmator
                miso_shift_reg <= miso_shift_reg << 1;
            end
        end 
    end
end

endmodule