## HDMI Port 2 (X2) - TMDS Clock
set_property PACKAGE_PIN F5 [get_ports {TMDS_Clk_p}]
set_property PACKAGE_PIN E5 [get_ports {TMDS_Clk_n}]

## HDMI Data Channel 0
set_property PACKAGE_PIN B4 [get_ports {TMDS_Data_p[0]}]
set_property PACKAGE_PIN A3 [get_ports {TMDS_Data_n[0]}]

## HDMI Data Channel 1
set_property PACKAGE_PIN A5 [get_ports {TMDS_Data_p[1]}]
set_property PACKAGE_PIN A4 [get_ports {TMDS_Data_n[1]}]

## HDMI Data Channel 2
set_property PACKAGE_PIN E2 [get_ports {TMDS_Data_p[2]}]
set_property PACKAGE_PIN D1 [get_ports {TMDS_Data_n[2]}]

## HDMI I/O Standard
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_Clk_p TMDS_Clk_n}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_Data_p[*] TMDS_Data_n[*]}]

## 100 MHz System Clock
set_property PACKAGE_PIN N14 [get_ports {clk_100}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk_100}]
create_clock -period 10.000 -name sys_clk [get_ports {clk_100}]
