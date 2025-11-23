`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/23/2025 02:01:32 AM
// Design Name: 
// Module Name: tb_pwm_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module tb_pwm_gen;

    reg clk;
    reg rst_n;
    reg pwm_en;
    reg [15:0] period;
    reg [7:0] functions;
    reg [15:0] compare1;
    reg [15:0] compare2;
    reg [15:0] count_val;

    wire pwm_out;

    pwm_gen dut (
        .clk(clk),
        .rst_n(rst_n),
        .pwm_en(pwm_en),
        .period(period),
        .functions(functions),
        .compare1(compare1),
        .compare2(compare2),
        .count_val(count_val),
        .pwm_out(pwm_out)
    );
    wire [15:0] c1;
    wire [15:0] c2;
    wire [7:0] func; 
    assign f = dut.first_allign;
    assign c1 = dut.active_compare1;
    assign c2 = dut.active_compare2;
    assign func = dut.active_functions;
    assign safe = dut.safe_to_update;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            count_val <= 0;
        end else if (pwm_en) begin
            if (count_val >= period - 1) 
                count_val <= 0;
            else 
                count_val <= count_val + 1;
        end
    end

    initial begin
        $display("--- START PWM TEST ---");
        rst_n = 0;
        pwm_en = 0;
        functions = 0;
        compare1 = 0;
        compare2 = 0;
        period = 8;
        count_val = 0;
        
        #20;
        rst_n = 1;
        pwm_en = 1;
        functions = 8'h00; 
        compare1 = 16'd3;
        
        #200;
        @(posedge clk); count_val = 0; 
        
        functions = 8'h01;
        compare1 = 16'd3;

        #200;
        
        @(posedge clk); count_val = 0;
        functions = 8'h02;
        compare1 = 16'd2;
        compare2 = 16'd6;

        #200;
        @(posedge clk); count_val = 0;
        
        functions = 8'h00;
        compare1 = 16'd4;
        
        #30;        
        compare1 = 16'd2; 

        #200;
        $finish;
    end

endmodule
