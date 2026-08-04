//============================================================================
// fft_wrapper_seq_item.sv
//
// One transaction == one clock cycle at the DUT pins. The DUT has no
// handshake, so there is nothing else it could sensibly be.
//============================================================================
package fft_wrapper_sequence_item;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class fft_wrapper_seq_item extends uvm_sequence_item;

        //---- stimulus -------------------------------------------------
        rand bit                 rst_n;
        rand bit                 en;
        rand logic signed [15:0] in_re;
        rand logic signed [15:0] in_im;

        //---- response, filled in by the monitor -----------------------
        logic signed [15:0]      out_re;
        logic signed [15:0]      out_im;

        //---- knobs the sequences set before randomize() ---------------

        // Amplitude cap, in Q4.12 counts.
        //
        // Why 16384 (== 4.0) by default: through a butterfly |(a+-b)/2| never
        // exceeds max(|a|,|b|), and a twiddle multiply preserves complex
        // magnitude, so no internal node ever exceeds the magnitude of the
        // largest input sample. But a single component can reach that whole
        // magnitude, i.e. sqrt(2)*amp for a square input box. Q4.12 tops out at
        // 8.0, so any amp up to 8/sqrt(2) = 5.66 is provably overflow-free.
        // 4.0 leaves margin; fft_full_scale_seq deliberately goes past 5.66 to
        // probe what the DUT does on overflow.
        int  amp_limit   = 16384;

        bit  allow_rst   = 0;    // let randomization drop rst_n
        bit  allow_stall = 0;    // let randomization drop en

        `uvm_object_utils_begin(fft_wrapper_seq_item)
            `uvm_field_int(rst_n,  UVM_ALL_ON | UVM_BIN)
            `uvm_field_int(en,     UVM_ALL_ON | UVM_BIN)
            `uvm_field_int(in_re,  UVM_ALL_ON | UVM_DEC)
            `uvm_field_int(in_im,  UVM_ALL_ON | UVM_DEC)
            `uvm_field_int(out_re, UVM_ALL_ON | UVM_DEC)
            `uvm_field_int(out_im, UVM_ALL_ON | UVM_DEC)
        `uvm_object_utils_end

        function new(string name = "fft_wrapper_seq_item");
            super.new(name);
        endfunction

      
        constraint c_rst {
            (allow_rst == 0) -> rst_n == 1'b1;
        }

        constraint c_en {
            (allow_stall == 0) -> en == 1'b1;
            (allow_stall == 1) -> en dist { 1'b1 := 8, 1'b0 := 2 };
        }

        constraint c_amp {
            in_re inside {[-amp_limit : amp_limit]};
            in_im inside {[-amp_limit : amp_limit]};
        }

        // Bias toward the corners; a uniform draw would essentially never
        // produce exactly zero or exactly full scale.
        constraint c_corners {
            in_re dist { 0                      := 3,
                         amp_limit              := 3,
                        -amp_limit              := 3,
                         [1 : amp_limit-1]      := 45,
                         [-(amp_limit-1) : -1]  := 46 };
            in_im dist { 0                      := 3,
                         amp_limit              := 3,
                        -amp_limit              := 3,
                         [1 : amp_limit-1]      := 45,
                         [-(amp_limit-1) : -1]  := 46 };
        }

        function string convert2string();
            return $sformatf("rst_n=%0b en=%0b in=(%0d,%0d) out=(%0d,%0d)",
                             rst_n, en, in_re, in_im, out_re, out_im);
        endfunction

    endclass

endpackage
