module spi_bridge (
    input clk,
    input rst_n,
    
    // spi signals
    input sclk,
    input cs_n,
    input mosi,
    output reg miso,

    // 
    output reg byte_sync,
    output reg [7:0] data_in,
    input [7:0] data_out
);

    // Contor si Shift Register
    reg [2:0] bit_cnt;
    reg [7:0] shift_rx;
    reg [7:0] shift_tx;

    
    // reading data
    always @(posedge sclk or posedge cs_n) begin
        if (cs_n) begin
            //reset
            bit_cnt   <= 3'd0;
            shift_rx  <= 8'h00;
            byte_sync <= 1'b0;
           
        end else begin
            // shifting and adding mosi bit
            shift_rx <= {shift_rx[6:0], mosi};
            
            // verify if the sequence of 8 bits it's completed
            if (bit_cnt == 3'd7) begin
                // latch final
                // write the sequence in data in
                data_in   <= {shift_rx[6:0], mosi}; 
                byte_sync <= 1'b1;       
                bit_cnt   <= 3'd0;       // reset contor
            end else begin
                byte_sync <= 1'b0;
                bit_cnt   <= bit_cnt + 1;
            end
        end
    end
    
    
    //  write data
    always @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            miso     <= 1'b0;
            shift_tx <= data_out; //load the data tha will be send
        end else begin
            if (bit_cnt == 3'd0) begin
                // begining of new byte
                miso     <= data_out[7];
                shift_tx <= {data_out[6:0], 1'b0};
            end else begin
                // Shift
                miso     <= shift_tx[7];
                shift_tx <= {shift_tx[6:0], 1'b0};
            end
        end
    end

endmodule