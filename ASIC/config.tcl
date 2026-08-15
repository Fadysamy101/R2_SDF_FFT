# 1. Design & PDK Setup
set ::env(DESIGN_NAME) "fft_wrapper"
set ::env(PDK) "sky130A"
set ::env(STD_CELL_LIBRARY) "sky130_fd_sc_hd"

# 2. Verilog Files Setup
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v]

# 3. Clock & Constraints Setup
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "14"
set ::env(BASE_SDC_FILE) "$::env(DESIGN_DIR)/constraints.sdc"

# 4. Synthesis Optimization
set ::env(SYNTH_STRATEGY) "DELAY 0"
set ::env(SYNTH_SIZING) 1
set ::env(SYNTH_BUFFERING) 1

# 5. LVS
set ::env(LVS_CONNECT_BY_LABEL) "1"

# 6. Floorplan & Placement
set ::env(FP_CORE_UTIL) 40
set ::env(PL_TARGET_DENSITY) 0.64

set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) "0 0 600 600"
set ::env(FP_CORE_MARGIN) 10

# 7. Timing / Slew / Capacitance Optimization
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 1
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 1

set ::env(DIODE_INSERTION_STRATEGY) 3
# Reduce high fanout
set ::env(MAX_FANOUT_CONSTRAINT) 8

# 8. Routing
set ::env(GRT_ALLOW_CONGESTION) 1

