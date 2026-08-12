package fft_wrapper_test_pkg;
import fft_wrapper_env_pac::*;
import fft_sequences_pkg::*;
import uvm_pkg::*;
// import sequences
import fft_wrapper_configuration::*;
import reset_sequence::*;
`timescale 1ns/1ps
`include "uvm_macros.svh"
class fft_wrapper_test extends uvm_test;
    `uvm_component_utils(fft_wrapper_test)
    fft_wrapper_confg conf_fft_wrapper;
    fft_wrapper_env env_fft_wrapper;
    fft_matlab_seq  matlab_seq;
    // define sequences
    function new(string name = "fft_wrapper_test",uvm_component parent = null);
        super.new(name,parent);
    endfunction 

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "fft_wrapper test build phase", UVM_LOW)
        env_fft_wrapper = fft_wrapper_env::type_id::create("env",this);
        matlab_seq = fft_matlab_seq::type_id::create("matlab_seq",this);

        conf_fft_wrapper = fft_wrapper_confg::type_id::create("conf_fft_wrapper",this);
        
       

        if(!uvm_config_db#(virtual fft_wrapper_inter)::get(this,"","fft_wrapper_test_vif",conf_fft_wrapper.fft_wrapper_test_vif))
        `uvm_fatal("build_phase","a333333333");
        
        conf_fft_wrapper.is_active = UVM_ACTIVE;// to make it passive we can use UVM_PASSIVE
        uvm_config_db#(fft_wrapper_confg)::set(null,"*","CFG",conf_fft_wrapper);
    endfunction 

    task run_phase (uvm_phase phase);
        virtual fft_wrapper_inter vif = conf_fft_wrapper.fft_wrapper_test_vif;
        super.run_phase(phase);
        phase.raise_objection(this);

        matlab_seq.start(env_fft_wrapper.agt.sqr);

        // The last item is driven on a negedge but the DUT only samples it on
        // the next posedge, and the SDF pipeline is LATENCY deep behind that.
        // Keep the clock running (driver holds en=1 on the last item) so the
        // final frame drains out and the monitor sees it. Waiting on negedges
        // parks us safely between the last needed posedge and the next one, so
        // we neither race the monitor nor capture a 321st sample.
        repeat (conf_fft_wrapper.LATENCY + 1) @(negedge vif.clk);

        phase.drop_objection(this);
    endtask
    

endclass 

endpackage