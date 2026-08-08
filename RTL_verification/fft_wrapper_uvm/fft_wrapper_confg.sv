package fft_wrapper_configuration;
import uvm_pkg::*;
`include "uvm_macros.svh"
class fft_wrapper_confg extends uvm_object;
    `uvm_object_utils(fft_wrapper_confg)
        virtual fft_wrapper_inter fft_wrapper_test_vif;
        parameter int LATENCY = 15;
        
        uvm_active_passive_enum is_active;
        function new(string name = "fft_wrapper_confg" );
        super.new(name);
        endfunction
endclass //className extends superClass
endpackage  
