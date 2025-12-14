`default_nettype none
`timescale 1ns/1ns

module tb_spi_bridge;

    reg  clk;
    reg  rst_n;
    reg  sclk;
    reg  cs_n;
    reg  tb_mosi;
    wire tb_miso;

    wire byte_sync;
    wire [7:0] data_in;
    wire [7:0] data_out;

    spi_bridge uut (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .miso(tb_miso),
        .mosi(tb_mosi),
        .byte_sync(byte_sync),
        .data_in(data_in),
        .data_out(8'h00)
    );

    localparam CLK_HALF   = 50;  
    localparam SCLK_HALF  = 50;   

    initial begin
        clk = 1'b0;
        forever #(CLK_HALF) clk = ~clk;
    end

    initial begin
        $dumpfile("waves_spi.vcd");
        $dumpvars(0, tb_spi_bridge);
    end

    
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
    endtask

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
                #(SCLK_HALF/2);
                sclk = 1'b0;
            end
        end
    endtask

    reg [7:0] dummy_rx;

    initial begin
        $display("--- Start tb_spi_bridge (Replica tb_top_system) ---");
        
        apply_reset();
        
        #(SCLK_HALF);
        cs_n = 1'b0;

        spi_transfer_byte(8'hC2, dummy_rx);
        
        #(10);
        if (data_in === 8'hC2 && byte_sync === 1'b1) 
            $display("[PASS] Byte 1 (Cmd): Sent 0xC2, Bridge Saw 0xC2");
        else
            $display("[FAIL] Byte 1 (Cmd): Sent 0xC2, Bridge Saw 0x%h, Sync=%b", data_in, byte_sync);

        spi_transfer_byte(8'h01, dummy_rx);

        #(10);
        if (data_in === 8'h01 && byte_sync === 1'b1) 
            $display("[PASS] Byte 2 (Dat): Sent 0x01, Bridge Saw 0x01");
        else
            $display("[FAIL] Byte 2 (Dat): Sent 0x01, Bridge Saw 0x%h, Sync=%b", data_in, byte_sync);

        #(SCLK_HALF);
        cs_n = 1'b1;
        
        #(200);
        $finish;
    end

endmodule
`default_nettype wire