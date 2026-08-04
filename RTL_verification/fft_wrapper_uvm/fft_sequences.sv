
package fft_sequences_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fft_wrapper_sequence_item::*;
    import fft_ref_pkg::*;

    //========================================================================
    // Base: one helper to push a single cycle.
    //========================================================================
    class fft_base_seq extends uvm_sequence #(fft_wrapper_seq_item);

        `uvm_object_utils(fft_base_seq)

        int n_frames = 4;
        int amp      = 16384;      // 4.0 in Q4.12
        bit stalls   = 0;

        function new(string name = "fft_base_seq");
            super.new(name);
        endfunction

        task send(logic signed [15:0] re, logic signed [15:0] im,
                  bit en = 1'b1, bit rst_n = 1'b1);
            fft_wrapper_seq_item it;
            it = fft_wrapper_seq_item::type_id::create("it");
            start_item(it);
            it.rst_n = rst_n;
            it.en    = en;
            it.in_re = re;
            it.in_im = im;
            finish_item(it);
        endtask

    endclass

    //========================================================================
    // All zeros. Flushes the pipe and gives a trivially checkable frame
    // (X[k] == 0 for all k) - a good smoke test right after reset.
    //========================================================================
    class fft_zero_seq extends fft_base_seq;
        `uvm_object_utils(fft_zero_seq)
        function new(string name = "fft_zero_seq"); super.new(name); endfunction

        task body();
            `uvm_info(get_type_name(), $sformatf("%0d zero frames", n_frames), UVM_LOW)
            repeat (n_frames * NPT) send(16'sd0, 16'sd0);
        endtask
    endclass

    //========================================================================
    // Unit impulse at n=0  ->  flat spectrum, X[k] = 1/16 for every k.
    // Exercises every twiddle with a known operand, and any bin that comes
    // out wrong names the stage that mangled it.
    //========================================================================
    class fft_impulse_seq extends fft_base_seq;
        `uvm_object_utils(fft_impulse_seq)
        function new(string name = "fft_impulse_seq"); super.new(name); endfunction

        task body();
            `uvm_info(get_type_name(), $sformatf("%0d impulse frames, amp=%0d", n_frames, amp), UVM_LOW)
            repeat (n_frames) begin
                send(16'(amp), 16'sd0);
                repeat (NPT-1) send(16'sd0, 16'sd0);
            end
        endtask
    endclass

    //========================================================================
    // DC  ->  all the energy in bin 0, every other bin exactly zero.
    // The cleanest cancellation test there is: every butterfly difference
    // must come out as a true zero.
    //========================================================================
    class fft_dc_seq extends fft_base_seq;
        `uvm_object_utils(fft_dc_seq)
        function new(string name = "fft_dc_seq"); super.new(name); endfunction

        task body();
            `uvm_info(get_type_name(), $sformatf("%0d DC frames, amp=%0d", n_frames, amp), UVM_LOW)
            repeat (n_frames * NPT) send(16'(amp), 16'sd0);
        endtask
    endclass

    //========================================================================
    // Single complex tone at bin k0  ->  all the energy in bin k0.
    // This is the check that actually depends on the twiddles being right:
    // a wrong coefficient leaks energy into neighbouring bins.
    //========================================================================
    class fft_tone_seq extends fft_base_seq;
        `uvm_object_utils(fft_tone_seq)
        rand int k0;
        constraint c_k0 { k0 inside {[0:NPT-1]}; }

        function new(string name = "fft_tone_seq"); super.new(name); endfunction

        task body();
            real ang;
            logic signed [15:0] re, im;
            `uvm_info(get_type_name(), $sformatf("%0d tone frames at bin k0=%0d, amp=%0d",
                                                 n_frames, k0, amp), UVM_LOW)
            repeat (n_frames) begin
                for (int n = 0; n < NPT; n++) begin
                    ang = 2.0 * PI * real'(k0) * real'(n) / real'(NPT);
                    re  = 16'(rnd_nearest($cos(ang) * real'(amp)));
                    im  = 16'(rnd_nearest($sin(ang) * real'(amp)));
                    send(re, im);
                end
            end
        endtask
    endclass

    //========================================================================
    // Constrained random frames.
    //========================================================================
    class fft_random_seq extends fft_base_seq;
        `uvm_object_utils(fft_random_seq)
        function new(string name = "fft_random_seq"); super.new(name); endfunction

        task body();
            fft_wrapper_seq_item it;
            `uvm_info(get_type_name(), $sformatf("%0d random frames, amp<=%0d, stalls=%0b",
                                                 n_frames, amp, stalls), UVM_LOW)
            repeat (n_frames * NPT) begin
                it = fft_wrapper_seq_item::type_id::create("it");
                start_item(it);
                it.amp_limit   = amp;
                it.allow_stall = stalls;
                it.allow_rst   = 0;
                if (!it.randomize())
                    `uvm_fatal(get_type_name(), "randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    //========================================================================
    // Random data with en dropped at random. The DUT must freeze completely:
    // a stalled cycle consumes nothing, so the answer stream has to be
    // bit-identical to the un-stalled case.
    //========================================================================
    class fft_stall_seq extends fft_random_seq;
        `uvm_object_utils(fft_stall_seq)
        function new(string name = "fft_stall_seq");
            super.new(name);
            stalls = 1;
        endfunction
    endclass

    //========================================================================
    // Amplitude beyond the provably-safe 8/sqrt(2) = 5.66. Deliberately
    // pushes the twiddle multiplier past what Q4.12 can hold, to see whether
    // it wraps or saturates. Kept out of the default regression - run it with
    // +UVM_TESTNAME=fft_wrapper_overflow_test.
    //========================================================================
    class fft_full_scale_seq extends fft_random_seq;
        `uvm_object_utils(fft_full_scale_seq)
        function new(string name = "fft_full_scale_seq");
            super.new(name);
            amp = 30000;                     // 7.32, well past 5.66
        endfunction
    endclass

    //========================================================================
    // Drops reset in the middle of a frame, then streams again. Checks that
    // the delay lines and both counters really do clear, rather than
    // restarting mid-phase and corrupting the following frames.
    //========================================================================
    class fft_reset_mid_frame_seq extends fft_base_seq;
        `uvm_object_utils(fft_reset_mid_frame_seq)
        rand int unsigned kill_at;
        constraint c_kill { kill_at inside {[1:NPT-1]}; }

        function new(string name = "fft_reset_mid_frame_seq"); super.new(name); endfunction

        task body();
            fft_wrapper_seq_item it;
            `uvm_info(get_type_name(), $sformatf("reset injected %0d samples into a frame", kill_at), UVM_LOW)

            // stream part of a frame ...
            repeat (kill_at) begin
                it = fft_wrapper_seq_item::type_id::create("it");
                start_item(it);
                it.amp_limit = amp;
                if (!it.randomize()) `uvm_fatal(get_type_name(), "randomize failed")
                finish_item(it);
            end

            // ... yank reset ...
            repeat (3) send(16'sd0, 16'sd0, 1'b0, 1'b0);

            // ... and start clean frames again
            repeat (n_frames * NPT) begin
                it = fft_wrapper_seq_item::type_id::create("it");
                start_item(it);
                it.amp_limit = amp;
                if (!it.randomize()) `uvm_fatal(get_type_name(), "randomize failed")
                finish_item(it);
            end
        endtask
    endclass

endpackage
