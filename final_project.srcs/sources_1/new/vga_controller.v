module vga_controller (
    input wire clk,              // 25MHz VGA clock
    input wire reset,            // Reset signal
    output reg hsync,            // Horizontal sync
    output reg vsync,            // Vertical sync
    output reg [9:0] display_x,  // Current display X position (0-319)
    output reg [9:0] display_y,  // Current display Y position (0-239)
    output reg display_active    // Active display area
);

    // VGA timing parameters for 640x480@60Hz
    // We're using 320x240 for display but maintaining standard VGA timing
    parameter H_DISPLAY      = 10'd640;  // Horizontal display area
    parameter H_FRONT_PORCH  = 10'd16;   // Horizontal front porch
    parameter H_SYNC_PULSE   = 10'd96;   // Horizontal sync pulse
    parameter H_BACK_PORCH   = 10'd48;   // Horizontal back porch
    parameter H_TOTAL        = H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;  // 800
    
    parameter V_DISPLAY      = 10'd480;  // Vertical display area
    parameter V_FRONT_PORCH  = 10'd10;   // Vertical front porch
    parameter V_SYNC_PULSE   = 10'd2;    // Vertical sync pulse
    parameter V_BACK_PORCH   = 10'd33;   // Vertical back porch
    parameter V_TOTAL        = V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;  // 525
    
    // Counter registers
    reg [9:0] h_count;  // Horizontal pixel counter
    reg [9:0] v_count;  // Vertical line counter
    
    // Next counter values
    wire [9:0] h_count_next;
    wire [9:0] v_count_next;
    
    // Calculate next counter values
    assign h_count_next = (h_count == H_TOTAL - 1) ? 10'd0 : h_count + 10'd1;
    assign v_count_next = (h_count == H_TOTAL - 1) ? 
                         ((v_count == V_TOTAL - 1) ? 10'd0 : v_count + 10'd1) : 
                         v_count;
    
    // Counter update logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin
            h_count <= h_count_next;
            v_count <= v_count_next;
        end
    end
    
    // Generate sync signals
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hsync <= 1'b1;  // Sync pulses are active low
            vsync <= 1'b1;
        end else begin
            // Horizontal sync
            hsync <= ~((h_count >= H_DISPLAY + H_FRONT_PORCH) && 
                     (h_count < H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE));
            
            // Vertical sync
            vsync <= ~((v_count >= V_DISPLAY + V_FRONT_PORCH) && 
                     (v_count < V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE));
        end
    end
    
    // Generate display active signal and coordinates
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            display_active <= 1'b0;
            display_x <= 10'd0;
            display_y <= 10'd0;
        end else begin
            // Active display area
            display_active <= (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
            
            // Calculate display coordinates (scaled to 320x240)
            if (h_count < H_DISPLAY) begin
                display_x <= h_count[9:1];  // Divide by 2 (640->320)
            end
            
            if (v_count < V_DISPLAY) begin
                display_y <= v_count[9:1];  // Divide by 2 (480->240)
            end
        end
    end

endmodule