`timescale 1ns / 1ns

module instr_dcd_tb;

    // --- Semnale de Testbench (TB) ---
    parameter CLK_PERIOD = 10; // 10ns = 100MHz
    reg clk;
    reg rst_n;
    
    // Interfa?? de la spi_bridge.v
    reg byte_sync;    
    reg[7:0] data_in; 
    wire[7:0] data_out; 
    
    // Interfa?? c?tre regs.v
    reg[7:0] data_read; // Date simulate citite din Registre
    wire read;
    wire write;
    wire[5:0] addr;
    wire[7:0] data_write;

    // --- Instan?ierea Modulului de Testat (DUT) ---
    instr_dcd DUT (
        .clk(clk),
        .rst_n(rst_n),
        .byte_sync(byte_sync),
        .data_in(data_in),
        .data_out(data_out),
        .data_read(data_read),
        .read(read),
        .write(write),
        .addr(addr),
        .data_write(data_write)
    );

    // --- Generarea Ceasului (50% Duty Cycle) ---
    always begin
        clk = 1'b0;
        #(CLK_PERIOD / 2) clk = 1'b1;
        #(CLK_PERIOD / 2);
    end

    // --- Secven?a de Test (Main Body) ---
    initial begin
        // Setare ini?ial?
        byte_sync = 1'b0;
        data_in = 8'h00;
        data_read = 8'h00; 

        // 1. Reset Asincron
        $display("--- 1. RESET ASINCRON ---");
        rst_n = 1'b0;
        # (CLK_PERIOD * 3);
        rst_n = 1'b1;
        # (CLK_PERIOD);
        $display("Reset completat. FSM ar trebui sa fie in starea SETUP.");

        // 2. Test SCRIE (WRITE) - Instruc?iunea: 0x93, Data: 0xA6
        // 0x93: 1 (Write) | 0 (Low Byte) | 010011 (Adresa 0x13)
        $display("--- 2. TEST SCRIERE (WRITE) 0x93 - Adresa 0x13 LSB ---");
        
        // --- Ciclul 1: SETUP (Trimitem 0x93) ---
        data_in = 8'h93;
        byte_sync = 1'b1; // Activ?m byte_sync
        
        @(posedge clk) begin
            // Verificam ca semnalele de control sunt LOW in SETUP
            if (write == 1'b0 && read == 1'b0) 
                $display("Ciclul 1 (SETUP): Instructiune 0x93 primita. FSM -> DATA.");
            else
                $display("Ciclul 1 (SETUP) EROARE: Semnale de control active.");
        end
        byte_sync = 1'b0; // Dezactiv?m byte_sync
        
        // --- Ciclul 2: DATA (Trimitem 0xA6) ---
        data_in = 8'hA6; // Byte-ul de date
        byte_sync = 1'b1;
        
        @(posedge clk) begin
            // Asteptam ca semnalele de scriere si adresa sa fie active
            if (write == 1'b1 && read == 1'b0 && addr == 6'h13 && data_write == 8'hA6) 
                $display("Ciclul 2 (DATA): SUCCESS. Write=1, Addr=0x13, Data=0xA6.");
            else begin
                $display("Ciclul 2 (DATA) EROARE la Scrierea.");
                $display("Asteptat: W=1, R=0, Addr=0x13, Data=0xA6. Obtinut: W=%b, R=%b, Addr=%h, Data=%h", write, read, addr, data_write);
            end
        end
        byte_sync = 1'b0;
        
        $display("FSM -> SETUP. Asteptam 1 ciclu de pauza...");
        # (CLK_PERIOD);
        
        // 3. Test CITIRE (READ) - Instruc?iunea: 0x41, Date primite din regs: 0xEE
        // 0x41: 0 (Read) | 0 (Low Byte) | 000001 (Adresa 0x01) -> Adresa finala 0x01
        $display("--- 3. TEST CITIRE (READ) 0x41 - Adresa 0x01 LSB ---");
        data_read = 8'hEE; // Setam datele citite din registre

        // --- Ciclul 3: SETUP (Trimitem 0x41) ---
        data_in = 8'h41; 
        byte_sync = 1'b1; 
        
        @(posedge clk) begin
            if (write == 1'b0 && read == 1'b0) 
                $display("Ciclul 3 (SETUP): Instructiune 0x41 primita. FSM -> DATA.");
        end
        byte_sync = 1'b0;
        
        // --- Ciclul 4: DATA (Byte Dummy) ---
        data_in = 8'hFF; // Masterul trimite un byte dummy
        byte_sync = 1'b1;
        
        @(posedge clk) begin
            // Asteptam ca semnalele de citire si adresa sa fie active
            if (read == 1'b1 && write == 1'b0 && addr == 6'h01 && data_out == 8'hEE) 
                $display("Ciclul 4 (DATA): SUCCESS. Read=1, Addr=0x01, Data_out=0xEE.");
            else begin
                $display("Ciclul 4 (DATA) EROARE la Citire.");
                $display("Asteptat: R=1, W=0, Addr=0x01, Data_out=0xEE. Obtinut: R=%b, W=%b, Addr=%h, Data_out=%h", read, write, addr, data_out);
            end
        end
        byte_sync = 1'b0;

        $display("--- Simularea s-a terminat ---");
        $stop;
    end
endmodule