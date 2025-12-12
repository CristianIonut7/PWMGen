`timescale 1ns/1ps

module tb_spi_bridge;

    reg clk;
    reg rst_n;

    reg sclk;
    reg cs_n;
    reg mosi;
    wire miso;

    wire byte_sync;
    wire [7:0] data_in;
    reg  [7:0] data_out;

    // instantiere DUT
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
    wire [7:0] random;
    assign random = DUT.miso_shift;
    // =======================
    // Clock intern periferic
    // =======================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;   // 100 MHz
    end

    // =======================
    // Clock SPI (master)
    // =======================
    initial begin
        sclk = 0;
        forever #10 sclk = ~sclk; // 25 MHz
    end

    // =======================
    // Task - trimite un byte pe MOSI (MSB-first)
    // =======================
    task spi_send_byte(input [7:0] b);
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                @(negedge sclk);    // punem bitul pe negedge
                mosi = b[i];
                @(posedge sclk);    // citire pe posedge (CPHA=0)
            end
        end
    endtask

    // =======================
    // Test principal
    // =======================
    initial begin
        // init
        cs_n = 1;
        mosi = 0;
        data_out = 8'hA5;   // byte transmis spre master pe MISO

        rst_n = 0;
        #50;
        rst_n = 1;

        // ======================
        // 1) Trimitem un byte
        // ======================
        #30;
        cs_n = 0;  // activam SPI

        spi_send_byte(8'h3C);  // trimitem 0x3C

        @(posedge clk);

        if (byte_sync == 1)
            $display("OK: Byte reception completed.");
        else
            $display("ERROR: byte_sync not asserted!");

        if (data_in == 8'h3C)
            $display("OK: data_in = %h", data_in);
        else
            $display("ERROR: wrong data_in = %h", data_in);

        // ======================
        // 2) Observam si MISO
        // ======================
        #100;
        cs_n = 1;

        $display("Test finished.");
        $stop;
    end

endmodule
