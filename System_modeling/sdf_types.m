function T = sdf_types(mode)
%SDF_TYPES  Numeric types for the R2SDF FFT model.
%
%   The datapath geometry is declared ONCE, here. gen_fft_vectors.m derives
%   DATA_WL/DATA_FL from the returned struct and writes them into meta.txt, and
%   the UVM scoreboard fatals if meta.txt disagrees with fft_cfg_pkg::DATA_WIDTH.
%   Changing the width is a one-line edit here plus the matching line in
%   RTL_verification/fft_wrapper_uvm/fft_cfg_pkg.sv.
%
%   Every datapath node carries the SAME type. fft_wrapper.v is uniform-width
%   integer arithmetic (see the comment at sdf_stage.v:12-15) with no binary
%   point anywhere -- the only fraction length in the whole design is
%   TWIDDLE_FRAC_BITS, used solely as the shift amount in cmult.v:35-36.
%   Per-stage fraction lengths are therefore NOT representable in this hardware.
%   Assigning them makes the model describe a different architecture, and it
%   diverges from the RTL rather than converging on it.
%
%   FL is a pure labelling convention: the scoreboard compares raw integer codes
%   and never learns the binary point. It only has to be self-consistent.
%
%   fimath is 'Nearest' + 'Wrap':
%     'Nearest' breaks ties toward +Inf, which is exactly what cmult.v:35-36
%       does with (x + 2^13) >>> 14. Do NOT use 'Round' -- it breaks ties away
%       from zero and so differs on every negative half-way product.
%     'Wrap' because no part of the RTL saturates.
%   The butterfly /2 does not use this rounding at all: sdf_r2dif_fft.m halves
%   with bitsra, an arithmetic shift, matching the signed >>> 1 at
%   sdf_stage.v:82-85 (floor toward -Inf).

    if nargin < 1
        mode = 'double';
    end

    % ---- The only place the datapath geometry is written down ----------
    W  = 12;   % RTL DATA_WIDTH         -- must equal fft_cfg_pkg::DATA_WIDTH
    FL = 9;    % labelling only; the RTL datapath has no binary point
    TW = 16;   % RTL TWIDDLE_WIDTH      -- twiddle_rom.v is hardcoded 16-bit
    TF = 14;   % RTL TWIDDLE_FRAC_BITS

    switch lower(mode)

        case 'double'
            T = fill_uniform(double([]));

        case 'single'
            T = fill_uniform(single([]));

        case 'fixed'

            F = fimath( ...
                'RoundingMethod', 'Nearest', ...
                'OverflowAction', 'Wrap',    ...
                'ProductMode',    'FullPrecision', ...
                'SumMode',        'FullPrecision');

            d = fi([], 1, W, FL, 'fimath', F);

            T.x     = d;

            % twiddle_rom.v is signed Q2.14 regardless of DATA_WIDTH. It carries
            % no local fimath on purpose: MATLAB rejects fi*fi when the two
            % operands have differing local fimaths, so leaving it off lets the
            % data operand's fimath govern the product. Both are FullPrecision,
            % so the multiply is exact either way.
            T.tw    = removefimath(fi([], 1, TW, TF));

            T.bf1   = d;   T.mul1 = d;   T.fifo1 = d;
            T.bf2   = d;   T.mul2 = d;   T.fifo2 = d;
            T.bf3   = d;   T.mul3 = d;   T.fifo3 = d;
            T.bf4   = d;   T.mul4 = d;   T.fifo4 = d;

            T.y     = d;

        otherwise
            error('sdf_types:badMode', ...
                  'mode must be ''double'', ''single'', or ''fixed''.');
    end
end


function T = fill_uniform(p)
    T.x     = p;
    T.tw    = p;
    T.fifo1 = p;   T.bf1 = p;   T.mul1 = p;
    T.fifo2 = p;   T.bf2 = p;   T.mul2 = p;
    T.fifo3 = p;   T.bf3 = p;   T.mul3 = p;
    T.fifo4 = p;   T.bf4 = p;   T.mul4 = p;
    T.y     = p;
end
