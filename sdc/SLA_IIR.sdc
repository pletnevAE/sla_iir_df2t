create_clock -name {clk} -period 20.00 -waveform { 0.000 10.00 } [get_ports {clk}]
derive_clock_uncertainty
set_false_path -from [get_ports rst_n]