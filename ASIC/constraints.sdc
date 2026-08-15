create_clock -name clk -period 14 [get_ports clk]

set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold 0.2 [get_clocks clk]
