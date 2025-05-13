## This file contains the complete constraints for the Basys3 board
## It includes I/O standards for all pins to resolve the DRC NSTD-1 error

## Clock signal
set_property PACKAGE_PIN W5 [get_ports clk]							
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset button (btnC)
set_property PACKAGE_PIN U18 [get_ports reset_n]						
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]

## Switches
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]

## LEDs
set_property PACKAGE_PIN U16 [get_ports {led[0]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

## Buttons
set_property PACKAGE_PIN T17 [get_ports btn_pattern]
set_property IOSTANDARD LVCMOS33 [get_ports btn_pattern]
set_property PACKAGE_PIN T18 [get_ports btn_zoom_in]
set_property IOSTANDARD LVCMOS33 [get_ports btn_zoom_in]
set_property PACKAGE_PIN U17 [get_ports btn_zoom_out]
set_property IOSTANDARD LVCMOS33 [get_ports btn_zoom_out]

## VGA Connector
set_property PACKAGE_PIN G19 [get_ports {vga_r[0]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN H19 [get_ports {vga_r[1]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN J19 [get_ports {vga_r[2]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN N19 [get_ports {vga_r[3]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[3]}]
set_property PACKAGE_PIN J17 [get_ports {vga_g[0]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN H17 [get_ports {vga_g[1]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN G17 [get_ports {vga_g[2]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN D17 [get_ports {vga_g[3]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[3]}]
set_property PACKAGE_PIN N18 [get_ports {vga_b[0]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN L18 [get_ports {vga_b[1]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN K18 [get_ports {vga_b[2]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN J18 [get_ports {vga_b[3]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[3]}]
set_property PACKAGE_PIN P19 [get_ports vga_hsync]						
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]
set_property PACKAGE_PIN R19 [get_ports vga_vsync]						
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

## Pmod Header JA (For SD Card - if using)
## Only include these if your design still includes the SD card interface
set_property PACKAGE_PIN J1 [get_ports sd_cs]					
set_property IOSTANDARD LVCMOS33 [get_ports sd_cs]
set_property PACKAGE_PIN J2 [get_ports sd_mosi]					
set_property IOSTANDARD LVCMOS33 [get_ports sd_mosi]
set_property PACKAGE_PIN G2 [get_ports sd_miso]					
set_property IOSTANDARD LVCMOS33 [get_ports sd_miso]
set_property PACKAGE_PIN L2 [get_ports sd_sclk]					
set_property IOSTANDARD LVCMOS33 [get_ports sd_sclk]