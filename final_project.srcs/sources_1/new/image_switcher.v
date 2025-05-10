module image_switcher (
    input wire clk,                  // System clock
    input wire reset,                // Reset signal
    
    // User controls
    input wire btn_next,             // Next image button
    input wire btn_prev,             // Previous image button
    
    // Status signals
    input wire sd_initialized,       // SD card is initialized
    input wire image_load_done,      // Current image loading is complete
    
    // Image selection
    output reg [2:0] current_img_index,  // Current image index (0-7)
    output reg [31:0] current_img_addr,  // Current image sector address
    output reg load_new_image        // Trigger image loading
);
    
    // Image table - stores sector addresses for up to 8 images
    // In a real implementation, these could be read from a directory structure on the SD card
    // For simplicity, we'll hardcode them here
    reg [31:0] image_addresses [0:7];
    
    // Previous button states for edge detection
    reg btn_next_prev, btn_prev_prev;
    
    // State machine
    localparam IDLE = 2'd0;
    localparam LOAD_REQUESTED = 2'd1;
    localparam LOADING = 2'd2;
    
    reg [1:0] state;
    
    // Number of available images
    parameter NUM_IMAGES = 3'd4;  // Adjust based on actual number of images (1-8)
    
    // Initialize image addresses (in actual implementation, you would read this from the SD card)
    initial begin
        // Assumes these sector addresses contain valid image data
        image_addresses[0] = 32'd1000;   // First image at sector 1000
        image_addresses[1] = 32'd2000;   // Second image at sector 2000
        image_addresses[2] = 32'd3000;   // Third image at sector 3000
        image_addresses[3] = 32'd4000;   // Fourth image at sector 4000
        image_addresses[4] = 32'd0;      // Unused
        image_addresses[5] = 32'd0;
        image_addresses[6] = 32'd0;
        image_addresses[7] = 32'd0;
    end
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_img_index <= 3'd0;
            current_img_addr <= image_addresses[0];
            load_new_image <= 1'b0;
            btn_next_prev <= 1'b0;
            btn_prev_prev <= 1'b0;
            state <= IDLE;
        end else begin
            // Default assignments
            load_new_image <= 1'b0;
            
            // Edge detection for buttons
            btn_next_prev <= btn_next;
            btn_prev_prev <= btn_prev;
            
            case (state)
                IDLE: begin
                    if (sd_initialized) begin
                        // Check for next image button press (rising edge)
                        if (btn_next && !btn_next_prev) begin
                            // Increment image index (with wraparound)
                            if (current_img_index < NUM_IMAGES - 1) begin
                                current_img_index <= current_img_index + 3'd1;
                            end else begin
                                current_img_index <= 3'd0;
                            end
                            state <= LOAD_REQUESTED;
                        end
                        
                        // Check for previous image button press (rising edge)
                        if (btn_prev && !btn_prev_prev) begin
                            // Decrement image index (with wraparound)
                            if (current_img_index > 3'd0) begin
                                current_img_index <= current_img_index - 3'd1;
                            end else begin
                                current_img_index <= NUM_IMAGES - 3'd1;
                            end
                            state <= LOAD_REQUESTED;
                        end
                        
                        // When first initialized, load the first image
                        if (current_img_addr == 32'd0) begin
                            current_img_addr <= image_addresses[0];
                            state <= LOAD_REQUESTED;
                        end
                    end
                end
                
                LOAD_REQUESTED: begin
                    // Update the current image address
                    current_img_addr <= image_addresses[current_img_index];
                    
                    // Trigger image loading
                    load_new_image <= 1'b1;
                    state <= LOADING;
                end
                
                LOADING: begin
                    // Wait for image loading to complete
                    if (image_load_done) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule