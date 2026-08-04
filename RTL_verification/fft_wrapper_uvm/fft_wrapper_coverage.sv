//============================================================================
// fft_wrapper_coverage.sv
//
// The interesting control state of this DUT is entirely a function of how
// many enabled cycles have gone by since reset: phase = n mod 16 fixes the
// load/butterfly phase AND the twiddle index of all four stages at once.
// So covering phase 0..15 (crossed with the input quadrant, and with stalls)
// is what actually proves every twiddle in every stage was exercised.
//============================================================================
package fft_wrapper_coverage_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fft_wrapper_sequence_item::*;
    import fft_ref_pkg::*;

    class fft_wrapper_cover extends uvm_component;

        `uvm_component_utils(fft_wrapper_cover)

        uvm_analysis_export   #(fft_wrapper_seq_item) cov_export;
        uvm_tlm_analysis_fifo #(fft_wrapper_seq_item) cov_fifo;
        fft_wrapper_seq_item item;

        // sampled variables
        logic signed [15:0] s_in_re, s_in_im, s_out_re, s_out_im;
        bit                 s_en, s_rst_n;
        int                 s_phase;

        int n = 0;      // enabled cycles since reset

        covergroup g1;
            option.per_instance = 1;
            option.name         = "fft_wrapper_cg";

            // ---- input stimulus ---------------------------------------
            cp_in_re : coverpoint s_in_re {
                bins zero    = {0};
                bins max_pos = {32767};
                bins max_neg = {-32768};
                bins pos[4]  = {[1:32767]};
                bins neg[4]  = {[-32768:-1]};
            }
            cp_in_im : coverpoint s_in_im {
                bins zero    = {0};
                bins max_pos = {32767};
                bins max_neg = {-32768};
                bins pos[4]  = {[1:32767]};
                bins neg[4]  = {[-32768:-1]};
            }

            // quadrant of the input sample
            cp_quad_re : coverpoint (s_in_re >= 0) { bins nonneg = {1}; bins neg = {0}; }
            cp_quad_im : coverpoint (s_in_im >= 0) { bins nonneg = {1}; bins neg = {0}; }
            x_quadrant : cross cp_quad_re, cp_quad_im;

            // ---- control ----------------------------------------------
            // 0..15 => every load/butterfly phase and every twiddle index of
            // every stage.
            cp_phase : coverpoint s_phase {
                bins phase[16] = {[0:15]};
            }
            cp_en    : coverpoint s_en    { bins run = {1}; bins stall = {0}; }
            cp_rst   : coverpoint s_rst_n { bins active = {0}; bins inactive = {1}; }

            // a stall must be seen in every phase of the frame
            x_stall_phase : cross cp_en, cp_phase;
            // reset must be seen mid-frame, not only at time zero
            x_rst_phase   : cross cp_rst, cp_phase;

            // ---- response ---------------------------------------------
            cp_out_re : coverpoint s_out_re {
                bins zero   = {0};
                bins pos[4] = {[1:32767]};
                bins neg[4] = {[-32768:-1]};
            }
            cp_out_im : coverpoint s_out_im {
                bins zero   = {0};
                bins pos[4] = {[1:32767]};
                bins neg[4] = {[-32768:-1]};
            }
        endgroup

        function new(string name = "fft_wrapper_cover", uvm_component parent = null);
            super.new(name, parent);
            g1 = new();
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            cov_export = new("cov_export", this);
            cov_fifo   = new("cov_fifo",   this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            cov_export.connect(cov_fifo.analysis_export);
        endfunction

        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin
                cov_fifo.get(item);

                // Track the frame phase exactly the way the scoreboard does:
                // only enabled cycles advance it, reset restarts it.
                s_rst_n = item.rst_n;
                s_en    = item.en;
                s_in_re = item.in_re;
                s_in_im = item.in_im;
                s_out_re = item.out_re;
                s_out_im = item.out_im;
                s_phase  = n % NPT;

                g1.sample();

                if (item.rst_n !== 1'b1)      n = 0;
                else if (item.en === 1'b1)    n++;
            end
        endtask

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("COV", $sformatf("functional coverage = %.2f %%", g1.get_coverage()), UVM_NONE)
        endfunction

    endclass

endpackage
