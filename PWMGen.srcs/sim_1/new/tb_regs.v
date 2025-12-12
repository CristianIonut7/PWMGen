`timescale 1ns / 1ps

module regs_tb;

    // --- 1. Semnale pentru conectarea la DUT (Device Under Test) ---
    reg clk;
    reg rst_n;
    reg read;
    reg write;
    reg [5:0] addr;
    reg [7:0] data_write;
    wire [7:0] data_read;

    // Intrare simulat? de la num?r?tor
    reg [15:0] counter_val;

    // Ie?iri monitorizate
    wire [15:0] period;
    wire en;
    wire count_reset;
    wire upnotdown;
    wire [7:0] prescale;
    wire pwm_en;
    wire [7:0] functions;
    wire [15:0] compare1;
    wire [15:0] compare2;

    // --- 2. Instan?ierea Modulului regs ---
    regs uut (
        .clk(clk),
        .rst_n(rst_n),
        .read(read),
        .write(write),
        .addr(addr),
        .data_read(data_read),
        .data_write(data_write),
        .counter_val(counter_val),
        .period(period),
        .en(en),
        .count_reset(count_reset),
        .upnotdown(upnotdown),
        .prescale(prescale),
        .pwm_en(pwm_en),
        .functions(functions),
        .compare1(compare1),
        .compare2(compare2)
    );

    // --- 3. Definirea Adreselor (pentru lizibilitate în test) ---
    localparam ADDR_PERIOD_L    = 6'h00;
    localparam ADDR_PERIOD_H    = 6'h01;
    localparam ADDR_EN          = 6'h02;
    localparam ADDR_COMP1_L     = 6'h03;
    localparam ADDR_COMP1_H     = 6'h04;
    localparam ADDR_RESET       = 6'h07;
    localparam ADDR_VAL_L       = 6'h08;
    localparam ADDR_VAL_H       = 6'h09;
    localparam ADDR_PWM_EN      = 6'h0C;

    // --- 4. Generator de Ceas ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Perioada de 10ns (100MHz)
    end

    // --- 5. Task-uri ajut?toare pentru scriere ?i citire ---
    
    // Task pentru scriere pe magistral?
    task write_reg(input [5:0] target_addr, input [7:0] value);
        begin
            @(posedge clk);
            write = 1;
            read = 0;
            addr = target_addr;
            data_write = value;
            @(posedge clk);
            write = 0;
            addr = 0;
            data_write = 0;
            #1; // Mic delay pentru stabilitate vizual?
        end
    endtask

    // Task pentru citire ?i verificare (Self-checking)
    task check_reg(input [5:0] target_addr, input [7:0] expected_val);
        begin
            @(posedge clk);
            read = 1;
            write = 0;
            addr = target_addr;
            @(posedge clk); // A?tept?m o latur? de ceas
            #1; // L?s?m timp logicii combina?ionale s? se a?eze
            if (data_read !== expected_val) begin
                $display("EROARE la adresa 0x%h: Citit = 0x%h, Asteptat = 0x%h", target_addr, data_read, expected_val);
            end else begin
                $display("OK la adresa 0x%h: Citit = 0x%h", target_addr, data_read);
            end
            read = 0;
            addr = 0;
        end
    endtask

    // --- 6. Scenariul de Test (Main) ---
    initial begin
        // Ini?ializare semnale
        rst_n = 0;
        read = 0;
        write = 0;
        addr = 0;
        data_write = 0;
        counter_val = 16'h0000;

        $display("--- Start Simulare regs.v ---");

        // 1. Testare Reset
        #20;
        rst_n = 1; // Eliber?m resetul
        #10;
        $display("Reset eliberat. Verificare valori implicite.");
        if (period !== 0) $display("Eroare: Period nu e 0 dupa reset");
        if (en !== 0) $display("Eroare: En nu e 0 dupa reset");

        // 2. Testare Scriere ?i Citire Registru 16-bit (PERIOD)
        $display("\n--- Testare Registru 16-bit (PERIOD) ---");
        // Scriem 0xA5B2 în Period (B2 jos, A5 sus)
        write_reg(ADDR_PERIOD_L, 8'hB2);
        write_reg(ADDR_PERIOD_H, 8'hA5);
        
        // Verific?m ie?irea fizic? a modulului
        #5;
        if (period === 16'hA5B2) 
            $display("Succes: Iesirea 'period' este 0xA5B2");
        else 
            $display("Eroare: Iesirea 'period' este 0x%h", period);

        // Verific?m citirea înapoi pe magistral?
        check_reg(ADDR_PERIOD_L, 8'hB2);
        check_reg(ADDR_PERIOD_H, 8'hA5);

        // 3. Testare Registri de 1 bit (EN, PWM_EN)
        $display("\n--- Testare Registri 1-bit ---");
        write_reg(ADDR_EN, 8'h01);     // Activam Enable
        write_reg(ADDR_PWM_EN, 8'h03); // Scriem 3, dar ar trebui sa ia doar bitul 0
        
        #5;
        if (en === 1) $display("Succes: 'en' este HIGH");
        else $display("Eroare: 'en' nu s-a setat");

        // Verific?m c? PWM_EN a luat doar LSB-ul
        check_reg(ADDR_PWM_EN, 8'h01); 

        // Dezactiv?m EN
        write_reg(ADDR_EN, 8'h00);
        #5 if (en === 0) $display("Succes: 'en' a revenit la LOW");

        // 4. Testare Read-Only External Input (COUNTER_VAL)
        $display("\n--- Testare Citire Read-Only (COUNTER_VAL) ---");
        // Simul?m c? num?r?torul hardware a ajuns la valoarea 0x1234
        counter_val = 16'h1234;
        
        // Încerc?m s? scriem la aceast? adres? (ar trebui s? fie ignorat de logic?)
        write_reg(ADDR_VAL_L, 8'hFF); 
        
        // Citim valorile
        check_reg(ADDR_VAL_L, 8'h34); // Ar trebui s? fie 34, nu FF
        check_reg(ADDR_VAL_H, 8'h12);

        // 5. Testare Puls Reset (Auto-clearing)
        $display("\n--- Testare Puls Reset ---");
        // Scriem 1 la adresa de reset
        @(posedge clk);
        write = 1; 
        addr = ADDR_RESET; 
        data_write = 8'h01;
        
        // Imediat dup? scriere, count_reset ar trebui s? fie 1
        @(posedge clk); 
        #1; // Verificam imediat dup? frontul ceasului unde s-a facut scrierea
        if (count_reset === 1) 
            $display("Succes: count_reset este HIGH (Puls activ)");
        else 
            $display("Eroare: count_reset nu s-a activat");
            
        // Oprim scrierea
        write = 0;
        
        // La urm?torul ceas, ar trebui s? revin? singur la 0
        @(posedge clk);
        #1;
        if (count_reset === 0) 
            $display("Succes: count_reset a revenit la LOW (Auto-clear)");
        else 
            $display("Eroare: count_reset a ramas agatat in HIGH");

        // 6. Testare Adres? Invalid?
        $display("\n--- Testare Adresa Invalida ---");
        check_reg(6'h3F, 8'h00); // Adresa inexistenta ar trebui sa returneze 0

        $display("\n--- Final Simulare ---");
        $stop;
    end


// --- 7. Generare fi?ier de unde (VCD) pentru vizualizare ---
    initial begin
        // Creeaz? un fi?ier numit "dump.vcd"
        $dumpfile("dump.vcd"); 
        // Salveaz? toate semnalele (nivel 0) din modulul regs_tb
        $dumpvars(0, regs_tb); 
    end
endmodule