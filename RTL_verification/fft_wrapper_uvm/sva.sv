//============================================================================
// sva.sv  -  bound-in assertions.
//
// Two checkers:
//   sva            -> bound to fft_wrapper, pin-level sanity
//   sdf_stage_sva  -> bound to *every* sdf_stage instance, so the control
//                     logic of all four stages is checked independently.
//
// The stage checker is where the value is. The scoreboard can tell you the
// output is wrong; a_twiddle_index tells you which stage picked the wrong
// coefficient, on which cycle, and by how much - straight from the spec
// (sdf_r2dif_fft.m: "k = cnt - Ds").
//============================================================================
`timescale 1ns / 1ps
`default_nettype wire

//----------------------------------------------------------------------------
// Bound to fft_wrapper
//----------------------------------------------------------------------------
module sva #(
    parameter DATA_WIDTH = fft_cfg_pkg::DATA_WIDTH
)(
    input wire                          clk,
    input wire                          rst_n,
    input wire                          en,
    input wire signed [DATA_WIDTH-1:0]  in_re,
    input wire signed [DATA_WIDTH-1:0]  in_im,
    input wire signed [DATA_WIDTH-1:0]  out_re,
    input wire signed [DATA_WIDTH-1:0]  out_im
);

    // Reset is asynchronous and clears every delay line, and phase_counter==0
    // puts each stage in its load phase, so the (combinational) output must be
    // the zero that just came out of the cleared RAM.
    property p_rst_out_zero;
        @(posedge clk) (!rst_n) |-> (out_re == '0 && out_im == '0);
    endproperty
    a_rst_out_zero : assert property (p_rst_out_zero)
        else $error("[SVA] out is not zero while rst_n is asserted: (%0d,%0d)", out_re, out_im);

    // No X/Z may reach the outputs once we are streaming.
    property p_out_known;
        @(posedge clk) disable iff (!rst_n) en |-> !$isunknown({out_re, out_im});
    endproperty
    a_out_known : assert property (p_out_known)
        else $error("[SVA] X/Z on the FFT output while en is high");

    // Stimulus-side check: driving X into the DUT would silently poison
    // everything downstream, so catch it at the source.
    property p_in_known;
        @(posedge clk) disable iff (!rst_n) en |-> !$isunknown({in_re, in_im});
    endproperty
    a_in_known : assert property (p_in_known)
        else $error("[SVA] X/Z driven onto the FFT input while en is high");

endmodule

//----------------------------------------------------------------------------
// Bound to every sdf_stage instance
//----------------------------------------------------------------------------
module sdf_stage_sva #(
    parameter DELAY_DEPTH = 8,
    parameter ADDR_WIDTH  = 3
)(
    input wire                    clk,
    input wire                    rst_n,
    input wire                    en,
    input wire [ADDR_WIDTH-1:0]   delay_ptr,
    input wire [ADDR_WIDTH:0]     phase_counter,
    input wire [ADDR_WIDTH-1:0]   twiddle_addr
);

    localparam int PERIOD = 2*DELAY_DEPTH;

    //---- reset ----------------------------------------------------------
    a_rst_clears : assert property (@(posedge clk)
            (!rst_n) |-> (delay_ptr == 0 && phase_counter == 0))
        else $error("[SVA] stage D=%0d: counters not cleared by reset (ptr=%0d, phase=%0d)",
                    DELAY_DEPTH, delay_ptr, phase_counter);

    //---- ranges ---------------------------------------------------------
    a_ptr_range : assert property (@(posedge clk) disable iff (!rst_n)
            delay_ptr < DELAY_DEPTH)
        else $error("[SVA] stage D=%0d: delay_ptr=%0d out of range", DELAY_DEPTH, delay_ptr);

    a_phase_range : assert property (@(posedge clk) disable iff (!rst_n)
            phase_counter < PERIOD)
        else $error("[SVA] stage D=%0d: phase_counter=%0d out of range", DELAY_DEPTH, phase_counter);

    //---- en really is a clock enable ------------------------------------
    a_frozen_when_disabled : assert property (@(posedge clk) disable iff (!rst_n)
            (!en) |=> ($stable(phase_counter) && $stable(delay_ptr)))
        else $error("[SVA] stage D=%0d: state advanced while en was low", DELAY_DEPTH);

    //---- counters walk ---------------------------------------------------
    a_phase_inc : assert property (@(posedge clk) disable iff (!rst_n)
            en |=> phase_counter == ((int'($past(phase_counter)) + 1) % PERIOD))
        else $error("[SVA] stage D=%0d: phase_counter %0d -> %0d is not a mod-%0d increment",
                    DELAY_DEPTH, $past(phase_counter), phase_counter, PERIOD);

    a_ptr_inc : assert property (@(posedge clk) disable iff (!rst_n)
            en |=> delay_ptr == ((int'($past(delay_ptr)) + 1) % DELAY_DEPTH))
        else $error("[SVA] stage D=%0d: delay_ptr %0d -> %0d is not a mod-%0d increment",
                    DELAY_DEPTH, $past(delay_ptr), delay_ptr, DELAY_DEPTH);

    //---- the twiddle index --------------------------------------------------
    // Spec (sdf_r2dif_fft.m): during the butterfly phase the coefficient index
    // is k = cnt - Ds. The RTL gets this by dropping the MSB of phase_counter,
    // which is only the same thing when ADDR_WIDTH == log2(DELAY_DEPTH).
    a_twiddle_index : assert property (@(posedge clk) disable iff (!rst_n)
            (phase_counter >= DELAY_DEPTH) |->
            (int'(twiddle_addr) == (int'(phase_counter) - DELAY_DEPTH)))
        else $error({"[SVA] stage D=%0d: twiddle index is %0d but the spec says ",
                     "k = cnt - D = %0d  (phase_counter=%0d)"},
                     DELAY_DEPTH, twiddle_addr, int'(phase_counter) - DELAY_DEPTH, phase_counter);

endmodule

`default_nettype wire
