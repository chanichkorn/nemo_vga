`timescale 1ns / 1ps

module vga_controller_tb;

    // Parameters
    parameter CLK_PERIOD = 40;  // 25MHz clock (40ns period)
    
    // Inputs
    reg clk;
    reg reset;
    
    // Outputs
    wire hsync;
    wire vsync;
    wire [9:0] display_x;
    wire [9:0] display_y;
    wire display_active;
    
    // Test pattern signals
    wire [11:0] pattern_color;
    
    // Counters for verification
    integer frame_count = 0;
    integer h_sync_count = 0;
    integer v_sync_count = 0;
    integer active_pixel_count = 0;
    
    // Instantiate the VGA controller
    vga_controller uut (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .display_x(display_x),
        .display_y(display_y),
        .display_active(display_active)
    );
    
    // Generate pattern color
    assign pattern_color = 
        (display_x < 80) ? 12'hF00 :  // Red
        (display_x < 160) ? 12'h0F0 : // Green
        (display_x < 240) ? 12'h00F : // Blue
        12'hFFF;                      // White
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Previous signal states for edge detection
    reg prev_hsync;
    reg prev_vsync;
    
    // Monitor VGA signals
    always @(posedge clk) begin
        // Detect falling edge of hsync (start of horizontal sync pulse)
        prev_hsync <= hsync;
        if (prev_hsync && !hsync) begin
            h_sync_count = h_sync_count + 1;
            $display("Horizontal sync pulse #%d at time %t", h_sync_count, $time);
        end
        
        // Detect falling edge of vsync (start of vertical sync pulse)
        prev_vsync <= vsync;
        if (prev_vsync && !vsync) begin
            v_sync_count = v_sync_count + 1;
            frame_count = frame_count + 1;
            $display("Vertical sync pulse #%d (Frame #%d) at time %t", 
                    v_sync_count, frame_count, $time);
        end
        
        // Count active pixels
        if (display_active) begin
            active_pixel_count = active_pixel_count + 1;
        end
    end
    
    // Main test sequence
    initial begin
        // Initialize
        reset = 1;
        $display("Starting VGA controller test at time %t", $time);
        
        // Wait a bit and release reset
        #100;
        reset = 0;
        
        // Display information about expected timings
        $display("Expected VGA 640x480@60Hz timing parameters:");
        $display("Horizontal: Display=640, Front porch=16, Sync pulse=96, Back porch=48, Total=800");
        $display("Vertical: Display=480, Front porch=10, Sync pulse=2, Back porch=33, Total=525");
        $display("Expected active pixels per frame: 640*480 = 307,200");
        
        // Wait for a few frames to verify operation
        wait(frame_count == 3);
        
        // Verify active pixel count (one frame)
        $display("Active pixel count: %d (expected 307,200)", active_pixel_count);
        if (active_pixel_count == 640*480) begin
            $display("PASS: Active pixel count matches expected value");
        end else begin
            $display("FAIL: Active pixel count does not match expected value");
        end
        
        // Wait one more frame for demonstration
        wait(frame_count == 4);
        
        // End simulation
        $display("VGA controller test completed at time %t", $time);
        $finish;
    end
    
    // Optionally, create a VCD dump for waveform viewing
    initial begin
        $dumpfile("vga_controller_tb.vcd");
        $dumpvars(0, vga_controller_tb);
    end
    
    // Additional tests for timing verification
    // These checks verify that hsync and vsync pulses occur at expected intervals
    
    // Variables to track timing
    integer last_hsync_time = 0;
    integer last_vsync_time = 0;
    integer hsync_period = 0;
    integer vsync_period = 0;
    
    // Check hsync period
    always @(negedge hsync) begin
        if (last_hsync_time != 0) begin
            hsync_period = $time - last_hsync_time;
            $display("Hsync period: %d ns", hsync_period);
            
            // Expected period for 640x480@60Hz with 25MHz pixel clock
            // 800 pixels * 40ns = 32,000ns
            if (hsync_period > 31900 && hsync_period < 32100) begin
                $display("PASS: Hsync period within expected range");
            end else begin
                $display("WARNING: Hsync period outside expected range");
            end
        end
        last_hsync_time = $time;
    end
    
    // Check vsync period
    always @(negedge vsync) begin
        if (last_vsync_time != 0) begin
            vsync_period = $time - last_vsync_time;
            $display("Vsync period: %d ns", vsync_period);
            
            // Expected period for 640x480@60Hz with 25MHz pixel clock
            // 525 lines * 800 pixels/line * 40ns = 16,800,000ns
            if (vsync_period > 16700000 && vsync_period < 16900000) begin
                $display("PASS: Vsync period within expected range");
            end else begin
                $display("WARNING: Vsync period outside expected range");
            end
        end
        last_vsync_time = $time;
    end

endmodule