`timescale 1ns/1ps

module tb_instr_dcd;

    reg clk;
    reg rst_n;
    reg byte_sync;
    reg [7:0] data_in;
    wire [7:0] data_out;
    wire read;
    wire write;
    wire [5:0] addr;
    reg [7:0] data_read;
    wire [7:0] data_write;

    // Instantiere DUT
    instr_dcd DUT (
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

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // Reset
    initial begin
        rst_n = 0;
        byte_sync = 0;
        data_in = 0;
        data_read = 8'h55; // exemplu pentru read
        #20;
        rst_n = 1;
    end

    // Task pentru trimite byte cu pulse pe byte_sync
    task send_byte(input [7:0] b);
        begin
            data_in = b;
            byte_sync = 1;
            #10;
            byte_sync = 0;
            #10;
        end
    endtask

    // Test principal
    initial begin
        #30;
        $display("===== Test Write Operation =====");

        // Byte setup: 1=write, 0=low, addr=0x12 -> 10010010
        send_byte(8'b10010010);

        // Byte data: 0xAB
        send_byte(8'hAB);

        #20;
        if (write) $display("Write enabled, addr=%h, data_write=%h", addr, data_write);
        else $display("ERROR: write not set!");

        #40;
        $display("===== Test Read Operation =====");

        // Byte setup: 0=read, 1=high, addr=0x03 -> 01000011
        send_byte(8'b01000011);

        // Byte data phase
        send_byte(8'h00); // dummy, pentru read

        #10;
        if (read) $display("Read enabled, addr=%h, data_out=%h", addr, data_out);
        else $display("ERROR: read not set!");

        #20;
        $display("Test finished.");
        $stop;
    end

endmodule
