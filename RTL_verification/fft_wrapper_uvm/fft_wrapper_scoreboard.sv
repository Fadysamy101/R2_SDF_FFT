//============================================================================
// fft_wrapper_scoreboard.sv
//
// Two checks run side by side on the same stream:
//
//  (1) BIT-EXACT, every enabled cycle.
//      The golden model is stepped once per enabled clock and out_re/out_im
//      must match exactly. This catches wrong coefficients, wrong twiddle
//      indices, wrong scaling - anything.
//
//  (2) FRAME / SQNR, every 16 outputs.
//      The 16 outputs are un-bit-reversed and compared against a double
//      precision DFT of the 16 inputs that produced them. This check knows
//      nothing about the fixed-point implementation, so it still holds even
//      if someone "fixes" the bit-exact model by copying the RTL. It is also
//      what turns a pile of LSB mismatches into a number an FFT person can
//      judge: SQNR in dB.
//
// Cycle accounting (n = number of enabled cycles since reset deasserted):
//      inputs  of frame f occupy n = 16f .. 16f+15
//      outputs of frame f occupy n = 16f+15 .. 16f+30    (latency 15)
// so the outputs of a frame overlap the inputs of the next one - that is
// normal for an SDF pipeline and is why the previous input frame is kept.
//============================================================================
package fft_wrapper_scoreborad_pck;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fft_wrapper_sequence_item::*;
    import fft_ref_pkg::*;

    class fft_wrapper_scoreborad extends uvm_scoreboard;

        `uvm_component_utils(fft_wrapper_scoreborad)

        uvm_analysis_export   #(fft_wrapper_seq_item) sb_export;
        uvm_tlm_analysis_fifo #(fft_wrapper_seq_item) sb_fifo;
        fft_wrapper_seq_item item;

        //---- bit-exact tallies ----------------------------------------
        int correct_count = 0;
        int wrong_count   = 0;
        int reported      = 0;
        int MAX_REPORTED  = 20;      // then go quiet and just count

        //---- frame tallies --------------------------------------------
        int  frames_checked = 0;
        int  frames_failed  = 0;
        real worst_bin_err  = 0.0;   // real units
        real worst_sqnr     = 1.0e9; // dB
        int  worst_frame    = -1;

        //---- pass criteria --------------------------------------------
        // 0.02 in real units == 82 LSB of Q4.12. Generous for a correct
        // 16-point fixed-point FFT (a few LSB is typical) and still tight
        // enough that a structural error cannot slip through.
        real frame_tol = 0.02;
        real sqnr_min  = 40.0;       // dB, the figure the MATLAB model checks

        //---- state ----------------------------------------------------
        fft_ref_model ref_model;
        int  n = 0;                  // enabled cycles since reset
        int  stall_cycles = 0;
        int  reset_cycles = 0;

        real x_cur_re  [NPT], x_cur_im  [NPT];   // frame being fed in
        real x_prev_re [NPT], x_prev_im [NPT];   // frame whose outputs are due
        real y_re      [NPT], y_im      [NPT];   // outputs, bit-reversed order

        function new(string name = "fft_wrapper_scoreborad", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sb_export = new("sb_export", this);
            sb_fifo   = new("sb_fifo",   this);
            ref_model = new(RND_FLOOR, OVF_WRAP);

            void'($value$plusargs("FRAME_TOL=%f", frame_tol));
            void'($value$plusargs("SQNR_MIN=%f",  sqnr_min));
            void'($value$plusargs("MAX_ERRORS=%d", MAX_REPORTED));
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            sb_export.connect(sb_fifo.analysis_export);
        endfunction

        //--------------------------------------------------------------------
        task run_phase(uvm_phase phase);
            data_t exp_re, exp_im;
            int    f0, j;

            super.run_phase(phase);
            forever begin
                sb_fifo.get(item);

                // ---- reset ------------------------------------------------
                if (item.rst_n !== 1'b1) begin
                    ref_model.reset();
                    n = 0;
                    reset_cycles++;
                    continue;
                end

                // ---- stalled: the DUT consumed nothing, out is meaningless -
                if (item.en !== 1'b1) begin
                    stall_cycles++;
                    continue;
                end

                // ---- (1) bit-exact ----------------------------------------
                ref_model.step(item.in_re, item.in_im, exp_re, exp_im);

                if (exp_re !== item.out_re || exp_im !== item.out_im) begin
                    wrong_count++;
                    if (reported < MAX_REPORTED) begin
                        reported++;
                        `uvm_error("SB_EXACT",
                            $sformatf({"cycle n=%0d (frame %0d, phase %0d): ",
                                       "in=(%0d,%0d) exp=(%0d,%0d) got=(%0d,%0d) ",
                                       "delta=(%0d,%0d)"},
                                       n, n/NPT, n%NPT,
                                       item.in_re, item.in_im,
                                       exp_re, exp_im, item.out_re, item.out_im,
                                       item.out_re - exp_re, item.out_im - exp_im))
                        if (reported == MAX_REPORTED)
                            `uvm_info("SB_EXACT",
                                "error cap reached - further mismatches counted silently",
                                UVM_NONE)
                    end
                end
                else begin
                    correct_count++;
                end

                // ---- (2) frame bookkeeping --------------------------------
                if (n % NPT == 0) begin              // rotate: the frame just
                    x_prev_re = x_cur_re;            // finished becomes the one
                    x_prev_im = x_cur_im;            // whose outputs are due
                end
                x_cur_re[n % NPT] = q12_to_real(item.in_re);
                x_cur_im[n % NPT] = q12_to_real(item.in_im);

                if (n >= LATENCY) begin
                    f0 = (n - LATENCY) / NPT;
                    j  = (n - LATENCY) % NPT;
                    y_re[j] = q12_to_real(item.out_re);
                    y_im[j] = q12_to_real(item.out_im);
                    if (j == NPT-1) check_frame(f0);
                end

                n++;
            end
        endtask

        //--------------------------------------------------------------------
        // Independent frame check: un-bit-reverse, compare against an ideal
        // DFT, report worst bin error and SQNR.
        //--------------------------------------------------------------------
        function void check_frame(int f0);
            real yn_re  [NPT], yn_im  [NPT];    // natural bin order
            real ref_re [NPT], ref_im [NPT];
            real er, ei, e2, sig2, err2, emax, sqnr;
            int  kmax;
            bit  fail;

            // The DUT emits bins in bit-reversed order.
            for (int jj = 0; jj < NPT; jj++) begin
                yn_re[bitrev4(jj)] = y_re[jj];
                yn_im[bitrev4(jj)] = y_im[jj];
            end

            ideal_dft(x_prev_re, x_prev_im, ref_re, ref_im);

            sig2 = 0.0;
            err2 = 0.0;
            emax = 0.0;
            kmax = 0;
            for (int k = 0; k < NPT; k++) begin
                er = yn_re[k] - ref_re[k];
                ei = yn_im[k] - ref_im[k];
                e2 = er*er + ei*ei;
                err2 += e2;
                sig2 += ref_re[k]*ref_re[k] + ref_im[k]*ref_im[k];
                if ($sqrt(e2) > emax) begin
                    emax = $sqrt(e2);
                    kmax = k;
                end
            end

            frames_checked++;
            fail = 0;

            if (emax > worst_bin_err) begin
                worst_bin_err = emax;
                worst_frame   = f0;
            end
            if (emax > frame_tol) fail = 1;

            // SQNR only means something if the frame carries energy.
            if (sig2 > 0.0) begin
                sqnr = (err2 > 0.0) ? 10.0*$log10(sig2/err2) : 999.0;
                if (sqnr < worst_sqnr) worst_sqnr = sqnr;
                if (sqnr < sqnr_min)   fail = 1;
            end
            else begin
                sqnr = 999.0;
            end

            if (fail) begin
                frames_failed++;
                if (reported < MAX_REPORTED) begin
                    reported++;
                    `uvm_error("SB_FRAME",
                        $sformatf({"frame %0d FAILED: worst bin k=%0d |err|=%.6f ",
                                   "(tol %.6f), SQNR=%.2f dB (min %.2f dB)\n",
                                   "      got  X[%0d] = %.6f %+.6fj\n",
                                   "      want X[%0d] = %.6f %+.6fj"},
                                   f0, kmax, emax, frame_tol, sqnr, sqnr_min,
                                   kmax, yn_re[kmax],  yn_im[kmax],
                                   kmax, ref_re[kmax], ref_im[kmax]))
                end
            end
            else begin
                `uvm_info("SB_FRAME",
                    $sformatf("frame %0d OK: worst |err|=%.6f  SQNR=%.2f dB",
                              f0, emax, sqnr), UVM_HIGH)
            end
        endfunction

        //--------------------------------------------------------------------
        function void report_phase(uvm_phase phase);
            int ovf;
            super.report_phase(phase);
            ovf = ref_model.ovf_total();

            `uvm_info("SB", $sformatf({"\n",
                "  ================ FFT SCOREBOARD =================\n",
                "   cycles checked (en=1)   : %0d\n",
                "   stalled cycles (en=0)   : %0d\n",
                "   reset cycles            : %0d\n",
                "   -- bit exact ------------------------------------\n",
                "   matched                 : %0d\n",
                "   mismatched              : %0d\n",
                "   -- frame / DFT ----------------------------------\n",
                "   frames checked          : %0d\n",
                "   frames failed           : %0d\n",
                "   worst bin error         : %.6f  (frame %0d, tol %.6f)\n",
                "   worst SQNR              : %.2f dB (min %.2f dB)\n",
                "   -- range ----------------------------------------\n",
                "   golden-model overflows  : %0d\n",
                "  ================================================="},
                correct_count + wrong_count, stall_cycles, reset_cycles,
                correct_count, wrong_count,
                frames_checked, frames_failed,
                worst_bin_err, worst_frame, frame_tol,
                worst_sqnr, sqnr_min, ovf), UVM_NONE)

            if (ovf > 0)
                `uvm_warning("SB", $sformatf({"%0d twiddle results did not fit in Q4.12. ",
                    "cmult.v truncates a 33-bit product into a 16-bit wire, so those ",
                    "wrap rather than saturate; the MATLAB model saturates."}, ovf))
        endfunction

    endclass

endpackage
