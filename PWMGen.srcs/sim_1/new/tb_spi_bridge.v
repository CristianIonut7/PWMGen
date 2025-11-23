`timescale 1ns / 1ps

module tb_spi_bridge;

    // ----------------------------------------------------
    // 1. Semnale de Interfa?? (Inputs ca reg, Outputs ca wire)
    // ----------------------------------------------------

    // Ceasul perifericului (100MHz -> Perioada 10ns)
    reg clk = 1'b0;
    reg rst_n = 1'b0;

    // SPI Master (TB) facing signals
    reg sclk = 1'b0;
    reg cs_n = 1'b1;
    reg mosi = 1'b0;
    wire miso;

    // Internal facing (catre Decodor - pentru verificare)
    wire byte_sync;
    wire [7:0] data_in;
    // data_out este reg in TB, simuleaza datele venite de la Decodor
    reg [7:0] data_out = 8'hAA; 
    
    // Semnal pentru a monitoriza contorul intern (pentru debugging)
    wire [2:0] monitor_bit_counter; 
    
    // Variabila folosita in blocul initial pentru a stoca datele primite de Master
    reg [7:0] master_rx_data; 

    // Parametri
    parameter CLK_PERIOD = 10; // 10 ns (100 MHz)
    parameter SCLK_HALF_PERIOD = 5; // 5 ns - presupunem ca CLK SPI este CLK Periferic

    // ----------------------------------------------------
    // 2. Instantierea Modulului de Testat (DUT)
    // ----------------------------------------------------

    spi_bridge DUT (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso),
        .byte_sync(byte_sync),
        .data_in(data_in),
        .data_out(data_out)
    );
    
    // Conectarea la semnalul intern (rezolva eroarea de compilare)
    assign monitor_bit_counter = DUT.bit_counter;

    // ----------------------------------------------------
    // 3. Generarea Ceasului Perifericului (CLK)
    // ----------------------------------------------------

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ----------------------------------------------------
    // 4. Task-uri Utile (Simuleaza Master SPI)
    // Task-ul este declarat AUTOMATIC pentru a permite variabile locale
    // ----------------------------------------------------

    // Task pentru a simula o transmisie/receptie de 8 bi?i
    task automatic spi_transfer_byte;
        input [7:0] tx_data;
        output [7:0] rx_data;
        reg [7:0] temp_rx_data; // Declaratie fara initializare
        integer i;
        begin
            temp_rx_data = 8'h00; // Initializare in blocul procedural
            cs_n = 1'b0; // Activeaza Chip Select
            
            $display("[Timp %0t] SPI START (TX: %h, Asteapta RX: %h)", $time, tx_data, data_out);

            // Transfera 8 bi?i (MSB primul)
            for (i = 7; i >= 0; i = i - 1) begin
                
                // 1. MASTER plaseaza datele pe MOSI 
                mosi = tx_data[i];
                #(SCLK_HALF_PERIOD) sclk = 1'b1; // Front Crescator SCLK (SLAVE citeste MOSI)
                
                // 2. MASTER citeste MISO
                temp_rx_data[i] = miso;
                
                // Foloseste semnalul de monitorizare extern
                $display("[Timp %0t] Bit %0d: MOSI=%b, MISO=%b, Counter=%d", $time, i, mosi, miso, monitor_bit_counter);

                // 3. MASTER asteapta
                #(SCLK_HALF_PERIOD) sclk = 1'b0; // Front Descrescator SCLK (SLAVE plaseaza noul MISO)
            end
            
            cs_n = 1'b1; // Dezactiveaza Chip Select
            rx_data = temp_rx_data;

            $display("[Timp %0t] SPI END. Receptionat: %h. Data_in Slave: %h.", $time, rx_data, data_in);
        end
    endtask

    // ----------------------------------------------------
    // 5. Stimuli de Test
    // ----------------------------------------------------

    initial begin
        
        // Initial setup
        rst_n = 1'b0;       
        sclk = 1'b0;
        cs_n = 1'b1;
        mosi = 1'b0;
        
        #20; // Asteapta stabilitatea
        
        // Reset
        rst_n = 1'b1; // Start
        $display("[Timp %0t] Reset terminat.", $time);
        
        #10;
        
        // ----------------------------------------
        // TEST 1: Receptie (Master TX: 0x93 -> Slave RX)
        // ----------------------------------------
        
        $display("\n--- TEST 1: Scriere (Master -> Slave) ---");
        spi_transfer_byte(8'h93, master_rx_data); 
        
        // Verificare receptie Slave
        #10;
        if (data_in === 8'h93 && byte_sync === 1'b1) begin
            $display("[Timp %0t] TEST 1 SUCCES: Slave a receptionat 0x93 si byte_sync activ.", $time);
        end else begin
            $display("[Timp %0t] TEST 1 ESEC: Slave nu a receptionat 0x93 (data_in: %h, sync: %b).", $time, data_in, byte_sync);
        end
        
        #20;

        // ----------------------------------------
        // TEST 2: Transmisie (Master RX <- Slave TX: 0xAA)
        // ----------------------------------------
        
        $display("\n--- TEST 2: Citire (Slave -> Master) ---");
        // Masterul trimite un byte 'dummy' (0x00) pentru a genera ceasul de citire
        spi_transfer_byte(8'h00, master_rx_data); 
        
        // Verificare transmisie Slave
        #10;
        if (master_rx_data === 8'hAA) begin
            $display("[Timp %0t] TEST 2 SUCCES: Master a citit 0xAA de la Slave.", $time);
        end else begin
            $display("[Timp %0t] TEST 2 ESEC: Master a citit %h, asteptat 0xAA.", $time, master_rx_data);
        end
        
        #50;
        
        $finish;
    end

endmodule