module zoom_pan_controller (
    input wire clk,              // Clock
    input wire reset,            // Reset signal
    
    // User controls
    input wire btn_zoom_in,      // Zoom in button
    input wire btn_zoom_out,     // Zoom out button
    input wire btn_pan_left,     // Pan left button/switch
    input wire btn_pan_right,    // Pan right button/switch
    input wire btn_pan_up,       // Pan up button/switch
    input wire btn_pan_down,     // Pan down button/switch
    
    // Zoom and pan values
    output reg [3:0] zoom_level, // Current zoom level (1-8)
    output reg [9:0] pan_x,      // Current pan X offset
    output reg [9:0] pan_y       // Current pan Y offset
);

    // Constants
    parameter MIN_ZOOM = 4'd1;   // No zoom
    parameter MAX_ZOOM = 4'd8;   // Maximum zoom level
    parameter PAN_STEP = 10'd4;  // Pixels to move per pan step
    
    // Speed control for continuous panning
    reg [19:0] pan_speed_counter;
    parameter PAN_SPEED_MAX = 20'd250000;  // Adjust for desired pan speed
    
    // Previous button states for edge detection
    reg btn_zoom_in_prev, btn_zoom_out_prev;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            zoom_level <= MIN_ZOOM;  // Start with no zoom
            pan_x <= 10'd0;          // Start centered
            pan_y <= 10'd0;
            btn_zoom_in_prev <= 1'b0;
            btn_zoom_out_prev <= 1'b0;
            pan_speed_counter <= 20'd0;
        end else begin
            // Edge detection for zoom buttons to avoid repeated actions
            btn_zoom_in_prev <= btn_zoom_in;
            btn_zoom_out_prev <= btn_zoom_out;
            
            // Handle zoom in button (on rising edge)
            if (btn_zoom_in && !btn_zoom_in_prev) begin
                if (zoom_level < MAX_ZOOM) begin
                    zoom_level <= zoom_level + 4'd1;
                    
                    // When zooming in, adjust pan to maintain center focus
                    // This creates a more natural zoom effect by keeping the
                    // current center point as the new zoom center
                    if (pan_x > 0) pan_x <= pan_x + (pan_x >> 2);
                    if (pan_y > 0) pan_y <= pan_y + (pan_y >> 2);
                end
            end
            
            // Handle zoom out button (on rising edge)
            if (btn_zoom_out && !btn_zoom_out_prev) begin
                if (zoom_level > MIN_ZOOM) begin
                    zoom_level <= zoom_level - 4'd1;
                    
                    // When zooming out, adjust pan to maintain center focus
                    if (pan_x > 0) pan_x <= pan_x - (pan_x >> 3);
                    if (pan_y > 0) pan_y <= pan_y - (pan_y >> 3);
                    
                    // If zooming all the way out, reset pan
                    if (zoom_level == 4'd2) begin
                        pan_x <= 10'd0;
                        pan_y <= 10'd0;
                    end
                end
            end
            
            // Pan control with speed regulation
            if (pan_speed_counter >= PAN_SPEED_MAX) begin
                pan_speed_counter <= 20'd0;
                
                // Pan left/right (ensure we stay within image bounds)
                if (btn_pan_left) begin
                    if (pan_x >= PAN_STEP) begin
                        pan_x <= pan_x - PAN_STEP;
                    end else begin
                        pan_x <= 10'd0;
                    end
                end
                
                if (btn_pan_right) begin
                    // Maximum pan depends on zoom level
                    // More zoom = more pan range
                    // At 2x zoom, we can pan up to 160 pixels (half the image)
                    // At 4x zoom, we can pan up to 240 pixels (3/4 of the image)
                    if (pan_x < (zoom_level * 40) - 40) begin
                        pan_x <= pan_x + PAN_STEP;
                    end
                end
                
                // Pan up/down
                if (btn_pan_up) begin
                    if (pan_y >= PAN_STEP) begin
                        pan_y <= pan_y - PAN_STEP;
                    end else begin
                        pan_y <= 10'd0;
                    end
                end
                
                if (btn_pan_down) begin
                    // Same logic as horizontal pan
                    if (pan_y < (zoom_level * 30) - 30) begin
                        pan_y <= pan_y + PAN_STEP;
                    end
                end
            end else begin
                pan_speed_counter <= pan_speed_counter + 20'd1;
            end
        end
    end

endmodule