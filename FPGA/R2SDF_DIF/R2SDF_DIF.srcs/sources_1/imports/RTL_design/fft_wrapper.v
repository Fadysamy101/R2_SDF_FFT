`default_nettype none
module fft_wrapper #(
    parameter DATA_WIDTH        = 12,
    parameter TWIDDLE_WIDTH     = 12,
    parameter TWIDDLE_FRAC_BITS = 11
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 en,

    input  wire signed [DATA_WIDTH-1:0] in_re,
    input  wire signed [DATA_WIDTH-1:0] in_im,

    output wire signed [DATA_WIDTH-1:0] out_re,
    output wire signed [DATA_WIDTH-1:0] out_im
);

    wire signed [DATA_WIDTH-1:0] s1_out_re, s1_out_im;
    wire signed [DATA_WIDTH-1:0] s2_out_re, s2_out_im;
    wire signed [DATA_WIDTH-1:0] s3_out_re, s3_out_im;

    wire [2:0] s1_twiddle_addr;
    wire [1:0] s2_twiddle_addr;

    wire signed [TWIDDLE_WIDTH-1:0] w1_re, w1_im;
    wire signed [TWIDDLE_WIDTH-1:0] w2_re, w2_im;

    //----------------------------------------------------------------
    // Stage 1  -  delay 8, W_16^k, k = 0..7
    //----------------------------------------------------------------
    sdf_stage #(
        .DATA_WIDTH(DATA_WIDTH), .DELAY_DEPTH(8), .ADDR_WIDTH(3),
        .USE_TWIDDLE_MULTIPLIER(1),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH), .TWIDDLE_FRAC_BITS(TWIDDLE_FRAC_BITS)
    ) u_s1 (
        .clk(clk), .rst_n(rst_n), .en(en),
        .in_re(in_re), .in_im(in_im),
        .w_re(w1_re), .w_im(w1_im),
        .twiddle_addr(s1_twiddle_addr),
        .out_re(s1_out_re), .out_im(s1_out_im)
    );

    twiddle_rom #(.DEPTH(8), .AW(3), .CW(TWIDDLE_WIDTH)) u_rom1 (
        .addr(s1_twiddle_addr), .w_re(w1_re), .w_im(w1_im)
    );

    //----------------------------------------------------------------
    // Stage 2  -  delay 4, W_8^k, k = 0..3
    //----------------------------------------------------------------
    sdf_stage #(
        .DATA_WIDTH(DATA_WIDTH), .DELAY_DEPTH(4), .ADDR_WIDTH(2),
        .USE_TWIDDLE_MULTIPLIER(1),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH), .TWIDDLE_FRAC_BITS(TWIDDLE_FRAC_BITS)
    ) u_s2 (
        .clk(clk), .rst_n(rst_n), .en(en),
        .in_re(s1_out_re), .in_im(s1_out_im),
        .w_re(w2_re), .w_im(w2_im),
        .twiddle_addr(s2_twiddle_addr),
        .out_re(s2_out_re), .out_im(s2_out_im)
    );

    twiddle_rom #(.DEPTH(4), .AW(2), .CW(TWIDDLE_WIDTH)) u_rom2 (
        .addr(s2_twiddle_addr), .w_re(w2_re), .w_im(w2_im)
    );

    //----------------------------------------------------------------
    // Stage 3  -  delay 2, twiddles are +1 and -j: no ROM, no multiplier
    //----------------------------------------------------------------
    sdf_stage #(
        .DATA_WIDTH(DATA_WIDTH), .DELAY_DEPTH(2), .ADDR_WIDTH(1),
        .USE_TWIDDLE_MULTIPLIER(0),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH), .TWIDDLE_FRAC_BITS(TWIDDLE_FRAC_BITS)
    ) u_s3 (
        .clk(clk), .rst_n(rst_n), .en(en),
        .in_re(s2_out_re), .in_im(s2_out_im),
        .w_re({TWIDDLE_WIDTH{1'b0}}), .w_im({TWIDDLE_WIDTH{1'b0}}),
        .twiddle_addr(),                     
        .out_re(s3_out_re), .out_im(s3_out_im)
    );

    //----------------------------------------------------------------
    // Stage 4  -  delay 1, only W_2^0 = +1
    //----------------------------------------------------------------
    sdf_stage #(
        .DATA_WIDTH(DATA_WIDTH), .DELAY_DEPTH(1), .ADDR_WIDTH(1),
        .USE_TWIDDLE_MULTIPLIER(0),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH), .TWIDDLE_FRAC_BITS(TWIDDLE_FRAC_BITS)
    ) u_s4 (
        .clk(clk), .rst_n(rst_n), .en(en),
        .in_re(s3_out_re), .in_im(s3_out_im),
        .w_re({TWIDDLE_WIDTH{1'b0}}), .w_im({TWIDDLE_WIDTH{1'b0}}),
        .twiddle_addr(),                      
        .out_re(out_re), .out_im(out_im)
    );

endmodule