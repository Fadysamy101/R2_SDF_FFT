
`timescale 1ns / 1ps

interface fft_wrapper_inter #(parameter int DATA_WIDTH = 16) (input bit clk);

    logic                          rst_n;
    logic                          en;
    logic signed [DATA_WIDTH-1:0]  in_re;
    logic signed [DATA_WIDTH-1:0]  in_im;

    // driven by the DUT -> must be nets
    wire  signed [DATA_WIDTH-1:0]  out_re;
    wire  signed [DATA_WIDTH-1:0]  out_im;

    clocking mon_cb @(posedge clk);
        default input #1step;
        input rst_n, en, in_re, in_im, out_re, out_im;
    endclocking

    modport MON (clocking mon_cb, input clk);

endinterface
