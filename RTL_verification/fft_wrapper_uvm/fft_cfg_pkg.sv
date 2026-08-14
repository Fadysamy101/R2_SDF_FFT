//============================================================================
// fft_cfg_pkg.sv
//
// Single source of truth for the DUT geometry on the testbench side.
//
// These MUST equal W / TW / TF in System_modeling/sdf_types.m. The scoreboard
// cross-checks DATA_WIDTH against meta.txt's DATA_WL at build time and fatals
// on a mismatch, so a stale set of golden vectors announces itself in one line
// instead of presenting as a few hundred off-by-a-few-LSB errors.
//============================================================================

package fft_cfg_pkg;

    parameter int DATA_WIDTH        = 12;
    parameter int TWIDDLE_WIDTH     = 16;   // twiddle_rom.v is hardcoded 16-bit
    parameter int TWIDDLE_FRAC_BITS = 14;   // the only binary point in the design

endpackage
