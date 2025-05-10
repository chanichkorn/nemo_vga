module image_loader (
    input wire clk,                  // System clock
    input wire reset,                // Reset signal
    
    // Control interface
    input wire load_request,         // Request to load a new image
    input wire [31:0] sector_addr,   // Starting sector address of image
    input wire sd_initialized,       // SD card is initialized
    
    // SD card controller interface
    output reg sd_read_request,      // Request to read a sector
    output reg [31:0] sd_sector_addr,// Sector address to read
    input wire sd_read_ready,        // Data is available from SD card
    input wire [7:0] sd_read_data,   // Data from SD card
    
    // Frame buffer interface
    output reg [18:0] frame_write_addr, // Address to write (320*240 = 76800 pixels)
    output reg [11:0] frame_write_data, // 12-bit RGB pixel data (4 bits per channel)
    output reg frame_write_en,          // Write enable for frame buffer
    
    // Status signals
    output reg load_done             // Image loading is complete
);

    // Image header structure (assumed format: 8-byte header + raw pixel data)
    // Byte 0-1: Width (little-endian)
    // Byte 2-3: Height (little-endian)
    // Byte 4: Bits per pixel (8 or 24)
    // Byte 5-7: Reserved
    
    // State machine states
    localparam IDLE = 3'd0;
    localparam READ_HEADER = 3'd1;
    localparam PROCESS_HEADER = 3'd2;
    localparam READ_PIXEL_DATA = 3'd3;
    localparam DONE = 3'd4;
    
    reg [2:0] state;
    
    // Image parameters
    reg [15:0] image_width;
    reg [15:0] image_height;
    reg [7:0] image_bpp;    // Bits per pixel
    
    // Loading counters and data
    reg [9:0] header_byte_count;
    reg [19:0] pixel_count;
    reg [31:0] current_sector;
    reg [9:0] sector_byte_count;
    
    // Color conversion variables
    reg [7:0] r_byte, g_byte, b_byte;
    reg [2:0] rgb_byte_count;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            load_done <= 1'b0;
            sd_read_request <= 1'b0;
            frame_write_en <= 1'b0;
            header_byte_count <= 10'd0;
            pixel_count <= 20'd0;
            current_sector <= 32'd0;
            sector_byte_count <= 10'd0;
            rgb_byte_count <= 3'd0;
        end else begin
            // Default assignments
            frame_write_en <= 1'b0;
            sd_read_request <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (load_request && sd_initialized) begin
                        // Start loading a new image
                        current_sector <= sector_addr;
                        sd_sector_addr <= sector_addr;
                        sd_read_request <= 1'b1;
                        state <= READ_HEADER;
                        header_byte_count <= 10'd0;
                        load_done <= 1'b0;
                    end
                end
                
                READ_HEADER: begin
                    // Read 8-byte header from first sector
                    if (sd_read_ready) begin
                        case (header_byte_count)
                            10'd0: begin
                                // First byte of width (LSB)
                                image_width[7:0] <= sd_read_data;
                                header_byte_count <= header_byte_count + 10'd1;
                            end
                            10'd1: begin
                                // Second byte of width (MSB)
                                image_width[15:8] <= sd_read_data;
                                header_byte_count <= header_byte_count + 10'd1;
                            end
                            10'd2: begin
                                // First byte of height (LSB)
                                image_height[7:0] <= sd_read_data;
                                header_byte_count <= header_byte_count + 10'd1;
                            end
                            10'd3: begin
                                // Second byte of height (MSB)
                                image_height[15:8] <= sd_read_data;
                                header_byte_count <= header_byte_count + 10'd1;
                            end
                            10'd4: begin
                                // Bits per pixel
                                image_bpp <= sd_read_data;
                                header_byte_count <= header_byte_count + 10'd1;
                            end
                            10'd5, 10'd6, 10'd7: begin
                                // Reserved bytes
                                header_byte_count <= header_byte_count + 10'd1;
                                if (header_byte_count == 10'd7) begin
                                    // Header complete
                                    state <= PROCESS_HEADER;
                                end
                            end
                        endcase
                        
                        // Count bytes in sector
                        sector_byte_count <= sector_byte_count + 10'd1;
                    end
                end
                
                PROCESS_HEADER: begin
                    // Validate header and prepare for pixel data
                    // Check if image size is valid (320x240 or smaller)
                    if (image_width <= 16'd320 && image_height <= 16'd240) begin
                        // Reset counters for pixel data
                        pixel_count <= 20'd0;
                        rgb_byte_count <= 3'd0;
                        
                        // Start reading pixel data
                        state <= READ_PIXEL_DATA;
                    end else begin
                        // Invalid image size
                        state <= DONE;
                        load_done <= 1'b0;  // Indicate failure
                    end
                end
                
                READ_PIXEL_DATA: begin
                    // Process pixel data based on BPP
                    if (sd_read_ready) begin
                        if (image_bpp == 8'd24) begin
                            // 24-bit RGB data (3 bytes per pixel)
                            case (rgb_byte_count)
                                3'd0: begin
                                    // Red byte
                                    r_byte <= sd_read_data;
                                    rgb_byte_count <= 3'd1;
                                end
                                3'd1: begin
                                    // Green byte
                                    g_byte <= sd_read_data;
                                    rgb_byte_count <= 3'd2;
                                end
                                3'd2: begin
                                    // Blue byte - complete pixel
                                    b_byte <= sd_read_data;
                                    rgb_byte_count <= 3'd0;
                                    
                                    // Convert 24-bit RGB to 12-bit RGB
                                    frame_write_data <= {r_byte[7:4], g_byte[7:4], b_byte[7:4]};
                                    frame_write_addr <= pixel_count;
                                    frame_write_en <= 1'b1;
                                    
                                    // Increment pixel counter
                                    pixel_count <= pixel_count + 20'd1;
                                    
                                    // Check if all pixels processed
                                    if (pixel_count == (image_width * image_height) - 1) begin
                                        state <= DONE;
                                    end
                                end
                            endcase
                        end else if (image_bpp == 8'd8) begin
                            // 8-bit grayscale data (1 byte per pixel)
                            // Convert to 12-bit RGB (same value for R, G, B)
                            frame_write_data <= {sd_read_data[7:4], sd_read_data[7:4], sd_read_data[7:4]};
                            frame_write_addr <= pixel_count;
                            frame_write_en <= 1'b1;
                            
                            // Increment pixel counter
                            pixel_count <= pixel_count + 20'd1;
                            
                            // Check if all pixels processed
                            if (pixel_count == (image_width * image_height) - 1) begin
                                state <= DONE;
                            end
                        end
                        
                        // Count bytes in sector
                        sector_byte_count <= sector_byte_count + 10'd1;
                        
                        // Check if we need to read next sector
                        if (sector_byte_count == 10'd511) begin
                            // Prepare to read next sector
                            current_sector <= current_sector + 32'd1;
                            sd_sector_addr <= current_sector + 32'd1;
                            sd_read_request <= 1'b1;
                            sector_byte_count <= 10'd0;
                        end
                    end
                end
                
                DONE: begin
                    // Image loading complete
                    load_done <= 1'b1;
                    
                    // Wait for next load request
                    if (load_request) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule