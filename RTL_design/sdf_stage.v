//============================================================================
// sdf_stage.v  -  One Single-path Delay Feedback stage.
//
// Direct transcription of sdf_stage() from the MATLAB model.
//
// Contents:
//   - delay RAM, DEPTH complex words, read and written at the same address
//   - address pointer, wraps every DEPTH cycles (gives DEPTH cycles of delay)
//   - free-running counter, 0 .. 2*DEPTH-1, the ONLY control logic:
//       phase_counter <  DEPTH  ->  load phase     (store input, pass old value out)
//       phase_counter >= DEPTH  ->  butterfly phase
//     and during the butterfly phase, phase_counter[AW-1:0] is the twiddle index k
//   - butterfly, plus a multiplier only when USE_MULT = 1
//   - two muxes, both driven by the butterfly_phase bit
//
// SCALING: each stage divides by 2 (the >>> 1 on both outputs). This keeps
// every datapath the same width instead of growing one bit per stage. Over
// four stages the result is X[k]/16 - remember that when comparing against
// a reference FFT.
//
// USE_MULT = 0 for stages 3 and 4: their only twiddles are +1 and -j, both
// pure wiring. No multiplier, no ROM.
//============================================================================
`timescale 1ns / 1ps
`default_nettype none
module sdf_stage #(
    parameter DATA_WIDTH             = 16,   // data width
    parameter DELAY_DEPTH            = 8,    // delay line depth
    parameter ADDR_WIDTH             = 3,    // address width, = log2(DELAY_DEPTH), minimum 1
    parameter USE_TWIDDLE_MULTIPLIER = 1,    // 1 for stages 1-2, 0 for stages 3-4
    parameter TWIDDLE_WIDTH          = 16,   // coefficient width
    parameter TWIDDLE_FRAC_BITS      = 14    // coefficient fractional bits
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 en,       // clock enable / data valid

    input  wire signed [DATA_WIDTH-1:0] in_re,
    input  wire signed [DATA_WIDTH-1:0] in_im,

    input  wire signed [TWIDDLE_WIDTH-1:0] w_re,     // from twiddle_rom, tie to 0 if unused
    input  wire signed [TWIDDLE_WIDTH-1:0] w_im,
    output wire [ADDR_WIDTH-1:0]        twiddle_addr,  // drives the ROM address

    output wire signed [DATA_WIDTH-1:0] out_re,
    output wire signed [DATA_WIDTH-1:0] out_im
);

    //------------------------------------------------------------------
    //------------------------------------------------------------------
    // State
    //------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] delay_line_re [0:DELAY_DEPTH-1];
    reg signed [DATA_WIDTH-1:0] delay_line_im [0:DELAY_DEPTH-1];
    reg        [ADDR_WIDTH-1:0] delay_ptr;
    reg        [ADDR_WIDTH:0]   phase_counter;

    //------------------------------------------------------------------
    // Control - one comparison, nothing more
    //------------------------------------------------------------------
    wire butterfly_phase = (phase_counter >= DELAY_DEPTH);      // 0 = load, 1 = butterfly

    // DELAY_DEPTH is a power of two, so subtracting it is just dropping the MSB
    assign twiddle_addr = phase_counter[ADDR_WIDTH-1:0];

    //------------------------------------------------------------------
    // RAM read (combinational, before the write - gives DEPTH-cycle delay)
    //------------------------------------------------------------------
    wire signed [DATA_WIDTH-1:0] delayed_re = delay_line_re[delay_ptr];
    wire signed [DATA_WIDTH-1:0] delayed_im = delay_line_im[delay_ptr];

    //------------------------------------------------------------------
    // Butterfly
    //------------------------------------------------------------------
    wire signed [DATA_WIDTH:0] butterfly_sum_re, butterfly_sum_im, butterfly_diff_re, butterfly_diff_im;

    butterfly #(.DATA_WIDTH(DATA_WIDTH)) u_bf (
        .delayed_sample_re (delayed_re),    .delayed_sample_im (delayed_im),
        .input_sample_re   (in_re),         .input_sample_im   (in_im),
        .butterfly_sum_re  (butterfly_sum_re),  .butterfly_sum_im  (butterfly_sum_im),
        .butterfly_diff_re (butterfly_diff_re), .butterfly_diff_im (butterfly_diff_im)
    );

    // Scale by 1/2 to hold the width constant
    wire signed [DATA_WIDTH-1:0] scaled_sum_re = butterfly_sum_re  >>> 1;
    wire signed [DATA_WIDTH-1:0] scaled_sum_im = butterfly_sum_im  >>> 1;
    wire signed [DATA_WIDTH-1:0] scaled_diff_re = butterfly_diff_re >>> 1;
    wire signed [DATA_WIDTH-1:0] scaled_diff_im = butterfly_diff_im >>> 1;

    //------------------------------------------------------------------
    // Twiddle path
    //------------------------------------------------------------------
    wire twiddle_is_one  = (twiddle_addr == 0);                // W^0 = +1
    wire twiddle_is_neg_j = (twiddle_addr == (DELAY_DEPTH >> 1)); // W^(N/2) = -j

    wire signed [DATA_WIDTH-1:0] feedback_re, feedback_im;

    generate
        if (USE_TWIDDLE_MULTIPLIER != 0) begin : g_mult
            wire signed [DATA_WIDTH-1:0] mult_out_re, mult_out_im;

            cmult #(.DATA_WIDTH(DATA_WIDTH), .TWIDDLE_WIDTH(TWIDDLE_WIDTH), .TWIDDLE_FRAC_BITS(TWIDDLE_FRAC_BITS)) u_mul (
                .input_data_re (scaled_diff_re), .input_data_im (scaled_diff_im),
                .twiddle_re    (w_re), .twiddle_im    (w_im),
                .product_re    (mult_out_re), .product_im    (mult_out_im)
            );

            // -j : (a,b) -> (b,-a)
            assign feedback_re = twiddle_is_one ? scaled_diff_re : (twiddle_is_neg_j ?  scaled_diff_im : mult_out_re);
            assign feedback_im = twiddle_is_one ? scaled_diff_im : (twiddle_is_neg_j ? -scaled_diff_re : mult_out_im);
        end
        else begin : g_nomult
            // Only +1 and -j occur here - pure wiring, no arithmetic
            assign feedback_re = twiddle_is_one ? scaled_diff_re :  scaled_diff_im;
            assign feedback_im = twiddle_is_one ? scaled_diff_im : -scaled_diff_re;
        end
    endgenerate

    //------------------------------------------------------------------
    // The two muxes
    //------------------------------------------------------------------
    wire signed [DATA_WIDTH-1:0] delay_write_re = butterfly_phase ? feedback_re : in_re;   // RAM write data
    wire signed [DATA_WIDTH-1:0] delay_write_im = butterfly_phase ? feedback_im : in_im;

    assign out_re = butterfly_phase ? scaled_sum_re : delayed_re;                 // stage output
    assign out_im = butterfly_phase ? scaled_sum_im : delayed_im;

    //------------------------------------------------------------------
    // Clock edge
    //------------------------------------------------------------------
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_ptr <= 0;
            phase_counter <= 0;
            for (i = 0; i < DELAY_DEPTH; i = i + 1) begin
                delay_line_re[i] <= 0;
                delay_line_im[i] <= 0;
            end
        end
        else if (en) begin
            delay_line_re[delay_ptr] <= delay_write_re;
            delay_line_im[delay_ptr] <= delay_write_im;
            delay_ptr <= (delay_ptr == DELAY_DEPTH-1)     ? 0 : delay_ptr + 1;
            phase_counter <= (phase_counter == 2*DELAY_DEPTH-1) ? 0 : phase_counter + 1;
        end
    end

endmodule
