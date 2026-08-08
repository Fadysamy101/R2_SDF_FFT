package fft_wrapper_sequencer;
import uvm_pkg::*;
`include "uvm_macros.svh"
`timescale 1ns/1ps
import fft_wrapper_sequence_item::*;
class fft_wrapper_sqr_class extends uvm_sequencer #(fft_wrapper_seq_item);
    `uvm_component_utils(fft_wrapper_sqr_class)

    function new(string name = "fft_wrapper_sqr_class" , uvm_component parent = null);
        super.new(name,parent);
    endfunction

endclass 
    
endpackage