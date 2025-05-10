module spi_master(
    input wire clk,           // System clock
    input wire reset,         // Reset signal
    
    // SPI interface
    input wire miso,          // Master In Slave Out
    output reg mosi,          // Master Out Slave In
    output reg sclk,          // Serial Clock
    output reg cs,            // Chip Select (active low)
    
    // TX (Command) interface
    input wire [7:0] tx_data, // Data to transmit
    input wire tx_valid,      // Indicates valid data to transmit
    output reg tx_ready,      // Indicates ready for next byte
    
    // RX (Response) interface
    output reg [7:0] rx_data, // Received data
    output reg rx_valid,      // Indicates valid received data
    
    // Speed control
    input wire set_fast       // Signal to switch to fast mode
);

    // SPI clock generation parameters
    // For initialization: ~400KHz (100MHz/256 ~= 390KHz)
    parameter CLK_DIV_INIT = 8'd128;  // Divider for sclk (divide by 256)
    
    // For data transfer: ~12.5MHz (100MHz/8 = 12.5MHz)
    parameter CLK_DIV_FAST = 8'd4;    // Divider for faster sclk (divide by 8)
    
    // Default to initialization speed
    reg [7:0] clk_div = CLK_DIV_INIT;
    reg [7:0] clk_counter = 8'd0;
    
    // SPI transfer state machine
    localparam IDLE = 2'd0;
    localparam TRANSFER = 2'd1;
    localparam FINISH = 2'd2;
    
    reg [1:0] state = IDLE;
    reg [2:0] bit_counter;    // Counts bits 0-7
    reg [7:0] shift_reg;      // Shift register for TX/RX
    
    // Mode control
    reg initialized = 1'b0;   // Start in slow mode
    
    // Set to faster clock after initialization
    task set_fast_mode;
        begin
            initialized <= 1'b1;
            clk_div <= CLK_DIV_FAST;
        end
    endtask
    
    // SPI clock generation
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_counter <= 8'd0;
            sclk <= 1'b0;
        end else begin
            if (clk_counter >= clk_div) begin
                clk_counter <= 8'd0;
                sclk <= ~sclk;
            end else begin
                clk_counter <= clk_counter + 8'd1;
            end
        end
    end
    
    // SPI state machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            cs <= 1'b1;           // Deselect device
            mosi <= 1'b1;         // MOSI idles high
            rx_valid <= 1'b0;
            tx_ready <= 1'b1;     // Ready to accept data
            bit_counter <= 3'd0;
            initialized <= 1'b0;
            clk_div <= CLK_DIV_INIT;
        end else begin
            // Default values
            rx_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    cs <= 1'b1;       // Deselect by default
                    mosi <= 1'b1;     // MOSI idles high
                    tx_ready <= 1'b1; // Ready for new data
                    
                    if (tx_valid) begin
                        // Latch the data to transmit
                        shift_reg <= tx_data;
                        cs <= 1'b0;   // Select the device
                        tx_ready <= 1'b0;
                        bit_counter <= 3'd7; // Start with MSB
                        state <= TRANSFER;
                    end
                end
                
                TRANSFER: begin
                    // On rising edge of SPI clock: prepare MOSI
                    if (clk_counter == clk_div && !sclk) begin
                        mosi <= shift_reg[bit_counter]; // MSB first
                    end
                    
                    // On falling edge of SPI clock: sample MISO
                    if (clk_counter == clk_div && sclk) begin
                        shift_reg[bit_counter] <= miso;
                        
                        if (bit_counter == 3'd0) begin
                            // All bits transferred
                            state <= FINISH;
                        end else begin
                            bit_counter <= bit_counter - 3'd1;
                        end
                    end
                end
                
                FINISH: begin
                    rx_data <= shift_reg;  // Output received byte
                    rx_valid <= 1'b1;      // Signal valid data
                    tx_ready <= 1'b1;      // Ready for next byte
                    
                    if (!tx_valid) begin
                        // If no more bytes to send
                        cs <= 1'b1;        // Deselect device
                        state <= IDLE;
                    end else begin
                        // More bytes to send
                        shift_reg <= tx_data;
                        tx_ready <= 1'b0;
                        bit_counter <= 3'd7;
                        state <= TRANSFER;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Handle set_fast signal
    always @(posedge clk) begin
        if (set_fast && !initialized) begin
            set_fast_mode();
        end
    end

endmodule