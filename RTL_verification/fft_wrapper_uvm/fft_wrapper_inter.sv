
`timescale 1ns / 1ps

// The DEFAULT is what matters here, not the instantiation. `virtual
// fft_wrapper_inter` is referenced unparameterized in the driver, monitor,
// test, scoreboard and config, so specialising the instance to #(12) while
// those handles still point at the #(16) default would be a type mismatch
// across the whole TB. Changing the default keeps every handle consistent.
interface fft_wrapper_inter #(parameter int DATA_WIDTH = fft_cfg_pkg::DATA_WIDTH)
                             (input bit clk);

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
