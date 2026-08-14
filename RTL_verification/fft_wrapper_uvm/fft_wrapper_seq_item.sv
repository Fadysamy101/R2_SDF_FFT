//============================================================================
// fft_wrapper_seq_item.sv
//
// One transaction == one clock cycle at the DUT pins. The DUT has no
// handshake, so there is nothing else it could sensibly be.

//============================================================================

package fft_wrapper_sequence_item;

    import uvm_pkg::*;
    import fft_cfg_pkg::*;
    `include "uvm_macros.svh"

    class fft_wrapper_seq_item extends uvm_sequence_item;

    logic rst_n;
    logic en;
    logic signed [DATA_WIDTH-1:0] in_re;
    logic signed [DATA_WIDTH-1:0] in_im;
    logic signed [DATA_WIDTH-1:0] out_re;
    logic signed [DATA_WIDTH-1:0] out_im;

    `uvm_object_utils(fft_wrapper_seq_item)

    function new(string name = "fft_wrapper_seq_item");
        super.new(name);
    endfunction

endclass

endpackage
