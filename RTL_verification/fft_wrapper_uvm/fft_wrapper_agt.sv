`timescale 1ns/1ps
package fft_wrapper_agtt;
    import uvm_pkg::*;
    import fft_wrapper_drive::*;
    import fft_wrapper_sequencer::*;
    import fft_wrapper_monitor::*;
    import fft_wrapper_configuration::*;
    import fft_wrapper_sequence_item::*;
    `include "uvm_macros.svh"
    class fft_wrapper_agt extends uvm_agent;
        `uvm_component_utils(fft_wrapper_agt)
        fft_wrapper_driver driver;
        fft_wrapper_monitor monitor;
        fft_wrapper_confg cfg;
        fft_wrapper_sqr_class sqr;
        uvm_analysis_port #(fft_wrapper_seq_item) agt_ap;
        

        function new(string name="fft_wrapper_agt", uvm_component parent = null);
            super.new(name,parent);
        endfunction //new()
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            `uvm_info(get_type_name(), "fft_wrapper agent build phase", UVM_LOW)
            
            monitor = fft_wrapper_monitor::type_id::create("mon",this);

        if(!uvm_config_db #(fft_wrapper_confg) :: get(this,"","CFG",cfg))
        `uvm_fatal("build_phase","no");
        
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver = fft_wrapper_driver::type_id::create("driver",this);
            sqr = fft_wrapper_sqr_class::type_id::create("sqr",this);
        end
        
        agt_ap = new("agt_ap",this);
        endfunction
        
        function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        
        monitor.fft_wrapper_test_vif=cfg.fft_wrapper_test_vif;
        if(cfg.is_active==UVM_ACTIVE)
        begin
            driver.fft_wrapper_test_vif=cfg.fft_wrapper_test_vif;
            driver.seq_item_port.connect(sqr.seq_item_export);
        end
        monitor.mon_ap.connect(agt_ap);
    endfunction 
    endclass //className extends superClass
endpackage