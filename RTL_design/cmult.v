//============================================================================
// cmult.v  -  Complex multiply by a twiddle coefficient.
//
//   (a + jb)(c + jd) = (ac - bd) + j(ad + bc)
//
`timescale 1ns / 1ps
`default_nettype none
module cmult #(
    parameter DATA_WIDTH = 16,   // data width
    parameter TWIDDLE_WIDTH = 16,   // coefficient width
    parameter TWIDDLE_FRAC_BITS = 14    // coefficient fractional bits
)(
    input  wire signed [DATA_WIDTH-1:0] input_data_re,
    input  wire signed [DATA_WIDTH-1:0] input_data_im,
    input  wire signed [TWIDDLE_WIDTH-1:0] twiddle_re,
    input  wire signed [TWIDDLE_WIDTH-1:0] twiddle_im,

    output wire signed [DATA_WIDTH-1:0] product_re,
    output wire signed [DATA_WIDTH-1:0] product_im
);

    // Full-precision partial products
    wire signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] real_real_product = input_data_re * twiddle_re;
    wire signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] imag_imag_product = input_data_im * twiddle_im;
    wire signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] real_imag_product = input_data_re * twiddle_im;
    wire signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] imag_real_product = input_data_im * twiddle_re;

    // One extra bit for the add/sub
    wire signed [DATA_WIDTH+TWIDDLE_WIDTH:0] full_precision_real = real_real_product - imag_imag_product;
    wire signed [DATA_WIDTH+TWIDDLE_WIDTH:0] full_precision_imag = real_imag_product + imag_real_product;

    // Realign the binary point. Arithmetic shift preserves sign.
    // This truncates (rounds toward -inf), matching RoundingMethod 'Floor'
    // in the MATLAB model. For round-to-nearest, add (1 << (TWIDDLE_FRAC_BITS-1)) first.
    assign product_re = full_precision_real >>> TWIDDLE_FRAC_BITS;
    assign product_im = full_precision_imag >>> TWIDDLE_FRAC_BITS;

endmodule
