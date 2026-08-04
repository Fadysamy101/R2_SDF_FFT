//============================================================================
// fft_wrapper_monitor.sv
//
// Samples through mon_cb (#1step before the posedge), which is the only
// race-free place to look: out_re/out_im are combinational off in_re/in_im,
// so reading them on the raw posedge would be a coin flip between the value
// belonging to this cycle and the next one.
//============================================================================
package fft_wrapper_monitor;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fft_wrapper_sequence_item::*;

    class fft_wrapper_monitor extends uvm_monitor;

        `uvm_component_utils(fft_wrapper_monitor)

        fft_wrapper_seq_item                        item;
        virtual fft_wrapper_inter                   fft_wrapper_test_vif;
        uvm_analysis_port #(fft_wrapper_seq_item)   mon_ap;

        function new(string name = "fft_wrapper_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon_ap = new("mon_ap", this);
        endfunction

        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin
                @(fft_wrapper_test_vif.mon_cb);

                item = fft_wrapper_seq_item::type_id::create("item");

                item.rst_n  = fft_wrapper_test_vif.mon_cb.rst_n;
                item.en     = fft_wrapper_test_vif.mon_cb.en;
                item.in_re  = fft_wrapper_test_vif.mon_cb.in_re;
                item.in_im  = fft_wrapper_test_vif.mon_cb.in_im;
                item.out_re = fft_wrapper_test_vif.mon_cb.out_re;
                item.out_im = fft_wrapper_test_vif.mon_cb.out_im;

                `uvm_info("MON", item.convert2string(), UVM_HIGH)
                mon_ap.write(item);
            end
        endtask

    endclass

endpackage
