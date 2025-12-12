`timescale 1ns / 1ps

module instr_dcd_tb;

    // --- 1. Semnale ---
    reg clk;
    reg rst_n;
    reg byte_sync;
    reg [7:0] data_in;      // Ce vine de la SPI
    reg [7:0] data_read;    // Ce vine de la Registri (simulat)

    wire [7:0] data_out;    // Ce pleaca spre SPI
    wire read;
    wire write;
    wire [5:0] addr;
    wire [7:0] data_write;  // Ce pleaca spre Registri

    // --- 2. Instantiere DUT (Device Under Test) ---
    instr_dcd uut (
        .clk(clk),
        .rst_n(rst_n),
        .byte_sync(byte_sync),
        .data_in(data_in),
        .data_out(data_out),
        .read(read),
        .write(write),
        .addr(addr),
        .data_read(data_read),
        .data_write(data_write)
    );

    // --- 3. Generator de Ceas ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns perioada
    end

    // --- 4. Task pentru a simula primirea unui octet prin SPI ---
    task send_spi_byte(input [7:0] byte_val);
        begin
            @(posedge clk);
            data_in = byte_val;
            byte_sync = 1;     // Pulsam sincronizarea
            @(posedge clk);
            byte_sync = 0;     // Oprim pulsul
            #1; // Mic delay
        end
    endtask

    // --- 5. Scenariul de Test ---
    initial begin
        // Configurare Waveform
        $dumpfile("instr_dcd_dump.vcd");
        $dumpvars(0, instr_dcd_tb);

        // Initializare
        rst_n = 0;
        byte_sync = 0;
        data_in = 0;
        data_read = 0;

        $display("--- Start Test instr_dcd ---");
        
        // Eliberare Reset
        #20;
        rst_n = 1;
        #10;

        // ============================================================
        // TEST 1: SCRIERE (WRITE)
        // Scriem valoarea 0x55 la Adresa 0x02 (De ex: Enable)
        // Comanda: Write(1) | High(0) | Addr(000010) = 10000010 = 0x82
        // ============================================================
        $display("\n[T1] Start Tranzactie WRITE la adresa 0x02");
        
        // Pas 1: Trimitem COMANDA
        send_spi_byte(8'h82); 
        
        // Verificam imediat dupa comanda (Inca NU trebuie sa scrie)
        #5; 
        if (write == 1) $display("EROARE GRAVA: Write activat prematur (dupa primul octet)!");
        else $display("OK: Write este 0 dupa comanda (asteapta datele).");

        if (addr == 6'h02) $display("OK: Adresa latch-uita corect: 0x02");

        // Simulam pauza dintre octeti (SPI-ul e lent)
        #50; 

        // Pas 2: Trimitem DATELE
        $display("[T1] Trimitere Date: 0x55");
        send_spi_byte(8'h55);

        // Verificam daca scrie acum
        #1; // Imediat dupa ceas
        if (write == 1 && data_write == 8'h55) 
            $display("SUCCES: Write activat corect cu datele 0x55.");
        else 
            $display("EROARE: Write nu s-a activat sau date gresite. W=%b, D=0x%h", write, data_write);


        // ============================================================
        // TEST 2: CITIRE (READ)
        // Citim de la Adresa 0x0A (Prescale)
        // Comanda: Read(0) | Low(0) | Addr(001010) = 00001010 = 0x0A
        // ============================================================
        #50;
        $display("\n[T2] Start Tranzactie READ de la adresa 0x0A");

        // Simulam ca Registrii au valoarea 0x99 la acea adresa
        data_read = 8'h99; 

        // Pas 1: Trimitem COMANDA
        send_spi_byte(8'h0A);

        // In modulul tau, Read se activeaza in starea DATA (dupa comanda)
        #10; 
        if (read == 1) 
            $display("OK: Semnalul Read este activ.");
        
        if (data_out == 8'h99) 
            $display("SUCCES: Data_out a preluat valoarea 0x99.");
        else 
            $display("EROARE: Data_out incorect: 0x%h", data_out);

        // Pas 2: Al doilea byte "dummy" de la Master (pentru a tine ceasul)
        send_spi_byte(8'h00); 

        #50;
        $display("\n--- Final Test ---");
        $finish;
    end

endmodule