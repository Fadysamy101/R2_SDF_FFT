//============================================================================
`timescale 1ns/1ps
package fft_wrapper_scoreborad_pck;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fft_wrapper_sequence_item::*;


    class fft_wrapper_scoreborad extends uvm_scoreboard;

        `uvm_component_utils(fft_wrapper_scoreborad)

        uvm_analysis_export   #(fft_wrapper_seq_item) sb_export;
        uvm_tlm_analysis_fifo #(fft_wrapper_seq_item) sb_fifo;
        fft_wrapper_seq_item item;
        virtual fft_wrapper_inter vif;
       

        logic [15:0] exp_re [0:3500];
        logic [15:0] exp_im [0:3500];

        string vec_dir = "../../System_modeling/vectors";
        int    N           = 16;
        int    n_frames    = 0;
        int    data_wl     = 16;
        int    latency     = 15;
        int    n_expected  = 0;   // n_frames * N

        // Allowed |error| in LSBs. 0 = bit-exact. Bump to 1-2 if the RTL
        // complex multiplier truncates at a different point than the model.
        int    tol_lsb     = 0;

        // ---- Running state ---------------------------------------------
        int unsigned idx        = 0;   // index into the golden arrays
        int unsigned n_compared = 0;
        int unsigned n_mismatch = 0;
        int          worst_re   = 0;
        int          worst_im   = 0;


        function new(  string name = "fft_wrapper_scoreborad", uvm_component parent = null );
            super.new(name, parent);
        endfunction


        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            `uvm_info(get_type_name(), "fft_wrapper scoreboard build phase", UVM_LOW)

            sb_export = new("sb_export", this);
            sb_fifo   = new("sb_fifo",   this);
            if (!uvm_config_db#(virtual fft_wrapper_inter)::get(this,"","fft_wrapper_test_vif",vif))
            `uvm_fatal(get_type_name(), "Failed to get virtual interface")
            // Directory can be overridden from the test or the command line:
            //   +VEC_DIR=../vectors        or  uvm_config_db set of "vec_dir"
            void'(uvm_config_db #(string)::get(this, "", "vec_dir", vec_dir));
            void'($value$plusargs("VEC_DIR=%s", vec_dir));
            void'($value$plusargs("TOL_LSB=%d", tol_lsb));

            load_meta();
            load_vectors();
        endfunction


        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            sb_export.connect(sb_fifo.analysis_export);
        endfunction


        // ----------------------------------------------------------------
        // meta.txt is "KEY value" per line, written by gen_fft_vectors.m
        // ----------------------------------------------------------------
        function void load_meta();
            int    fd;
            string key;
            int    val;
            string path;

            path = {vec_dir, "/meta.txt"};
            fd   = $fopen(path, "r");

       

            while ($fscanf(fd, "%s %d", key, val) == 2) begin
                case (key)
                    "N"       : N        = val;
                    "FRAMES"  : n_frames = val;
                    "DATA_WL" : data_wl  = val;
                    "LATENCY" : latency  = val;
                    default   : ; // ORDER_IN / ORDER_OUT are strings, skipped
                endcase
            end
            $fclose(fd);

            n_expected = N * n_frames;

   

            `uvm_info(get_type_name(),
                $sformatf("meta: N=%0d frames=%0d width=%0d latency=%0d -> %0d samples",
                          N, n_frames, data_wl, latency, n_expected), UVM_LOW)
        endfunction


        function void load_vectors();
            // Fill with X first so a short file shows up as a mismatch
            // rather than silently comparing against zeros.
            foreach (exp_re[i]) begin
                exp_re[i] = 'x;
                exp_im[i] = 'x;
            end


            $readmemh({vec_dir, "/output_re.hex"}, exp_re);
            $readmemh({vec_dir, "/output_im.hex"}, exp_im);

            if ($isunknown(exp_re[0]) || $isunknown(exp_im[0]))
                `uvm_fatal(get_type_name(),
                    $sformatf("Golden vectors not loaded from %s - check the path",
                              vec_dir))

            `uvm_info(get_type_name(),
                $sformatf("Loaded golden output vectors from %s", vec_dir), UVM_LOW)
        endfunction


        // ----------------------------------------------------------------
        task run_phase(uvm_phase phase);
            super.run_phase(phase);
             repeat (latency) @(posedge vif.clk);
            forever begin
                sb_fifo.get(item);
                if(item.rst_n==1'b1)
                compare_sample(item);
            end
        endtask


        function void compare_sample(fft_wrapper_seq_item tr);
            int signed got_re, got_im, ref_re, ref_im;
            int        d_re,   d_im;
            int        frame,  bin;

            if (idx >= n_expected) begin
                `uvm_error(get_type_name(),
                    $sformatf("DUT produced sample %0d but only %0d golden samples exist",
                              idx, n_expected))
                return;
            end
            
            // ---- adjust these two lines to your seq_item field names ----
            got_re = $signed(tr.out_re);
            got_im = $signed(tr.out_im);
            // -------------------------------------------------------------

            ref_re = $signed(exp_re[idx]);
            ref_im = $signed(exp_im[idx]);

            d_re = (got_re > ref_re) ? (got_re - ref_re) : (ref_re - got_re);
            d_im = (got_im > ref_im) ? (got_im - ref_im) : (ref_im - got_im);

            if (d_re > worst_re) worst_re = d_re;
            if (d_im > worst_im) worst_im = d_im;

            frame = idx / N;
            bin   = idx % N;   // NOTE: bit-reversed bin index, not natural

            if (d_re > tol_lsb || d_im > tol_lsb) begin
                n_mismatch++;
                `uvm_error(get_type_name(),
                    $sformatf(
                        "MISMATCH sample %0d (rst_n %0d, frame %0d, br-bin %0d): got %0d + %0di, exp %0d + %0di, delta %0d/%0d",
                        idx, item.rst_n, frame, bin,
                        got_re, got_im,
                        ref_re, ref_im,
                        d_re, d_im
                    )
                )
            end
            else begin
                `uvm_info(get_type_name(),
                    $sformatf(
                        "MATCH sample %0d (frame %0d, br-bin %0d): %0d + %0di",
                        idx, frame, bin,
                        got_re, got_im
                    ),
                    UVM_HIGH
                )
            end

            idx++;
            n_compared++;
        endfunction


        function void report_phase(uvm_phase phase);
            super.report_phase(phase);

            if (n_compared != n_expected)
                `uvm_error(get_type_name(), $sformatf(
                    "Sample count mismatch: compared %0d, expected %0d",
                    n_compared, n_expected))

            `uvm_info(get_type_name(), $sformatf(
                "\n  compared  : %0d\n  mismatches: %0d\n  worst dRe : %0d LSB\n  worst dIm : %0d LSB\n  tolerance : %0d LSB",
                n_compared, n_mismatch, worst_re, worst_im, tol_lsb), UVM_NONE)

            if (n_mismatch == 0 && n_compared == n_expected)
                `uvm_info(get_type_name(), "*** FFT SCOREBOARD PASS ***", UVM_NONE)
            else
                `uvm_info(get_type_name(), "*** FFT SCOREBOARD FAIL ***", UVM_NONE)
        endfunction


    endclass

endpackage