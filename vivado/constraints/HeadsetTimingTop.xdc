# Clock constraint for HeadsetTimingTop timing analysis (200 MHz).
# Use with out-of-context synthesis/implementation; board pins are not assigned.
create_clock -period 5.000 -name sys_clk [get_ports {clk}]
