module button_debouncer (
    input wire clk,        // Clock input
    input wire reset,      // Reset input
    input wire btn_in,     // Button input
    output reg btn_out     // Debounced button output
);
    
    // Parameters for debounce timing
    parameter DEBOUNCE_LIMIT = 20'd250000;  // ~10ms at 25MHz
    
    // Counter for debounce timing
    reg [19:0] count;
    
    // Previous state for edge detection
    reg btn_prev;
    
    // State definitions
    localparam IDLE = 2'b00;
    localparam COUNT = 2'b01;
    localparam STABLE = 2'b10;
    
    reg [1:0] state;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_out <= 1'b0;
            btn_prev <= 1'b0;
            count <= 20'd0;
            state <= IDLE;
        end else begin
            // Store previous button state
            btn_prev <= btn_in;
            
            case (state)
                IDLE: begin
                    // Wait for button state change
                    if (btn_in != btn_prev) begin
                        state <= COUNT;
                        count <= 20'd0;
                    end
                end
                
                COUNT: begin
                    // Count to debounce time threshold
                    if (btn_in != btn_prev) begin
                        // Button state changed during debounce - reset
                        state <= IDLE;
                    end else begin
                        if (count >= DEBOUNCE_LIMIT) begin
                            // Debounce time met, update output
                            btn_out <= btn_in;
                            state <= STABLE;
                        end else begin
                            count <= count + 20'd1;
                        end
                    end
                end
                
                STABLE: begin
                    // Button state is stable
                    // Wait for next state change
                    if (btn_in != btn_prev) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule