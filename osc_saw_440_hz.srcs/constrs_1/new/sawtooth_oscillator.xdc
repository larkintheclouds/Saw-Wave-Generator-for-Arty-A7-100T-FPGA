# 100 MHz system clock
set_property PACKAGE_PIN E3 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk [get_ports clk_100mhz]

# Reset button (CPU reset button on Arty)
set_property PACKAGE_PIN C2 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]

# PMOD I2S2 connections - USING PMOD JA
# Pin assignments for JA (top row):
# JA1 = MCLK
set_property PACKAGE_PIN J2 [get_ports i2s_mclk]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_mclk]

# JA2 = LRCK
set_property PACKAGE_PIN J3 [get_ports i2s_lrck]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_lrck]

# JA3 = SCK
set_property PACKAGE_PIN H2 [get_ports i2s_sck]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_sck]

# JA4 = SDIN (not used in this design - for microphone input)
# set_property PACKAGE_PIN H3 [get_ports i2s_sdin]  # Uncomment if using microphone

# JA7 = SDOUT (this connects to J2 line out on the I2S2 module)
set_property PACKAGE_PIN G3 [get_ports i2s_sdout]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_sdout]

# JA8, JA9, JA10 are ground and power (automatically connected through PMOD)

# Optional: Add pull-ups for I2S lines
set_property PULLUP true [get_ports i2s_mclk]
set_property PULLUP true [get_ports i2s_lrck]
set_property PULLUP true [get_ports i2s_sck]
set_property PULLUP true [get_ports i2s_sdout]