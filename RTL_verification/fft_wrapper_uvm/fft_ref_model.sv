//============================================================================
// fft_ref_model.sv  -  Golden model for the 16-point R2SDF DIF FFT.
//
// Written from the MATLAB spec (System_modeling/sdf_r2dif_fft.m), NOT from the
// Verilog. That is deliberate: a model transcribed from the RTL would happily
// reproduce the RTL's bugs. The only thing borrowed from the RTL is the
// arithmetic *style* (rounding / overflow), which is selectable below because
// the two descriptions disagree about it - see the notes on ROUND_MODE.
//
// Two independent checks are built on this file:
//
//   1. fft_ref_model   - cycle-accurate, bit-exact. One step() per enabled
//                        clock, expected out_re/out_im compared exactly.
//   2. ideal_dft()     - double-precision DFT of a whole 16-sample frame,
//                        used to bound the *algorithmic* error (SQNR). This is
//                        what catches a structurally wrong butterfly even if
//                        someone "fixes" the bit-exact model to match the RTL.
//
// Number formats (from System_modeling/sdf_types.m, mode 'fixed'):
//   data     fi(1, 16, 12)  -> Q4.12, 1.0 == 4096,  range [-8, +8)
//   twiddle  fi(1, 16, 14)  -> Q2.14, 1.0 == 16384, range [-2, +2)
//
// Scaling: every stage does >>>1, so the DUT computes X[k]/16, and the frame
// comes out in bit-reversed order after a latency of 8+4+2+1 = 15 cycles.
//============================================================================
`ifndef FFT_REF_MODEL_SV
`define FFT_REF_MODEL_SV

package fft_ref_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int  DW      = 16;    // data width
    parameter int  FRAC    = 12;    // data fractional bits  (Q4.12)
    parameter int  TWW     = 16;    // twiddle width
    parameter int  TWF     = 14;    // twiddle fractional bits (Q2.14)
    parameter int  NPT     = 16;    // FFT size
    parameter int  NSTAGES = 4;
    parameter int  LATENCY = 15;    // 8 + 4 + 2 + 1
    parameter real ONE     = 4096.0;                 // 2.0**FRAC
    parameter real TW_ONE  = 16384.0;                // 2.0**TWF
    parameter real PI      = 3.14159265358979323846;

    // Delay-line depth per stage.
    parameter int  DEPTHS [NSTAGES] = '{8, 4, 2, 1};

    //------------------------------------------------------------------------
    // How the multiplier realigns the binary point.
    //   RND_FLOOR   - arithmetic right shift, rounds toward -inf.
    //                 This is what cmult.v does (`>>> TWIDDLE_FRAC_BITS`).
    //   RND_NEAREST - round half away from zero. This is what MATLAB actually
    //                 does, because sdf_types.m builds its fi() objects with
    //                 the default fimath (RoundingMethod 'Nearest').
    // cmult.v's header comment claims the model uses 'Floor'; it does not.
    // The environment defaults to RND_FLOOR so that the bit-exact check
    // reflects the RTL's stated intent and does not drown real bugs in +-1 LSB
    // noise - run with RND_NEAREST to measure the gap against MATLAB.
    //------------------------------------------------------------------------
    typedef enum { RND_FLOOR, RND_NEAREST } round_e;

    //------------------------------------------------------------------------
    //   OVF_WRAP - truncate to DW bits. This is what the RTL does: cmult.v
    //              assigns a 33-bit result to a 16-bit wire.
    //   OVF_SAT  - clamp. This is what MATLAB does (default OverflowAction
    //              'Saturate').
    // Defaults to OVF_WRAP for the same reason as above. Either way the model
    // *counts* every overflow, so the scoreboard can report them.
    //------------------------------------------------------------------------
    typedef enum { OVF_WRAP, OVF_SAT } ovf_e;

    typedef logic signed [DW-1:0] data_t;

    //------------------------------------------------------------------------
    // Helpers
    //------------------------------------------------------------------------

    // Round half away from zero, matching MATLAB's 'Nearest'.
    function automatic longint rnd_nearest(real x);
        if (x >= 0.0) rnd_nearest =  longint'($floor( x + 0.5));
        else          rnd_nearest = -longint'($floor(-x + 0.5));
    endfunction

    // 4-bit reversal, used to undo the DUT's output ordering.
    function automatic int bitrev4(int i);
        bitrev4 = ((i & 1) << 3) | ((i & 2) << 1) | ((i & 4) >> 1) | ((i & 8) >> 3);
    endfunction

    function automatic real q12_to_real(data_t v);
        q12_to_real = real'(v) / ONE;
    endfunction

    //------------------------------------------------------------------------
    // Ideal DFT, double precision, including the DUT's 1/N scaling.
    // Completely independent of the fixed-point model.
    //------------------------------------------------------------------------
    function automatic void ideal_dft(input  real xr [NPT], input  real xi [NPT],
                                      output real yr [NPT], output real yi [NPT]);
        real ang, c, s;
        for (int k = 0; k < NPT; k++) begin
            yr[k] = 0.0;
            yi[k] = 0.0;
            for (int n = 0; n < NPT; n++) begin
                ang = -2.0 * PI * k * n / real'(NPT);
                c   = $cos(ang);
                s   = $sin(ang);
                yr[k] += xr[n]*c - xi[n]*s;
                yi[k] += xr[n]*s + xi[n]*c;
            end
            yr[k] = yr[k] / real'(NPT);   // the DUT's >>>1 per stage
            yi[k] = yi[k] / real'(NPT);
        end
    endfunction

    //========================================================================
    // One SDF stage - transcription of sdf_stage() in sdf_r2dif_fft.m
    //========================================================================
    class sdf_stage_ref;

        int      depth;
        round_e  rmode;
        ovf_e    omode;

        data_t                 fifo_re [];
        data_t                 fifo_im [];
        logic signed [TWW-1:0] tw_re   [];
        logic signed [TWW-1:0] tw_im   [];

        int cnt;
        int ovf_count;      // times a result did not fit in Q4.12

        function new(int depth_i, round_e r = RND_FLOOR, ovf_e o = OVF_WRAP);
            real ang;
            depth = depth_i;
            rmode = r;
            omode = o;

            fifo_re = new[depth];
            fifo_im = new[depth];
            tw_re   = new[depth];
            tw_im   = new[depth];

            // tw(k) = exp(-j*2*pi*k / (2*depth)), quantised to Q2.14
            for (int k = 0; k < depth; k++) begin
                ang      = -2.0 * PI * real'(k) / (2.0 * real'(depth));
                tw_re[k] = TWW'(rnd_nearest($cos(ang) * TW_ONE));
                tw_im[k] = TWW'(rnd_nearest($sin(ang) * TW_ONE));
            end

            ovf_count = 0;
            reset();
        endfunction

        function void reset();
            foreach (fifo_re[i]) begin
                fifo_re[i] = '0;
                fifo_im[i] = '0;
            end
            cnt = 0;
        endfunction

        // Squeeze a full-precision result back into Q4.12.
        function data_t fit(longint v);
            if (v > 32767 || v < -32768) begin
                ovf_count++;
                if (omode == OVF_SAT) begin
                    fit = (v > 0) ? 16'sh7FFF : 16'sh8000;
                    return fit;
                end
            end
            fit = data_t'(v);           // wrap - what the RTL does
        endfunction

        // Realign the binary point after a twiddle multiply.
        function longint shift_tw(longint full);
            if (rmode == RND_NEAREST) begin
                if (full >= 0) shift_tw =   (full + (1 << (TWF-1))) >>> TWF;
                else           shift_tw = -(((-full) + (1 << (TWF-1))) >>> TWF);
            end
            else begin
                shift_tw = full >>> TWF;    // arithmetic shift == floor
            end
        endfunction

        //--------------------------------------------------------------------
        // One enabled clock.
        //--------------------------------------------------------------------
        function void step(input data_t s_re, input data_t s_im,
                           output data_t o_re, output data_t o_im);

            data_t  p_re, p_im;         // value stored `depth` cycles ago
            data_t  w_re, w_im;         // value pushed back into the fifo
            int     k;
            longint sum_re, sum_im, diff_re, diff_im, fb_re, fb_im;

            p_re = fifo_re[0];
            p_im = fifo_im[0];

            if (cnt < depth) begin
                //---- load phase: store the sample, pass the old one out ----
                o_re = p_re;   o_im = p_im;
                w_re = s_re;   w_im = s_im;
            end
            else begin
                //---- butterfly phase ----
                k = cnt - depth;                    // twiddle index

                sum_re  = (longint'(p_re) + longint'(s_re)) >>> 1;
                sum_im  = (longint'(p_im) + longint'(s_im)) >>> 1;
                diff_re = (longint'(p_re) - longint'(s_re)) >>> 1;
                diff_im = (longint'(p_im) - longint'(s_im)) >>> 1;

                o_re = data_t'(sum_re);             // always fits: |a+b|/2 <= max(|a|,|b|)
                o_im = data_t'(sum_im);

                if (k == 0) begin                            // W^0 = +1
                    fb_re = diff_re;
                    fb_im = diff_im;
                end
                else if (2*k == depth) begin                 // W^(depth/2) = -j
                    fb_re =  diff_im;
                    fb_im = -diff_re;
                end
                else begin                                   // general multiply
                    fb_re = shift_tw(diff_re*longint'(tw_re[k]) - diff_im*longint'(tw_im[k]));
                    fb_im = shift_tw(diff_re*longint'(tw_im[k]) + diff_im*longint'(tw_re[k]));
                end

                w_re = fit(fb_re);
                w_im = fit(fb_im);
            end

            // shift the delay line
            for (int i = 0; i < depth-1; i++) begin
                fifo_re[i] = fifo_re[i+1];
                fifo_im[i] = fifo_im[i+1];
            end
            fifo_re[depth-1] = w_re;
            fifo_im[depth-1] = w_im;

            cnt = (cnt + 1) % (2*depth);
        endfunction

    endclass

    //========================================================================
    // The whole pipeline
    //========================================================================
    class fft_ref_model;

        sdf_stage_ref st [NSTAGES];

        function new(round_e r = RND_FLOOR, ovf_e o = OVF_WRAP);
            foreach (st[i]) st[i] = new(DEPTHS[i], r, o);
        endfunction

        function void reset();
            foreach (st[i]) st[i].reset();
        endfunction

        function void step(input data_t i_re, input data_t i_im,
                           output data_t o_re, output data_t o_im);
            data_t a_re, a_im, b_re, b_im;
            a_re = i_re;
            a_im = i_im;
            for (int s = 0; s < NSTAGES; s++) begin
                st[s].step(a_re, a_im, b_re, b_im);
                a_re = b_re;
                a_im = b_im;
            end
            o_re = a_re;
            o_im = a_im;
        endfunction

        function int ovf_total();
            ovf_total = 0;
            foreach (st[i]) ovf_total += st[i].ovf_count;
        endfunction

    endclass

endpackage

`endif
