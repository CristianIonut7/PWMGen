module counter (
    // peripheral clock signals
    input clk,
    input rst_n,
    // register facing signals
    output[15:0] count_val,
    input[15:0] period,
    input en,
    input count_reset,
    input upnotdown,
    input[7:0] prescale
);
    
    reg [31:0] prescaler_cnt; //internal counter for prescale 
    wire [31:0] prescaler_limit; //the number of cicles for counter
    wire tick; // the signal for counter
    reg[15:0] val; // auxiliary variable for modifying the counter_val
    assign count_val = val;

    assign prescaler_limit = (32'd1 << prescale); //2^prescale 

    assign tick = (prescaler_cnt >= (prescaler_limit - 32'd1)); //tick is true if internal counter is equal to the counter_limit - 1

    // Block for prescale
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin //reset
            prescaler_cnt <= 0;
        end else if (count_reset) begin
            prescaler_cnt <= 0; //internal reset
        end else if (en) begin
            if (tick) begin
                prescaler_cnt <= 0; //limit 
            end else begin
                prescaler_cnt <= prescaler_cnt + 1;
            end
        end
    end

    //Block for counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            val <= 0; //reset
        end else if (count_reset) begin
            val <= 0; //internal reset
        end else if (en && tick) begin
            if (upnotdown) begin
                //incrementation
                if (val >= period - 1) begin
                    val <= 0; //period reset
                end else begin
                    val <= val + 1;
                end
            end else begin
                //decrementation
                if (val == 0) begin
                    val <= period - 1; //period reset
                end else begin
                    val <= val - 1;
                end
            end
        end
    end
endmodule