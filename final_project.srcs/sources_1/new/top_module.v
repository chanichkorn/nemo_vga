module image_display_system_top (
    input wire clk,              // 100MHz system clock
    input wire reset_n,          // Active-low reset switch (usually btnC)
    
    // User control buttons
    input wire btn_next,         // Next image button (btnR)
    input wire btn_prev,         // Previous image button (btnL)
    input wire btn_zoom_in,      // Zoom in button (btnU)
    input wire btn_zoom_out,     // Zoom out button (btnD)
    input wire [3:0] sw,         // Switches for pan control and options
                                 // sw[0]: pan left, sw[1]: pan right
                                 // sw[2]: pan up,   sw[3]: pan down
    
    // SD card interface (connect to Pmod port)
    output wire sd_cs,           // SD card chip select
    output wire sd_mosi,         // SD card MOSI
    input wire sd_miso,          // SD card MISO
    output wire sd_sclk,         // SD card serial clock
    
    // VGA interface
    output wire [3:0] vga_r,     // VGA red channel
    output wire [3:0] vga_g,     // VGA green channel
    output wire [3:0] vga_b,     // VGA blue channel
    output wire vga_hsync,       // VGA horizontal sync
    output wire vga_vsync,       // VGA vertical sync
    
    // Status LEDs
    output wire [3:0] led        // Status LEDs for debugging
);

    // Internal reset signal (active high)
    wire reset = ~reset_n;
    
    // =========================================================================
    // Clock generation for VGA (25MHz)
    // =========================================================================
    wire clk_25MHz;
    wire clk_locked;
    
    clk_wiz_0 clk_gen (
        .clk_in1(clk),           // 100MHz input
        .clk_out1(clk_25MHz),    // 25MHz output for VGA
        .locked(clk_locked)
    );
    
    // =========================================================================
    // SD Card Interface
    // =========================================================================
    wire sd_initialized;
    wire [7:0] sd_status;
    wire sd_read_request;
    wire sd_read_ready;
    wire [7:0] sd_read_data;
    wire [31:0] sd_sector_addr;
    
    // SPI controller for SD card
    spi_master spi_controller (
        .clk(clk),
        .reset(reset),
        .miso(sd_miso),
        .mosi(sd_mosi),
        .sclk(sd_sclk),
        .cs(sd_cs),
        .rx_data(sd_read_data),
        .rx_valid(sd_read_ready),
        .tx_data(sd_cmd_data),
        .tx_valid(sd_cmd_valid),
        .tx_ready(sd_cmd_ready)
    );
    
    // SD card controller (handles commands and initialization)
    sd_controller sd_ctrl (
        .clk(clk),
        .reset(reset),
        .spi_tx_data(sd_cmd_data),
        .spi_tx_valid(sd_cmd_valid),
        .spi_tx_ready(sd_cmd_ready),
        .spi_rx_data(sd_read_data),
        .spi_rx_valid(sd_read_ready),
        .initialized(sd_initialized),
        .status(sd_status),
        .read_request(sd_read_request),
        .sector_addr(sd_sector_addr)
    );

    // =========================================================================
    // Button Debouncing and User Control
    // =========================================================================
    wire btn_next_debounced;
    wire btn_prev_debounced;
    wire btn_zoom_in_debounced;
    wire btn_zoom_out_debounced;
    
    button_debouncer btn_next_db (
        .clk(clk_25MHz),
        .reset(reset),
        .btn_in(btn_next),
        .btn_out(btn_next_debounced)
    );
    
    button_debouncer btn_prev_db (
        .clk(clk_25MHz),
        .reset(reset),
        .btn_in(btn_prev),
        .btn_out(btn_prev_debounced)
    );
    
    button_debouncer btn_zoom_in_db (
        .clk(clk_25MHz),
        .reset(reset),
        .btn_in(btn_zoom_in),
        .btn_out(btn_zoom_in_debounced)
    );
    
    button_debouncer btn_zoom_out_db (
        .clk(clk_25MHz),
        .reset(reset),
        .btn_in(btn_zoom_out),
        .btn_out(btn_zoom_out_debounced)
    );
    
    // =========================================================================
    // Zoom and Pan Control
    // =========================================================================
    wire [3:0] zoom_level;
    wire [9:0] pan_x;
    wire [9:0] pan_y;
    
    zoom_pan_controller zoom_pan_ctrl (
        .clk(clk_25MHz),
        .reset(reset),
        .btn_zoom_in(btn_zoom_in_debounced),
        .btn_zoom_out(btn_zoom_out_debounced),
        .btn_pan_left(sw[0]),
        .btn_pan_right(sw[1]),
        .btn_pan_up(sw[2]),
        .btn_pan_down(sw[3]),
        .zoom_level(zoom_level),
        .pan_x(pan_x),
        .pan_y(pan_y)
    );
    
    // =========================================================================
    // Image Management
    // =========================================================================
    wire [31:0] current_img_addr;
    wire [2:0] current_img_index;
    wire load_new_image;
    wire image_load_done;
    
    image_switcher img_switch (
        .clk(clk),
        .reset(reset),
        .btn_next(btn_next_debounced),
        .btn_prev(btn_prev_debounced),
        .sd_initialized(sd_initialized),
        .image_load_done(image_load_done),
        .current_img_index(current_img_index),
        .current_img_addr(current_img_addr),
        .load_new_image(load_new_image)
    );
    
    // =========================================================================
    // Frame Buffer and Image Loading
    // =========================================================================
    wire [9:0] vga_x;
    wire [9:0] vga_y;
    wire vga_active;
    wire [11:0] pixel_data;
    
    image_loader img_loader (
        .clk(clk),
        .reset(reset),
        .load_request(load_new_image),
        .sector_addr(current_img_addr),
        .sd_initialized(sd_initialized),
        .sd_read_request(sd_read_request),
        .sd_read_ready(sd_read_ready),
        .sd_read_data(sd_read_data),
        .sd_sector_addr(sd_sector_addr),
        .load_done(image_load_done),
        .frame_write_addr(fb_write_addr),
        .frame_write_data(fb_write_data),
        .frame_write_en(fb_write_en)
    );
    
    // Frame buffer with zoom functionality
    frame_buffer fb (
        .clk(clk_25MHz),
        .write_clk(clk),
        .write_addr(fb_write_addr),
        .write_data(fb_write_data),
        .write_en(fb_write_en),
        .read_x(vga_x),
        .read_y(vga_y),
        .zoom_level(zoom_level),
        .pan_x(pan_x),
        .pan_y(pan_y),
        .pixel_data(pixel_data)
    );
    
    // =========================================================================
    // VGA Controller
    // =========================================================================
    vga_controller vga_ctrl (
        .clk(clk_25MHz),
        .reset(reset),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .display_x(vga_x),
        .display_y(vga_y),
        .display_active(vga_active)
    );
    
    // Output RGB values when display is active
    assign vga_r = vga_active ? pixel_data[11:8] : 4'b0000;
    assign vga_g = vga_active ? pixel_data[7:4] : 4'b0000;
    assign vga_b = vga_active ? pixel_data[3:0] : 4'b0000;
    
    // Status LEDs
    assign led[0] = sd_initialized;  // SD card initialized
    assign led[1] = image_load_done; // Image loaded successfully
    assign led[2] = current_img_index[0]; // Current image index LSB
    assign led[3] = current_img_index[1]; // Current image index bit 1

endmodule