package fft_wrapper_env_pac;
import uvm_pkg::*;
import fft_wrapper_agtt::*;
import fft_wrapper_scoreborad_pck::*;
`include "uvm_macros.svh"
`timescale 1ns/1ps

class fft_wrapper_env extends uvm_env;
    `uvm_component_utils(fft_wrapper_env)
    fft_wrapper_agt agt;
    fft_wrapper_scoreborad sb;
   
    function new(string name = "fft_wrapper_env" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "fft_wrapper environment build phase", UVM_LOW)
        agt = fft_wrapper_agt::type_id::create("agt",this);
        sb = fft_wrapper_scoreborad::type_id::create("sb",this);
      
    endfunction 
    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        agt.agt_ap.connect(sb.sb_export);
        //agt.agt_ap.connect(cov.cov_export);
    endfunction 
endclass 
    
endpackage