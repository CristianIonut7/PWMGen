`default_nettype none
`timescale 1ns/1ns

module tb_dcd_exact;

    // --- 1. Semnale ---
    reg clk;
    reg rst_n;
    
    // Intrari (Simuleaza iesirea din SPI Bridge)
    reg byte_sync;
    reg [7:0] data_in;
    
    // Intrari (Simuleaza citirea din Registri)
    reg [7:0] data_read;

    // Iesiri monitorizate
    wire read;
    wire write;
    wire [5:0] addr;
    wire [7:0] data_write;
    wire [7:0] data_out;

    // --- 2. Instantiere instr_dcd (DUT) ---
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

    // --- 3. Generare Ceas (100MHz - ca in Top) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns perioada
    end

    // Parametri (Aceiasi ca in Top)
    localparam [5:0] REG_PERIOD        = 6'h00;
    localparam [5:0] REG_COUNTER_EN    = 6'h02;
    localparam [5:0] REG_COMPARE1      = 6'h03;
    localparam [5:0] REG_COMPARE2      = 6'h05;
    localparam [5:0] REG_COUNTER_RESET = 6'h07;
    localparam [5:0] REG_COUNTER_VAL   = 6'h08;
    localparam [5:0] REG_PRESCALE      = 6'h0A;
    localparam [5:0] REG_PWM_EN        = 6'h0C;
    localparam [5:0] REG_FUNCTIONS     = 6'h0D;
    localparam [1:0] FUNCTION_ALIGN_LEFT = 2'b00;

    // --- 4. Task care imita EXACT 'spi_write_reg' din Top ---
    // In Top, un byte dureaza 8 * 100ns = 800ns sa fie trimis.
    // Deci intre byte_sync 1 si byte_sync 2 trebuie sa treaca aprox 800ns.
    task mimic_top_write;
        input [5:0] target_addr;
        input [7:0] target_data;
        
        reg [7:0] cmd_byte;
        begin
            cmd_byte = {1'b1, 1'b1, target_addr}; // Calcul Comanda (Write)

            $display("--- Mimic Write: Addr 0x%h, Data 0x%h ---", target_addr, target_data);

            // 1. BRIDGE-ul termina primul octet (Comanda)
            @(posedge clk);
            data_in = cmd_byte;
            byte_sync = 1;
            @(posedge clk);
            byte_sync = 0;

            // VERIFICARE: Decodorul NU trebuie sa scrie acum!
            if (write) begin
                $display("   [FAIL CRITIC] Decodorul a scris la primirea Comenzii (0x%h)!", cmd_byte);
                $stop; 
            end

            // 2. PAUZA DE TRANSMISIE (Simulam timpul cat Top-ul trimite al doilea byte)
            // In Top: spi_transfer_byte dureaza ~800ns.
            #800; 

            // 3. BRIDGE-ul termina al doilea octet (Datele)
            @(posedge clk);
            data_in = target_data;
            byte_sync = 1;
            
            // VERIFICARE: Acum trebuie sa scrie!
            // Verificam imediat dupa activarea byte_sync
            #1; 
            if (write === 1 && data_write === target_data && addr === target_addr)
                $display("   [PASS] Scriere Reusita: Addr=0x%h, Data=0x%h", addr, data_write);
            else
                $display("   [FAIL] Nu a scris corect! Write=%b, Addr=0x%h, Data=0x%h", write, addr, data_write);

            @(posedge clk);
            byte_sync = 0;
            
            // Pauza intre tranzactii (ca in Top: #(4*CLK_HALF))
            #200; 
        end
    endtask

    // --- 5. Task care imita EXACT 'spi_read_reg' din Top ---
    task mimic_top_read;
        input [5:0] target_addr;
        input [7:0] simulated_val;
        
        reg [7:0] cmd_byte;
        begin
            cmd_byte = {1'b0, 1'b1, target_addr}; // Calcul Comanda (Read)
            data_read = simulated_val; // Simulam ca registrul are valoarea asta

            $display("--- Mimic Read: Addr 0x%h (Expect 0x%h) ---", target_addr, simulated_val);

            // 1. BRIDGE-ul termina primul octet (Comanda)
            @(posedge clk);
            data_in = cmd_byte;
            byte_sync = 1;
            @(posedge clk);
            byte_sync = 0;

            // Decodorul are timp sa activeze semnalul READ acum
            #10;
            if (read === 1 && data_out === simulated_val)
                $display("   [PASS] Read Activ: data_out = 0x%h", data_out);
            else
                $display("   [FAIL] Read Inactiv sau Date Gresite! Read=%b, Out=0x%h", read, data_out);

            // 2. PAUZA DE TRANSMISIE (Simulam timpul cat Top-ul citeste byte-ul dummy)
            #800;

            // 3. BRIDGE-ul termina al doilea octet (Dummy 0x00 trimis de Master)
            @(posedge clk);
            data_in = 8'h00; 
            byte_sync = 1; 
            @(posedge clk);
            byte_sync = 0; // Aici decodorul revine la starea CMD

            #200;
        end
    endtask

    // --- 6. Scenariul de Test (Copia Fidela a Top-ului) ---
    initial begin
        $dumpfile("dcd_exact.vcd");
        $dumpvars(0, tb_dcd_exact);

        // Reset
        rst_n = 0; byte_sync = 0; data_in = 0; data_read = 0;
        #200; // Reset lung ca in Top
        rst_n = 1; 
        #100;

        $display("START TB_DCD_EXACT");

        // Executam exact secventa din tb_top_system
        mimic_top_write(REG_PERIOD,     8'd7);
        mimic_top_write(REG_PRESCALE,   8'd0);
        mimic_top_write(REG_COMPARE1,   8'd3);
        mimic_top_write(REG_COUNTER_EN, 8'd1); // Aici era problema cu 0xC2
        mimic_top_write(REG_PWM_EN,     8'd1);
        mimic_top_write(REG_FUNCTIONS,  {6'b0, FUNCTION_ALIGN_LEFT});

        mimic_top_write(REG_COUNTER_RESET, 8'd1);
        mimic_top_write(REG_COUNTER_RESET, 8'd0);

        // Test Citire
        mimic_top_read(REG_COUNTER_VAL, 8'h55); 

        // Update-uri ulterioare
        mimic_top_write(REG_COMPARE1, 8'd2);
        mimic_top_write(REG_COMPARE2, 8'd6);
        mimic_top_write(REG_FUNCTIONS, {6'b0, 2'b10});

        $display("FINALIZAT");
        $finish;
    end

endmodule