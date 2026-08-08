//============================================================================
// fft_wrapper_driver.sv
//
// One item per clock. Drives on the negedge so the pins are settled well
// before the posedge that the DUT (and the monitor) sample on.
//============================================================================
`timescale 1ns / 1ps

package fft_wrapper_drive;

    import uvm_pkg::*;
    import fft_wrapper_configuration::*;
    import fft_wrapper_sequence_item::*;
    `include "uvm_macros.svh"

    class fft_wrapper_driver extends uvm_driver #(fft_wrapper_seq_item);

        `uvm_component_utils(fft_wrapper_driver)

        fft_wrapper_seq_item        item;
        virtual fft_wrapper_inter   fft_wrapper_test_vif;

        function new(string name = "fft_wrapper_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            `uvm_info(get_type_name(), "fft_wrapper driver build phase", UVM_LOW)
        endfunction

        task run_phase(uvm_phase phase);
            super.run_phase(phase);

            // Park the pins in reset until the first item shows up, so the DUT
            // never sees X on rst_n/en.
            fft_wrapper_test_vif.rst_n <= 1'b0;
            fft_wrapper_test_vif.en    <= 1'b0;
            fft_wrapper_test_vif.in_re <= '0;
            fft_wrapper_test_vif.in_im <= '0;

            forever begin
                seq_item_port.get_next_item(item);

                @(negedge fft_wrapper_test_vif.clk);
                fft_wrapper_test_vif.rst_n <= item.rst_n;
                fft_wrapper_test_vif.en    <= item.en;
                fft_wrapper_test_vif.in_re <= item.in_re;
                fft_wrapper_test_vif.in_im <= item.in_im;

                seq_item_port.item_done();
            end
        endtask

    endclass

endpackage
