module spi_bridge (
    // peripheral clock signals
    input clk,
    input rst_n,
    // SPI master facing signals
    input sclk,
    input cs_n,
    input mosi,
    output miso,
    // internal facing 
    output reg byte_sync,
    output reg [7:0] data_in,
    input  [7:0] data_out
);

    // sincroniz?ri pentru sclk ?i cs_n
    reg sclk_d, sclk_dd;
    reg cs_d, cs_dd;

    always @(posedge clk) begin
        sclk_d  <= sclk;
        sclk_dd <= sclk_d;

        cs_d  <= cs_n;
        cs_dd <= cs_d;
    end

    wire sclk_rise = sclk == 1;//(sclk_d == 1);// && sclk_dd == 0);
    wire sclk_fall = sclk == 0;//(sclk_d == 0);// && sclk_dd == 1);
    wire cs_active = cs_n == 0;//(cs_dd == 0);
    wire cs_start  = cs_n == 0;//(cs_dd == 1 && cs_d == 0);

    // shift register MOSI
    reg [7:0] mosi_shift;
    reg [2:0] bit_cnt;

    // shift register MISO
    reg [7:0] miso_shift;
    reg       miso_reg;
    assign miso = miso_reg;


    // ============================
    // Load MISO register on CS falling edge
    // ============================
    always @(posedge clk) begin
        if (!rst_n)
            miso_shift <= data_out;   // load byte to send
    end


    // ============================
    // MOSI reception (posedge SCLK)
    // ============================
    always @(posedge clk) begin
        if (!rst_n) begin
            mosi_shift <= 0;
            bit_cnt    <= 0;
            byte_sync  <= 0;
            data_in    <= 0;
        end else begin
            byte_sync <= 0;

            if (!cs_active) begin
                bit_cnt <= 0;
            end else if (sclk_rise) begin
                mosi_shift <= { mosi_shift[6:0], mosi };

                if (bit_cnt == 3'd7) begin
                    data_in   <= { mosi_shift[6:0], mosi };
                    byte_sync <= 1'b1;
                    bit_cnt   <= 0;
                end else begin
                    bit_cnt <= bit_cnt + 1;
                end
            end
        end
    end


    // ============================
    // MISO transmission (negedge SCLK)
    // ============================
    always @(negedge clk) begin
        if (!rst_n) begin
            miso_reg <= 0;
        end else if (cs_active && sclk_fall) begin
            miso_reg   <= miso_shift[7];
            miso_shift <= { miso_shift[6:0], 1'b0 };
        end
    end

endmodule
