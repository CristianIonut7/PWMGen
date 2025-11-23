`timescale 1ns / 1ps

module tb_instr_dcd;

    // ----------------------------------------------------
    // 1. Semnale de Interfata Decodor (Inputs ca reg, Outputs ca wire)
    // ----------------------------------------------------

    // Interfata FSM/Ceas
    reg clk;
    reg rst_n;
    
    // Interfata SPI Bridge (Simulata)
    reg byte_sync;
    reg [7:0] data_in;
    wire [7:0] data_out;
    
    // Interfata Banc de Registre (Decodor -> Banc)
    wire read;
    wire write;
    wire [5:0] addr;
    wire [7:0] data_write;

    // Interfata Banc de Registre (Banc -> Decodor)
    // Acesta va fi setat manual de catre TB pentru a simula datele citite.
    reg [7:0] data_read_sim; 

    // Parametri
    parameter CLK_PERIOD = 10; // 10 ns (100 MHz)
    
    // ----------------------------------------------------
    // 2. INSTANTIEREA MODULULUI instr_dcd (DUT)
    // ----------------------------------------------------
    instr_dcd DUT (
        .clk(clk),
        .rst_n(rst_n),
        .byte_sync(byte_sync),
        .data_in(data_in),
        .data_out(data_out),
        
        // Interfata catre Bancul de Registre
        .read(read),
        .write(write),
        .addr(addr),
        .data_read(data_read_sim), 
        .data_write(data_write)
    );

    // ----------------------------------------------------
    // 3. Generarea Ceasului Perifericului (CLK)
    // ----------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end
    
    // ----------------------------------------------------
    // 4. Task-uri Utile (Simuleaza transferul SPI in 2 cicluri CLK)
    // ----------------------------------------------------
    
    task automatic send_command;
        input [7:0] setup_byte; // Byte-ul de Setup (Comanda R/W)
        input [7:0] data_byte;  // Byte-ul de Date (Scriere) sau Dummy (Citire)
        input is_write;         // 1 pentru Write, 0 pentru Read
        
        reg [7:0] expected_data_out; // Valoarea asteptata la iesirea data_out (Decodor)
        reg [7:0] expected_data_write; // Valoarea asteptata pentru data_write (Scriere)
        
        begin
            $display("\n[Timp %0t] --- INCEPE OPERATIE %s (SETUP: 0x%h, DATA: 0x%h) ---", 
                     $time, (is_write ? "SCRIERE" : "CITIRE"), setup_byte, data_byte);
            
            // Seteaza valoarea asteptata
            expected_data_write = is_write ? data_byte : 8'hXX; // data_write este relevant doar la Write
            expected_data_out = is_write ? 8'h01 : data_read_sim; // ACK la Write, data_read_sim la Read
            
            // PASUL 1: SETUP (Trimite Comanda)
            data_in = setup_byte; 
            byte_sync = 1'b1; #1; byte_sync = 1'b0; // Puls byte_sync
            # (CLK_PERIOD - 1); // Asteapta pana la urmatorul flanc pozitiv CLK
            
            // Verificare Faza SETUP (Adresa setata pe bus in acest ciclu)
            if (addr !== setup_byte[5:0]) $display("[Timp %0t] ESEC SETUP: Adresa 0x%h incorecta (Asteptat 0x%h).", $time, addr, setup_byte[5:0]);
            
            // PASUL 2: DATA (Trimite Datele / Dummy)
            data_in = data_byte;
            
            // Pentru Citire: Simuleaza raspunsul bancului de registre INAINTE de flancul CLK
            if (!is_write) begin
                // Injectam o valoare hardcodata pe data_read_sim (Intrarea Decodorului)
                // Folosim valori distincte pentru a verifica selectia LSB/MSB
                if (setup_byte[6] == 1'b1) begin // MSB Read
                    data_read_sim = 8'hAD; // Ex: A D
                end else begin // LSB Read
                    data_read_sim = 8'hDE; // Ex: D E
                end // Am adaugat 'end' lipsa pentru a rezolva eroarea de sintaxa
                expected_data_out = data_read_sim;
                $display("[Timp %0t] SIMULATOR: Pune 0x%h pe data_read (Intrare Decodor).", $time, data_read_sim);
            end
            
            byte_sync = 1'b1; #1; byte_sync = 1'b0; // Puls byte_sync
            # (CLK_PERIOD - 1);

            // Verificare Faza DATA (Semnale de Control si Output)
            if (is_write) begin
                // Asteptat: write=1, read=0, data_write=data_byte, data_out=ACK
                if (write !== 1'b1) $display("[Timp %0t] ESEC DATA (W): Semnalul write NU a fost activat.", $time);
                if (read !== 1'b0) $display("[Timp %0t] ESEC DATA (W): Semnalul read a fost activat (trebuie 0).", $time);
                if (data_write !== expected_data_write) $display("[Timp %0t] ESEC DATA (W): data_write (0x%h) incorect (Asteptat 0x%h).", $time, data_write, expected_data_write);
                if (data_out !== expected_data_out) $display("[Timp %0t] ESEC DATA (W): data_out (0x%h) incorect (Asteptat ACK 0x01).", $time, data_out);
            end else begin // READ
                // Asteptat: read=1, write=0, data_out=data_read_sim
                if (read !== 1'b1) $display("[Timp %0t] ESEC DATA (R): Semnalul read NU a fost activat.", $time);
                if (write !== 1'b0) $display("[Timp %0t] ESEC DATA (R): Semnalul write a fost activat (trebuie 0).", $time);
                if (data_out !== expected_data_out) $display("[Timp %0t] ESEC DATA (R): data_out (0x%h) incorect (Asteptat 0x%h).", $time, data_out, expected_data_out);
            end

        end
    endtask

    // ----------------------------------------------------
    // 5. Stimuli de Test
    // ----------------------------------------------------

    initial begin
        
        // --- SETUP Initial ---
        rst_n = 1'b0;       
        byte_sync = 1'b0;
        data_in = 8'h00;
        data_read_sim = 8'h00; 
        
        #20; 
        
        // Reset
        rst_n = 1'b1; 
        $display("[Timp %0t] Reset terminat. FSM in S_SETUP.", $time);
        
        #10;

        // ----------------------------------------------------------
        // TEST 1: SCRIERE LSB la Adresa 0x01
        // Comanda: 10000001 (0x81) -> Write(1), LSB(0), Addr 0x01
        // Date: 0xAA
        // Asteptat: write=1, data_write=0xAA, data_out=0x01 (ACK)
        // ----------------------------------------------------------
        send_command(8'h81, 8'hAA, 1'b1);
        #10;
        
        // ----------------------------------------------------------
        // TEST 2: SCRIERE MSB la Adresa 0x02
        // Comanda: 11000010 (0xC2) -> Write(1), MSB(1), Addr 0x02
        // Date: 0x55
        // Asteptat: write=1, data_write=0x55, data_out=0x01 (ACK)
        // ----------------------------------------------------------
        send_command(8'hC2, 8'h55, 1'b1);
        #10;

        // ----------------------------------------------------------
        // TEST 3: CITIRE LSB de la Adresa 0x01
        // Comanda: 00000001 (0x01) -> Read(0), LSB(0), Addr 0x01
        // Dummy: 0x00. Simulator injecteaza 0xDE
        // Asteptat: read=1, data_out=0xDE
        // ----------------------------------------------------------
        send_command(8'h01, 8'h00, 1'b0);
        #10;

        // ----------------------------------------------------------
        // TEST 4: CITIRE MSB de la Adresa 0x02
        // Comanda: 01000010 (0x42) -> Read(0), MSB(1), Addr 0x02
        // Dummy: 0x00. Simulator injecteaza 0xAD
        // Asteptat: read=1, data_out=0xAD
        // ----------------------------------------------------------
        send_command(8'h42, 8'h00, 1'b0);
        #10;
        
        $finish;

    end

endmodule