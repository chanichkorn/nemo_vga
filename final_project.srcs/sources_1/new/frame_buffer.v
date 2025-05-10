module frame_buffer (
    input wire clk,                  // VGA clock (25MHz)
    input wire write_clk,            // Write clock (system clock)
    
    // Write port (from SD card data loader)
    input wire [18:0] write_addr,    // Write address
    input wire [11:0] write_data,    // Write data (12-bit RGB)
    input wire write_en,             // Write enable
    
    // Read port (to VGA controller)
    input wire [9:0] read_x,         // Display X coordinate
    input wire [9:0] read_y,         // Display Y coordinate
    
    // Zoom and pan control
    input wire [3:0] zoom_level,     // Zoom factor (1-8)
    input wire [9:0] pan_x,          // Pan X offset
    input wire [9:0] pan_y,          // Pan Y offset
    
    // Output pixel data
    output reg [11:0] pixel_data     // 12-bit RGB pixel data (4 bits per channel)
);

    // Frame buffer memory
    // 320x240 pixels, 12 bits per pixel = 76,800 words
    reg [11:0] buffer [76799:0];
    
    // Read address calculation with zoom
    wire [9:0] source_x, source_y;
    wire [18:0] read_addr;
    
    // Coordinate transformation for zoom and pan
    coordinate_transformer coord_transform (
        .clk(clk),
        .display_x(read_x),
        .display_y(read_y),
        .zoom_level(zoom_level),
        .pan_x(pan_x),
        .pan_y(pan_y),
        .source_x(source_x),
        .source_y(source_y)
    );
    
    // Calculate linear read address from transformed coordinates
    assign read_addr = (source_y * 320) + source_x;
    
    // Handle out-of-bounds coordinates (black border)
    wire out_of_bounds = (source_x >= 320) || (source_y >= 240);
    
    // Dual-port RAM implementation
    // Write port (synchronous to write_clk)
    always @(posedge write_clk) begin
        if (write_en) begin
            buffer[write_addr] <= write_data;
        end
    end
    
    // Read port (synchronous to clk)
    always @(posedge clk) begin
        if (out_of_bounds) begin
            pixel_data <= 12'h000;   // Black for out-of-bounds
        end else begin
            pixel_data <= buffer[read_addr];
        end
    end

endmodule

// Coordinate transformer module for zoom functionality
module coordinate_transformer (
    input wire clk,                  // Clock
    input wire [9:0] display_x,      // Display X coordinate (0-319)
    input wire [9:0] display_y,      // Display Y coordinate (0-239)
    input wire [3:0] zoom_level,     // Zoom level (1-8)
    input wire [9:0] pan_x,          // Pan X offset
    input wire [9:0] pan_y,          // Pan Y offset
    output reg [9:0] source_x,       // Source image X coordinate
    output reg [9:0] source_y        // Source image Y coordinate
);

    // Internal calculation wires
    wire [13:0] zoomed_x, zoomed_y;  // Intermediate calculations with extra precision
    
    // Fixed-point precision for zoom calculations
    parameter ZOOM_PRECISION = 4;    // 4 bits of fractional precision
    
    // Convert zoom level to divisor
    // zoom_level 1 = no zoom (divide by 1)
    // zoom_level 2 = 2x zoom (divide by 2)
    // etc.
    wire [3:0] zoom_divisor = (zoom_level == 0) ? 4'd1 : zoom_level;
    
    // Calculate center-based zooming coordinates
    // These calculations find the "window" of the original image that should be displayed
    // when zoomed in, and apply the pan offset to move this window
    always @(posedge clk) begin
        // Step 1: Calculate center-point of display
        // For 320x240 display, center is at (160, 120)
        
        // Step 2: Convert display coordinates to source coordinates using zoom factor
        // The idea is to map each display pixel to the corresponding source pixel
        // For zoom=1, each display pixel maps directly to source pixel
        // For zoom=2, each 2x2 block of display pixels maps to one source pixel
        // This creates the zoom effect
        
        // Calculate X source coordinate: (display_x / zoom) + pan_x
        // Using fixed point for smoother zooming: (display_x << ZOOM_PRECISION) / zoom
        zoomed_x = (display_x << ZOOM_PRECISION) / zoom_divisor;
        source_x = zoomed_x[9:0] + pan_x;
        
        // Calculate Y source coordinate: (display_y / zoom) + pan_y
        zoomed_y = (display_y << ZOOM_PRECISION) / zoom_divisor;
        source_y = zoomed_y[9:0] + pan_y;
        
        // Clamp to valid range
        if (source_x >= 10'd320) source_x = 10'd319;
        if (source_y >= 10'd240) source_y = 10'd239;
    end

endmodule