`default_nettype none
`timescale 1ns/1ns

module tb_spi_bridge;

    // --- 1. Semnale identice cu tb_top_system ---
    reg  clk;
    reg  rst_n;
    reg  sclk;
    reg  cs_n;
    reg  tb_mosi;
    wire tb_miso;

    // Semnale pentru a verifica iesirea din bridge
    wire byte_sync;
    wire [7:0] data_in;  // Ce a receptionat bridge-ul
    wire [7:0] data_out; // Intrare dummy pentru test

    // --- 2. Instantiere DUT (Device Under Test) ---
    spi_bridge uut (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .miso(tb_miso),
        .mosi(tb_mosi),
        .byte_sync(byte_sync),
        .data_in(data_in),
        .data_out(8'h00) // Nu testam MISO acum, punem 0
    );

    // --- 3. Timing IDENTIC cu tb_top_system ---
    localparam CLK_HALF   = 50;  
    localparam SCLK_HALF  = 50;   

    // Generator de ceas sistem (COPIAT din tb_top_system)
    initial begin
        clk = 1'b0;
        forever #(CLK_HALF) clk = ~clk;
    end

    // Dump VCD
    initial begin
        $dumpfile("waves_spi.vcd");
        $dumpvars(0, tb_spi_bridge);
    end

    // --- 4. Task-uri COPIATE din tb_top_system ---
    
    task apply_reset;
        begin
            rst_n  = 1'b0;
            cs_n   = 1'b1;
            sclk   = 1'b0;
            tb_mosi = 1'b0;
            #(10*CLK_HALF); 
            rst_n  = 1'b1;
            #(5*CLK_HALF);
        end
    endtask // <--- AICI ERA PROBLEMA (lipsea endtask)

    // Task exact ca in original (fara verificari interne, doar drive)
    task spi_transfer_byte;
        input  [7:0] tx;
        output [7:0] rx;
        integer i;
        begin
            rx = 8'h00;
            for (i = 7; i >= 0; i = i - 1) begin
                tb_mosi = tx[i];
                #(SCLK_HALF);
                sclk = 1'b1;            
                #(SCLK_HALF/2);
                // rx[i] = tb_miso; // Nu ne intereseaza rx pe miso acum
                #(SCLK_HALF/2);
                sclk = 1'b0;
            end
        end
    endtask // <--- AICI ERA PROBLEMA (lipsea endtask)

    // --- 5. Scenariu de Test ---
    reg [7:0] dummy_rx;

    initial begin
        $display("--- Start tb_spi_bridge (Replica tb_top_system) ---");
        
        apply_reset();

        // -------------------------------------------------------------
        // TEST: Simulam scrierea la REG_EN (Addr 0x02) cu Date 0x01
        // -------------------------------------------------------------
        
        // 1. Activam Chip Select
        #(SCLK_HALF);
        cs_n = 1'b0;

        // 2. Trimitem Primul Octet (Comanda): 0xC2 (11000010)
        spi_transfer_byte(8'hC2, dummy_rx);
        
        // Verificam imediat ce iese din Bridge
        #(10); // Mic delay pentru stabilitate
        if (data_in === 8'hC2 && byte_sync === 1'b1) 
            $display("[PASS] Byte 1 (Cmd): Sent 0xC2, Bridge Saw 0xC2");
        else
            $display("[FAIL] Byte 1 (Cmd): Sent 0xC2, Bridge Saw 0x%h, Sync=%b", data_in, byte_sync);

        // 3. Trimitem Al doilea Octet (Date): 0x01 (00000001)
        spi_transfer_byte(8'h01, dummy_rx);

        // Verificam al doilea octet
        #(10);
        if (data_in === 8'h01 && byte_sync === 1'b1) 
            $display("[PASS] Byte 2 (Dat): Sent 0x01, Bridge Saw 0x01");
        else
            $display("[FAIL] Byte 2 (Dat): Sent 0x01, Bridge Saw 0x%h, Sync=%b", data_in, byte_sync);

        // Dezactivam CS
        #(SCLK_HALF);
        cs_n = 1'b1;
        
        #(200);
        $finish;
    end

endmodule
`default_nettype wire