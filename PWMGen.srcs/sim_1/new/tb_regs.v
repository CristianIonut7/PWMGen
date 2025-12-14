`timescale 1ns/1ns

module tb_regs_verify;

    reg clk;
    reg rst_n;
    reg read;
    reg write;
    reg [5:0] addr;
    reg [7:0] data_write;
    
    reg [15:0] counter_val;

    wire [7:0] data_read;
    wire [15:0] period;
    wire en;
    wire count_reset;
    wire upnotdown;
    wire [7:0] prescale;
    wire pwm_en;
    wire [7:0] functions;
    wire [15:0] compare1;
    wire [15:0] compare2;

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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task write_reg(input [5:0] a, input [7:0] d);
        begin
            @(posedge clk);
            addr = a;
            data_write = d;
            write = 1;
            @(posedge clk);
            write = 0;
            addr = 0;
            data_write = 0;
            #1;
        end
    endtask

    initial begin
        $dumpfile("regs_check.vcd");
        $dumpvars(0, tb_regs_verify);
        
        rst_n = 0; read = 0; write = 0; addr = 0; data_write = 0; counter_val = 0;
        #20; rst_n = 1; #10;

        $display("--- START REGS CHECK ---");

        write_reg(6'h02, 8'h01);
        
        if (en === 1) $display("[PASS] Enable activat corect cu 0x01");
        else          $display("[FAIL] Enable a ramas 0! (Value: %b)", en);

        write_reg(6'h0C, 8'h01);
        if (pwm_en === 1) $display("[PASS] PWM_EN activat corect");
        else              $display("[FAIL] PWM_EN Fail (Value: %b)", pwm_en);

        write_reg(6'h00, 8'hFF);
        write_reg(6'h01, 8'hAA);
        
        if (period === 16'hAAFF) $display("[PASS] Period asamblat corect: 0xAAFF");
        else                     $display("[FAIL] Period gresit: 0x%h (Expected: 0xAAFF)", period);

        write_reg(6'h05, 8'h34);
        write_reg(6'h06, 8'h12);
        
        if (compare2 === 16'h1234) $display("[PASS] Compare2 asamblat corect: 0x1234");
        else                       $display("[FAIL] Compare2 gresit: 0x%h (Expected: 0x1234)", compare2);

        write_reg(6'h07, 8'h01);

        @(posedge clk);
        #1;
        if (count_reset === 0) $display("[PASS] Count Reset Pulse s-a stins singur (Auto-Clear)");
        else                   $display("[FAIL] Count Reset a ramas blocat pe 1! (Value: %b)", count_reset);
        
        $display("--- REGS CHECK FINALIZAT ---");
        $finish;
    end

endmodule