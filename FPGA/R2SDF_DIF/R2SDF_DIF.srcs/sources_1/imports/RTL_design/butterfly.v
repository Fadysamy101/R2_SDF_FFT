
`timescale 1ns / 1ps
`default_nettype none
module butterfly #(
    parameter DATA_WIDTH = 16
)(
    input  wire signed [DATA_WIDTH-1:0] delayed_sample_re,   // from the delay line
    input  wire signed [DATA_WIDTH-1:0] delayed_sample_im,
    input  wire signed [DATA_WIDTH-1:0] input_sample_re,    // arriving this cycle
    input  wire signed [DATA_WIDTH-1:0] input_sample_im,

    output wire signed [DATA_WIDTH:0] butterfly_sum_re,  // a + b -> leaves the stage now
    output wire signed [DATA_WIDTH:0] butterfly_sum_im,
    output wire signed [DATA_WIDTH:0] butterfly_diff_re, // a - b -> twiddled, then stored
    output wire signed [DATA_WIDTH:0] butterfly_diff_im
);

    assign butterfly_sum_re  = delayed_sample_re + input_sample_re;
    assign butterfly_sum_im  = delayed_sample_im + input_sample_im;
    assign butterfly_diff_re = delayed_sample_re - input_sample_re;
    assign butterfly_diff_im = delayed_sample_im - input_sample_im;

endmodule
