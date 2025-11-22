`timescale 1ns / 1ps

module tb_counter;
    //Declare variables
    reg clk;
    reg rst_n;
    reg [15:0] period;
    reg en;
    reg count_reset;
    reg upnotdown;
    reg [7:0] prescale;

    wire [15:0] count_val;
    
    wire [31:0] monitor_prescaler_cnt;
    
    //Instantiation
    counter dut (
        .clk(clk),
        .rst_n(rst_n),
        .count_val(count_val),
        .period(period),
        .en(en),
        .count_reset(count_reset),
        .upnotdown(upnotdown),
        .prescale(prescale)
    );
    //this is for the internal count
    assign monitor_prescaler_cnt = dut.prescaler_cnt;


    //clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        //Initial setup
        rst_n = 0;       
        en = 0;
        count_reset = 0;
        upnotdown = 1;   
        prescale = 0;    
        period = 16'd5;  
        
        #20;
        rst_n = 1;     //start   
        #10;
        
        //Test 1: period = 5 prescale = 0, upnotdown = 1
        $display("[Timp %0t] Test 1: Prescaler = 0 (Monitor: %d)", $time, monitor_prescaler_cnt);
        en = 1;
        period = 16'd5; 
        prescale = 8'd0;
        
        #100; 
        
        //Test 2: prescale = 2, period = 5, upnotdown = 1;
        $display("[Timp %0t] Test 2: Prescaler = 2 (Div 4)", $time);
        prescale = 8'd2;
        
        //count reset
        count_reset = 1;
        #10
        count_reset = 0;
        
        #100;
        
        //Test 3: prescale = 1, period = 5, upnotdown = 0
        $display("[Timp %0t] Test 3: Switch Direction (DOWN)", $time);
        prescale = 8'd1;
        upnotdown = 0;   
        
        //count reset
        count_reset = 1;
        #10
        count_reset = 0;
        
        #100;
        
        $finish;
    end

endmodule