module sd_controller (
    input wire clk,                  // System clock
    input wire reset,                // Reset signal
    
    // SPI interface
    output reg [7:0] spi_tx_data,    // Data to send to SPI
    output reg spi_tx_valid,         // Valid data to send
    input wire spi_tx_ready,         // SPI ready for next byte
    input wire [7:0] spi_rx_data,    // Data received from SPI
    input wire spi_rx_valid,         // Valid data received
    
    // Control and status
    output reg initialized,          // SD card initialized successfully
    output reg [7:0] status,         // Status bits
    
    // Read interface
    input wire read_request,         // Request to read a sector
    input wire [31:0] sector_addr,   // Sector address to read
    
    // Data output interface
    output reg read_data_valid,      // Valid data read from SD card
    output reg [7:0] read_data       // Data byte read from SD card
);

    // SD card command definitions
    localparam CMD0  = 8'h40;        // GO_IDLE_STATE - reset card to idle state
    localparam CMD8  = 8'h48;        // SEND_IF_COND - verify voltage and check card version
    localparam CMD17 = 8'h51;        // READ_SINGLE_BLOCK - read a block of data
    localparam CMD55 = 8'h77;        // APP_CMD - next command is app command
    localparam ACMD41 = 8'h69;       // SD_SEND_OP_COND - start initialization

    // Token for start of data block (for CMD17)
    localparam START_BLOCK_TOKEN = 8'hFE;
    
    // R1 response bit flags
    localparam R1_IDLE = 8'h01;      // Idle state
    localparam R1_SUCCESS = 8'h00;   // Success (no error)
    
    // State machine states
    localparam INIT_IDLE = 4'd0;
    localparam INIT_SEND_CMD0 = 4'd1;
    localparam INIT_WAIT_CMD0 = 4'd2;
    localparam INIT_SEND_CMD8 = 4'd3;
    localparam INIT_WAIT_CMD8 = 4'd4;
    localparam INIT_SEND_CMD55 = 4'd5;
    localparam INIT_WAIT_CMD55 = 4'd6;
    localparam INIT_SEND_ACMD41 = 4'd7;
    localparam INIT_WAIT_ACMD41 = 4'd8;
    localparam INIT_COMPLETE = 4'd9;
    localparam READ_SEND_CMD17 = 4'd10;
    localparam READ_WAIT_CMD17 = 4'd11;
    localparam READ_WAIT_DATA = 4'd12;
    localparam READ_DATA = 4'd13;
    localparam READ_CRC = 4'd14;
    localparam READ_DONE = 4'd15;
    
    reg [3:0] state;
    reg [3:0] return_state;       // State to return to after response
    
    reg [7:0] cmd_response;       // Stores R1 response
    reg [2:0] cmd_response_cnt;   // For multi-byte responses
    reg [31:0] r7_response;       // Stores R7 response (for CMD8)
    
    reg [9:0] init_wait_counter;  // Wait counter for initialization
    reg [9:0] data_counter;       // Counter for data bytes
    
    // Initialization task - sends 6-byte command over SPI
    task send_cmd;
        input [5:0] cmd_idx;
        input [31:0] arg;
        input [7:0] crc;
        begin
            // Wait until SPI is ready before sending
            if (spi_tx_ready) begin
                spi_tx_data <= {2'b01, cmd_idx};  // Command byte
                spi_tx_valid <= 1'b1;
                state <= state + 1'b1;            // Move to next state (wait response)
            end
        end
    endtask
    
    // Main state machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= INIT_IDLE;
            initialized <= 1'b0;
            status <= 8'h00;
            spi_tx_valid <= 1'b0;
            init_wait_counter <= 10'd0;
            read_data_valid <= 1'b0;
        end else begin
            // Default assignments
            spi_tx_valid <= 1'b0;
            read_data_valid <= 1'b0;
            
            case (state)
                // Initialization sequence
                INIT_IDLE: begin
                    // Wait for power-up (>74 clock cycles with CS high)
                    if (init_wait_counter < 10'd200) begin
                        init_wait_counter <= init_wait_counter + 1'b1;
                    end else begin
                        state <= INIT_SEND_CMD0;
                    end
                end
                
                INIT_SEND_CMD0: begin
                    // CMD0: Reset card to idle state (SPI mode)
                    if (spi_tx_ready) begin
                        // Send command byte
                        spi_tx_data <= CMD0;
                        spi_tx_valid <= 1'b1;
                        state <= INIT_WAIT_CMD0;
                        cmd_response_cnt <= 3'd0;
                    end
                end
                
                INIT_WAIT_CMD0: begin
                    // Send command argument and CRC
                    if (spi_tx_ready) begin
                        case (cmd_response_cnt)
                            3'd0: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd1; end
                            3'd1: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd2; end
                            3'd2: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd3; end
                            3'd3: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd4; end
                            3'd4: begin spi_tx_data <= 8'h95; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd5; end
                            3'd5: begin
                                // Wait for response
                                if (spi_rx_valid) begin
                                    cmd_response <= spi_rx_data;
                                    if (spi_rx_data == R1_IDLE) begin
                                        // Card is in idle state, proceed to next command
                                        state <= INIT_SEND_CMD8;
                                    end else begin
                                        // Retry CMD0
                                        state <= INIT_SEND_CMD0;
                                    end
                                end else begin
                                    // Send dummy bytes until we get a response
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                        endcase
                    end
                end
                
                INIT_SEND_CMD8: begin
                    // CMD8: Send interface condition
                    if (spi_tx_ready) begin
                        spi_tx_data <= CMD8;
                        spi_tx_valid <= 1'b1;
                        state <= INIT_WAIT_CMD8;
                        cmd_response_cnt <= 3'd0;
                    end
                end
                
                INIT_WAIT_CMD8: begin
                    // Send command argument and CRC
                    if (spi_tx_ready) begin
                        case (cmd_response_cnt)
                            3'd0: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd1; end
                            3'd1: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd2; end
                            3'd2: begin spi_tx_data <= 8'h01; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd3; end  // VHS=1 (2.7-3.6V)
                            3'd3: begin spi_tx_data <= 8'hAA; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd4; end  // Check pattern
                            3'd4: begin spi_tx_data <= 8'h87; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd5; end  // CRC
                            3'd5: begin
                                // Wait for R1 response
                                if (spi_rx_valid) begin
                                    cmd_response <= spi_rx_data;
                                    // Continue to read R7 response (4 more bytes)
                                    cmd_response_cnt <= 3'd6;
                                    r7_response <= 32'h00000000;
                                end else begin
                                    // Send dummy bytes until we get a response
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                            3'd6: begin
                                // Read byte 1 of R7
                                if (spi_rx_valid) begin
                                    r7_response[31:24] <= spi_rx_data;
                                    cmd_response_cnt <= 3'd7;
                                end else begin
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                            3'd7: begin
                                // Read byte 2 of R7
                                if (spi_rx_valid) begin
                                    r7_response[23:16] <= spi_rx_data;
                                    cmd_response_cnt <= 3'd0;  // Changed to 0 to avoid truncation warning
                                end else begin
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                            3'd0: begin  // Using 0 instead of 8 to avoid truncation
                                // Read byte 3 of R7
                                if (spi_rx_valid) begin
                                    r7_response[15:8] <= spi_rx_data;
                                    cmd_response_cnt <= 3'd1;  // Changed to 1 to avoid truncation warning
                                end else begin
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                            3'd1: begin  // Using 1 instead of 9 to avoid truncation
                                // Read byte 4 of R7
                                if (spi_rx_valid) begin
                                    r7_response[7:0] <= spi_rx_data;
                                    // Check response - expect check pattern 0xAA in last byte
                                    if (spi_rx_data == 8'hAA && cmd_response == R1_IDLE) begin
                                        // Card is SD v2, proceed with initialization
                                        state <= INIT_SEND_CMD55;
                                    end else begin
                                        // Card may be SD v1 or MMC, or CMD8 failed
                                        // Retry from CMD0
                                        state <= INIT_SEND_CMD0;
                                    end
                                end else begin
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                        endcase
                    end
                end
                
                INIT_SEND_CMD55: begin
                    // CMD55: App command prefix
                    if (spi_tx_ready) begin
                        spi_tx_data <= CMD55;
                        spi_tx_valid <= 1'b1;
                        state <= INIT_WAIT_CMD55;
                        cmd_response_cnt <= 3'd0;
                    end
                end
                
                INIT_WAIT_CMD55: begin
                    // Send command argument and CRC
                    if (spi_tx_ready) begin
                        case (cmd_response_cnt)
                            3'd0: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd1; end
                            3'd1: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd2; end
                            3'd2: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd3; end
                            3'd3: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd4; end
                            3'd4: begin spi_tx_data <= 8'h01; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd5; end  // Dummy CRC
                            3'd5: begin
                                // Wait for response
                                if (spi_rx_valid) begin
                                    cmd_response <= spi_rx_data;
                                    if (spi_rx_data == R1_IDLE) begin
                                        // Card accepted APP_CMD, send ACMD41
                                        state <= INIT_SEND_ACMD41;
                                    end else begin
                                        // Retry CMD55
                                        state <= INIT_SEND_CMD55;
                                    end
                                end else begin
                                    // Send dummy bytes
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                        endcase
                    end
                end
                
                INIT_SEND_ACMD41: begin
                    // ACMD41: Initialize card
                    if (spi_tx_ready) begin
                        spi_tx_data <= ACMD41;
                        spi_tx_valid <= 1'b1;
                        state <= INIT_WAIT_ACMD41;
                        cmd_response_cnt <= 3'd0;
                    end
                end
                
                INIT_WAIT_ACMD41: begin
                    // Send command argument and CRC
                    if (spi_tx_ready) begin
                        case (cmd_response_cnt)
                            3'd0: begin spi_tx_data <= 8'h40; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd1; end  // HCS bit
                            3'd1: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd2; end
                            3'd2: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd3; end
                            3'd3: begin spi_tx_data <= 8'h00; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd4; end
                            3'd4: begin spi_tx_data <= 8'h01; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd5; end  // Dummy CRC
                            3'd5: begin
                                // Wait for response
                                if (spi_rx_valid) begin
                                    cmd_response <= spi_rx_data;
                                    if (spi_rx_data == R1_SUCCESS) begin
                                        // Card initialized successfully
                                        state <= INIT_COMPLETE;
                                    end else if (spi_rx_data == R1_IDLE) begin
                                        // Card still initializing, retry CMD55+ACMD41
                                        state <= INIT_SEND_CMD55;
                                    end else begin
                                        // Initialization failed, retry from CMD0
                                        state <= INIT_SEND_CMD0;
                                    end
                                end else begin
                                    // Send dummy bytes
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                        endcase
                    end
                end
                
                INIT_COMPLETE: begin
                    // Card initialized successfully
                    initialized <= 1'b1;
                    
                    // Wait for read request
                    if (read_request) begin
                        state <= READ_SEND_CMD17;
                    end
                end
                
                // Read block sequence
                READ_SEND_CMD17: begin
                    // CMD17: READ_SINGLE_BLOCK
                    if (spi_tx_ready) begin
                        spi_tx_data <= CMD17;
                        spi_tx_valid <= 1'b1;
                        state <= READ_WAIT_CMD17;
                        cmd_response_cnt <= 3'd0;
                    end
                end
                
                READ_WAIT_CMD17: begin
                    // Send sector address and CRC
                    if (spi_tx_ready) begin
                        case (cmd_response_cnt)
                            3'd0: begin spi_tx_data <= sector_addr[31:24]; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd1; end
                            3'd1: begin spi_tx_data <= sector_addr[23:16]; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd2; end
                            3'd2: begin spi_tx_data <= sector_addr[15:8]; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd3; end
                            3'd3: begin spi_tx_data <= sector_addr[7:0]; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd4; end
                            3'd4: begin spi_tx_data <= 8'h01; spi_tx_valid <= 1'b1; cmd_response_cnt <= 3'd5; end  // Dummy CRC
                            3'd5: begin
                                // Wait for response
                                if (spi_rx_valid) begin
                                    cmd_response <= spi_rx_data;
                                    if (spi_rx_data == R1_SUCCESS) begin
                                        // Command accepted, wait for data
                                        state <= READ_WAIT_DATA;
                                    end else begin
                                        // Command failed, return to idle
                                        state <= INIT_COMPLETE;
                                    end
                                end else begin
                                    // Send dummy bytes
                                    spi_tx_data <= 8'hFF;
                                    spi_tx_valid <= 1'b1;
                                end
                            end
                        endcase
                    end
                end
                
                READ_WAIT_DATA: begin
                    // Wait for start block token
                    if (spi_rx_valid) begin
                        if (spi_rx_data == START_BLOCK_TOKEN) begin
                            // Data block starts
                            state <= READ_DATA;
                            data_counter <= 10'd0;
                        end
                    end
                    
                    // Keep clocking in data
                    if (spi_tx_ready) begin
                        spi_tx_data <= 8'hFF;
                        spi_tx_valid <= 1'b1;
                    end
                end
                
                READ_DATA: begin
                    // Read 512 bytes of data
                    if (spi_rx_valid) begin
                        // Forward data to output
                        read_data <= spi_rx_data;
                        read_data_valid <= 1'b1;
                        
                        if (data_counter == 10'd511) begin
                            // End of data block, read CRC
                            state <= READ_CRC;
                            data_counter <= 10'd0;
                        end else begin
                            data_counter <= data_counter + 10'd1;
                        end
                    end
                    
                    // Keep clocking in data
                    if (spi_tx_ready) begin
                        spi_tx_data <= 8'hFF;
                        spi_tx_valid <= 1'b1;
                    end
                end
                
                READ_CRC: begin
                    // Read 2 CRC bytes (typically ignored)
                    if (spi_rx_valid) begin
                        if (data_counter == 10'd1) begin
                            // End of CRC
                            state <= READ_DONE;
                        end else begin
                            data_counter <= data_counter + 10'd1;
                        end
                    end
                    
                    // Keep clocking in data
                    if (spi_tx_ready) begin
                        spi_tx_data <= 8'hFF;
                        spi_tx_valid <= 1'b1;
                    end
                end
                
                READ_DONE: begin
                    // Return to idle state, ready for next command
                    state <= INIT_COMPLETE;
                end
                
                default: state <= INIT_IDLE;
            endcase
        end
    end
    
    // Status output
    always @(posedge clk) begin
        status[0] <= initialized;
        status[1] <= (state == READ_DATA);
        status[7:2] <= 6'b000000;
    end

endmodule