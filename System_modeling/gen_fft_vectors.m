%% gen_fft_vectors.m
% Generate input / golden-output hex vectors for the 16-point R2SDF FFT RTL.
%
% Files written (one hex word per line, two's complement, MSB-first):
%   input_re.hex     DATA_WL-bit real part,      natural order (DUT input order)
%   input_im.hex     DATA_WL-bit imag part,      natural order
%   input_cplx.hex   {re,im} packed, 2*DATA_WL bits per line
%   output_re.hex    DATA_WL-bit real part,      BIT-REVERSED (DUT output order)
%   output_im.hex    DATA_WL-bit imag part,      BIT-REVERSED
%   output_cplx.hex  {re,im} packed
%   meta.txt         N, latency, widths, frame count
%
% NOTE ordering: the SDF pipeline emits bins in bit-reversed order, so the
% golden output files are left in that order. The testbench compares the DUT
% stream directly, sample-for-sample, with no reordering.

clear; clc;

%% ---- Configuration (must match the RTL parameters) ----
N        = 16;
nStages  = log2(N);
D        = N ./ (2.^(1:nStages));

DATA_WL  = 16;          % RTL DATA_WIDTH
DATA_FL  = 13;          % RTL binary point -> s2.13, range [-4, +4)
                        % <-- set this to match sdf_types('fixed')

nFrames  = 20;          % number of test frames to emit
inScale  = 0.25;        % pre-scale on randn so |x| stays inside full scale
outDir   = 'vectors';

T = sdf_types('fixed');

% fimath matching the RTL: truncate, wrap (no saturation logic in the RTL)
F = fimath('RoundingMethod','Floor', ...
           'OverflowAction','Wrap', ...
           'ProductMode','FullPrecision', ...
           'SumMode','FullPrecision');

if ~exist(outDir,'dir'), mkdir(outDir); end

%% ---- Open files ----
f.in_re   = fopen(fullfile(outDir,'input_re.hex'),   'w');
f.in_im   = fopen(fullfile(outDir,'input_im.hex'),   'w');
f.in_cx   = fopen(fullfile(outDir,'input_cplx.hex'), 'w');
f.out_re  = fopen(fullfile(outDir,'output_re.hex'),  'w');
f.out_im  = fopen(fullfile(outDir,'output_im.hex'),  'w');
f.out_cx  = fopen(fullfile(outDir,'output_cplx.hex'),'w');
c = onCleanup(@() structfun(@fclose, f));

latency  = NaN;
maxAbsIn = 0;

%% ---- Frame loop ----
for s = 1:nFrames
    rng(s);
    x = inScale * complex(randn(1,N), randn(1,N));

    % Quantize the stimulus exactly as the DUT will see it, then use the
    % quantized values (not the doubles) to drive the model. Otherwise the
    % golden output carries an input-quantization error the DUT never had.
    xre = fi(real(x), 1, DATA_WL, DATA_FL, F);
    xim = fi(imag(x), 1, DATA_WL, DATA_FL, F);
    xq  = complex(double(xre), double(xim));

    maxAbsIn = max(maxAbsIn, max(abs(xq)));
    check_range(xq, DATA_WL, DATA_FL, s);

    % Golden output from the fixed-point model. Output is already X[k]/16
    % (1/2 scaling per stage) and in bit-reversed order -- no *16, no unshuffle.
    [y, lat] = sdf_r2dif_fft(xq, N, D, T);
    latency  = lat;
    Y = y(lat+1 : lat+N);

    yre = fi(real(double(Y)), 1, DATA_WL, DATA_FL, F);
    yim = fi(imag(double(Y)), 1, DATA_WL, DATA_FL, F);

    write_hex(f.in_re,  f.in_im,  f.in_cx,  xre, xim);
    write_hex(f.out_re, f.out_im, f.out_cx, yre, yim);
end

%% ---- Metadata for the testbench ----
fm = fopen(fullfile(outDir,'meta.txt'),'w');
fprintf(fm, 'N          %d\n', N);
fprintf(fm, 'FRAMES     %d\n', nFrames);
fprintf(fm, 'DATA_WL    %d\n', DATA_WL);
fprintf(fm, 'DATA_FL    %d\n', DATA_FL);
fprintf(fm, 'LATENCY    %d\n', latency);
fprintf(fm, 'ORDER_IN   natural\n');
fprintf(fm, 'ORDER_OUT  bitreversed\n');
fclose(fm);

fprintf('Wrote %d frames (%d samples) to ./%s\n', nFrames, nFrames*N, outDir);
fprintf('Model latency : %d cycles\n', latency);
fprintf('Peak |x| used : %.4f  (full scale %.4f)\n', ...
        maxAbsIn, 2^(DATA_WL-1-DATA_FL));

%% ===================================================================
function write_hex(fre, fim, fcx, vre, vim)
% hex() on a fi object gives the raw two's-complement bit pattern,
% zero-padded to ceil(WL/4) digits -- exactly what $readmemh wants.
    hre = hex(vre);
    him = hex(vim);
    for k = 1:size(hre,1)
        fprintf(fre, '%s\n', hre(k,:));
        fprintf(fim, '%s\n', him(k,:));
        fprintf(fcx, '%s%s\n', hre(k,:), him(k,:));   % {re, im}
    end
end

function check_range(v, WL, FL, frameIdx)
    fs = 2^(WL-1-FL);
    if max(abs(v)) >= fs
        error('Frame %d: |x| = %.4f exceeds full scale %.4f. Lower inScale.', ...
              frameIdx, max(abs(v)), fs);
    end
end
