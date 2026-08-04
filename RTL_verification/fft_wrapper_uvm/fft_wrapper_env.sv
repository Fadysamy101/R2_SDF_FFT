package fft_wrapper_env_pac;
import uvm_pkg::*;
import fft_wrapper_agtt::*;
import fft_wrapper_coverage_pkg::*;
import fft_wrapper_scoreborad_pck::*;
`include "uvm_macros.svh"

class fft_wrapper_env extends uvm_env;
    `uvm_component_utils(fft_wrapper_env)
    fft_wrapper_agt agt;
    fft_wrapper_scoreborad sb;
    fft_wrapper_cover cov;
    function new(string name = "fft_wrapper_env" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        agt = fft_wrapper_agt::type_id::create("agt",this);
        sb = fft_wrapper_scoreborad::type_id::create("sb",this);
        cov = fft_wrapper_cover::type_id::create("cov",this);
    endfunction 
    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);
        agt.agt_ap.connect(sb.sb_export);
        agt.agt_ap.connect(cov.cov_export);
    endfunction 
endclass 
    
endpackage