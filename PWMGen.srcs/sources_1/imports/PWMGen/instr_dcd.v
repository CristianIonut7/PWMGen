module instr_dcd (
    // peripheral clock signals
    input clk,
    input rst_n,
    // towards SPI slave interface signals
    input byte_sync,
    input [7:0] data_in,
    output reg [7:0] data_out,
    // register access signals
    output reg read,
    output reg write,
    output reg [5:0] addr,
    input [7:0] data_read,
    output reg [7:0] data_write
);

    // FSM states
    localparam SETUP = 1'b0;
    localparam DATA  = 1'b1;

    reg state, next_state;

    // Internal storage
    reg rw_flag;
    reg hl_flag;

    // ========================
    // FSM state register
    // ========================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= SETUP;
        else
            state <= next_state;
    end

    // ========================
    // FSM next state logic
    // ========================
    always @(*) begin
        case(state)
            SETUP: next_state = byte_sync ? DATA : SETUP;
            DATA:  next_state = byte_sync ? DATA : SETUP;
            default: next_state = SETUP;
        endcase
    end

    // ========================
    // Output and data handling
    // ========================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read       <= 0;
            write      <= 0;
            addr       <= 0;
            rw_flag    <= 0;
            hl_flag    <= 0;
            data_write <= 0;
            data_out   <= 0;
        end else begin
            read  <= 0;
            write <= 0;
            data_out <= 0;

 
                case(state)
                    SETUP: begin
                        rw_flag <= data_in[7];    // 1 = write, 0 = read
                        hl_flag <= data_in[6];    // 1 = high, 0 = low
                        addr    <= data_in[5:0];  // registrul vizat
                    end
                    DATA: begin
                        if (rw_flag) begin
                            write      <= 1;
                            data_write <= data_in;
                        end else begin
                            read     <= 1;
                            // selecteaza byte-ul corect din data_read
                            if (hl_flag)
                                data_out <= data_read; // MSB
                            else
                                data_out <= data_read; // LSB
                        end
                    end
                endcase
            
        end
    end

endmodule
