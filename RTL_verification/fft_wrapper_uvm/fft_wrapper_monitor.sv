
`timescale 1ns/1ps
package fft_wrapper_monitor;

    import uvm_pkg::*;
    import fft_wrapper_sequence_item::*;
    import fft_wrapper_configuration::*;

    `include "uvm_macros.svh"

    class fft_wrapper_monitor extends uvm_monitor;

        `uvm_component_utils(fft_wrapper_monitor)

        fft_wrapper_seq_item item;
        int latency_cycles = 0;
        fft_wrapper_confg cfg;

        virtual fft_wrapper_inter fft_wrapper_test_vif;

        uvm_analysis_port #(fft_wrapper_seq_item) mon_ap;

        function new(
            string name = "fft_wrapper_monitor",
            uvm_component parent = null
        );
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);

            super.build_phase(phase);

            mon_ap = new("mon_ap", this);

            if (!uvm_config_db#(fft_wrapper_confg)::get(
                    this,
                    "",
                    "CFG",
                    cfg
                ))
            begin
                `uvm_fatal(
                    "MONITOR",
                    "Could not get fft_wrapper_confg from uvm_config_db"
                )
            end

            fft_wrapper_test_vif = cfg.fft_wrapper_test_vif;

        endfunction

        task run_phase(uvm_phase phase);

            super.run_phase(phase);
            latency_cycles = 0;

            while (latency_cycles <= cfg.LATENCY) begin

                `uvm_info(
                    get_type_name(),
                    $sformatf(
                        "Waiting for latency cycle %0d/%0d, rst_n = %0d",
                        latency_cycles + 1,
                        cfg.LATENCY,
                        fft_wrapper_test_vif.mon_cb.rst_n
                    ),
                    UVM_LOW
                )

                @(posedge fft_wrapper_test_vif.clk);

                if (fft_wrapper_test_vif.mon_cb.rst_n !== 1'bx)
                    latency_cycles++;
            end
            forever begin

                @(fft_wrapper_test_vif.mon_cb);

                item = fft_wrapper_seq_item::type_id::create("item");

                item.rst_n = fft_wrapper_test_vif.mon_cb.rst_n;
                item.en    = fft_wrapper_test_vif.mon_cb.en;

                item.in_re = fft_wrapper_test_vif.mon_cb.in_re;
                item.in_im = fft_wrapper_test_vif.mon_cb.in_im;

                item.out_re = fft_wrapper_test_vif.mon_cb.out_re;
                item.out_im = fft_wrapper_test_vif.mon_cb.out_im;

                `uvm_info(
                    "MON",
                    item.convert2string(),
                    UVM_HIGH
                )
                mon_ap.write(item);

            end

        endtask

    endclass

endpackage

