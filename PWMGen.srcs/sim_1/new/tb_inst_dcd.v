`default_nettype none
`timescale 1ns/1ns

module tb_dcd_exact;

    reg clk;
    reg rst_n;
    
    reg byte_sync;
    reg [7:0] data_in;
    
    reg [7:0] data_read;

    wire read;
    wire write;
    wire [5:0] addr;
    wire [7:0] data_write;
    wire [7:0] data_out;

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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

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

    task mimic_top_write;
        input [5:0] target_addr;
        input [7:0] target_data;
        
        reg [7:0] cmd_byte;
        begin
            cmd_byte = {1'b1, 1'b1, target_addr};

            $display("--- Mimic Write: Addr 0x%h, Data 0x%h ---", target_addr, target_data);

            @(posedge clk);
            data_in = cmd_byte;
            byte_sync = 1;
            @(posedge clk);
            byte_sync = 0;

            if (write) begin
                $display("   [FAIL CRITIC] Decodorul a scris la primirea Comenzii (0x%h)!", cmd_byte);
                $stop; 
            end

            #800; 

            @(posedge clk);
            data_in = target_data;
            byte_sync = 1;
            
            #1; 
            if (write === 1 && data_write === target_data && addr === target_addr)
                $display("   [PASS] Scriere Reusita: Addr=0x%h, Data=0x%h", addr, data_write);
            else
                $display("   [FAIL] Nu a scris corect! Write=%b, Addr=0x%h, Data=0x%h", write, addr, data_write);

            @(posedge clk);
            byte_sync = 0;
            
            #200; 
        end
    endtask

    task mimic_top_read;
        input [5:0] target_addr;
        input [7:0] simulated_val;
        
        reg [7:0] cmd_byte;
        begin
            cmd_byte = {1'b0, 1'b1, target_addr};
            data_read = simulated_val;

            $display("--- Mimic Read: Addr 0x%h (Expect 0x%h) ---", target_addr, simulated_val);

            @(posedge clk);
            data_in = cmd_byte;
            byte_sync = 1;
            @(posedge clk);
            byte_sync = 0;

            #10;
            if (read === 1 && data_out === simulated_val)
                $display("   [PASS] Read Activ: data_out = 0x%h", data_out);
            else
                $display("   [FAIL] Read Inactiv sau Date Gresite! Read=%b, Out=0x%h", read, data_out);

            #800;

            @(posedge clk);
            data_in = 8'h00; 
            byte_sync = 1; 
            @(posedge clk);
            byte_sync = 0;

            #200;
        end
    endtask

    initial begin
        $dumpfile("dcd_exact.vcd");
        $dumpvars(0, tb_dcd_exact);

        rst_n = 0; byte_sync = 0; data_in = 0; data_read = 0;
        #200;
        rst_n = 1; 
        #100;

        $display("START TB_DCD_EXACT");

        mimic_top_write(REG_PERIOD,     8'd7);
        mimic_top_write(REG_PRESCALE,   8'd0);
        mimic_top_write(REG_COMPARE1,   8'd3);
        mimic_top_write(REG_COUNTER_EN, 8'd1);
        mimic_top_write(REG_PWM_EN,     8'd1);
        mimic_top_write(REG_FUNCTIONS,  {6'b0, FUNCTION_ALIGN_LEFT});

        mimic_top_write(REG_COUNTER_RESET, 8'd1);
        mimic_top_write(REG_COUNTER_RESET, 8'd0);

        mimic_top_read(REG_COUNTER_VAL, 8'h55); 

        mimic_top_write(REG_COMPARE1, 8'd2);
        mimic_top_write(REG_COMPARE2, 8'd6);
        mimic_top_write(REG_FUNCTIONS, {6'b0, 2'b10});

        $display("FINALIZAT");
        $finish;
    end

endmodule