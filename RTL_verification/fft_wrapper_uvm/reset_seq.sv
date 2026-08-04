//============================================================================
// reset_seq.sv  -  hold rst_n low, then release with the pipe idle.
//
// Kept in its own file/package because everything else imports it.
//============================================================================
package reset_sequence;

    import fft_wrapper_sequence_item::*;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class reset_seq extends uvm_sequence #(fft_wrapper_seq_item);

        `uvm_object_utils(reset_seq)

        fft_wrapper_seq_item item;
        int n_cycles = 5;

        function new(string name = "reset_seq");
            super.new(name);
        endfunction

        task body();
            `uvm_info(get_type_name(), $sformatf("asserting rst_n for %0d cycles", n_cycles), UVM_LOW)
            repeat (n_cycles) begin
                item = fft_wrapper_seq_item::type_id::create("item");
                start_item(item);
                item.rst_n = 1'b0;
                item.en    = 1'b0;
                item.in_re = '0;
                item.in_im = '0;
                finish_item(item);
            end
        endtask

    endclass

endpackage
