module instr_dcd (
    input clk,
    input rst_n,
    
    // spi bridge
    input byte_sync,     
    input [7:0] data_in,  // data received from spi
    output reg [7:0] data_out, // data sent to spi

    // registers
    output reg read,
    output reg write,
    output reg [5:0] addr,
    input [7:0] data_read,
    output reg [7:0] data_write
);

    // states defintions
    localparam STATE_CMD  = 1'b0; // wait for the command,first byte
    localparam STATE_DATA = 1'b1; // wait for data,seocnd byte

    reg state, next_state;

    
    reg rw_flag; // 1 = Write,0 = Read

    // state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            state <= STATE_CMD;
        else 
            state <= next_state;
    end

    // next state logic
    always @(*) begin
        case (state)
            STATE_CMD: begin
                if (byte_sync) next_state = STATE_DATA;
                else           next_state = STATE_CMD;
            end

            STATE_DATA: begin
                if (byte_sync) next_state = STATE_CMD;
                else           next_state = STATE_DATA;
            end
            
            default: next_state = STATE_CMD;
        endcase
    end

    // Output logic: generates read/write pulses and data based on FSM
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            //clear all outputs and internal flags
            read       <= 0;         
            write      <= 0;        
            addr       <= 0;        
            data_write <= 0;         
            data_out   <= 0;       
            rw_flag    <= 0;          
        end else begin
            // Default: reset pulses at every clock cycle
            write <= 0;              
            read  <= 0;                
    
            // Output depends on current FSM state
            case (state)
                // STATE_CMD: waiting for the first byte (command byte)
                STATE_CMD: begin
                    if (byte_sync) begin
                        // Latch command information
                        rw_flag <= data_in[7];   // MSB = Write(1)/Read(0)
                        addr    <= data_in[5:0]; // Register address
    
                        // write/read pulses remain 0 here
                    end
                end
    
                // STATE_DATA: waiting for the second byte (data byte)
                STATE_DATA: begin
                    if (rw_flag) begin
                        // write
                        if (byte_sync) begin
                            write      <= 1;       
                            data_write <= data_in; // Write data to register
                        end
                    end else begin
                        // read
                        // Trigger read pulse immediately in this state
                        read <= 1;
                        // Prepare data to send back via SPI
                        data_out <= data_read; 
                    end
                end
    
            endcase
        end
    end
    

endmodule