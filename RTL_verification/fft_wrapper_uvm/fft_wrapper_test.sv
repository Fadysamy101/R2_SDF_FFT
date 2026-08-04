package fft_wrapper_test_pkg;
import fft_wrapper_env_pac::*;
import uvm_pkg::*;
// import sequences
import fft_wrapper_configuration::*;
import reset_sequence::*;
`include "uvm_macros.svh"
class fft_wrapper_test extends uvm_test;
    `uvm_component_utils(fft_wrapper_test)
    fft_wrapper_confg conf_fft_wrapper;
    fft_wrapper_env env_fft_wrapper;
    reset_seq reset_seq_h;
    // define sequences
    function new(string name = "fft_wrapper_test",uvm_component parent = null);
        super.new(name,parent);
    endfunction 

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        env_fft_wrapper = fft_wrapper_env::type_id::create("env",this);
        conf_fft_wrapper = fft_wrapper_confg::type_id::create("conf_fft_wrapper",this);
        reset_seq_h = reset_seq::type_id::create("reset_seq",this);
        if(!uvm_config_db#(virtual fft_wrapper_inter)::get(this,"","fft_wrapper_test_vif",conf_fft_wrapper.fft_wrapper_test_vif))
        `uvm_fatal("build_phase","a333333333");
        conf_fft_wrapper.is_active = UVM_ACTIVE;// to make it passive we can use UVM_PASSIVE
        uvm_config_db#(fft_wrapper_confg)::set(null,"*","CFG",conf_fft_wrapper);
    endfunction 

    task run_phase (uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this);
        // run sequences
        
        
        `uvm_info("run_phase", $sformatf("correct_count=%0d , wrong_count = %0d",env_fft_wrapper.sb.correct_count,env_fft_wrapper.sb.wrong_count),UVM_MEDIUM)

        phase.drop_objection(this);
    endtask
    

endclass 

endpackage