import fft_wrapper_test_pkg::*;
import uvm_pkg::*;

`timescale 1ns/1ps
`include "uvm_macros.svh"
module top ();
    bit clk ;
    initial begin
        forever begin
            #10;
            clk=!clk;
        end
    end

    fft_wrapper_inter fft_wrapper_test_vif(clk);
    fft_wrapper #(
        .DATA_WIDTH(16),
        .TWIDDLE_WIDTH(16),
        .TWIDDLE_FRAC_BITS(14)
    ) dut (
        .clk(clk),
        .rst_n(fft_wrapper_test_vif.rst_n),
        .en(fft_wrapper_test_vif.en),
        .in_re(fft_wrapper_test_vif.in_re),
        .in_im(fft_wrapper_test_vif.in_im),
        .out_re(fft_wrapper_test_vif.out_re),
        .out_im(fft_wrapper_test_vif.out_im)
    );
    sva #(
        .DATA_WIDTH(16)
    ) dut_sva (
        .clk(clk),
        .rst_n(fft_wrapper_test_vif.rst_n),
        .en(fft_wrapper_test_vif.en),
        .in_re(fft_wrapper_test_vif.in_re),
        .in_im(fft_wrapper_test_vif.in_im),
        .out_re(fft_wrapper_test_vif.out_re),
        .out_im(fft_wrapper_test_vif.out_im)
    );
    initial begin
    uvm_config_db#(virtual fft_wrapper_inter)::set(null,"*","fft_wrapper_test_vif",fft_wrapper_test_vif);
    run_test("fft_wrapper_test");
    end

endmodule