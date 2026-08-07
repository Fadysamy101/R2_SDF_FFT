

clear; clc; close all;

%% ---- Configuration ----
N       = 16;
nStages = log2(N);
D       = N ./ (2.^(1:nStages));   
nSeeds  = 100;


brIdx = bit_reverse_index(N);
T = sdf_types('fixed'); 

%% ---- Monte Carlo loop ----
errMax  = zeros(1, nSeeds);        % worst bin error for each seed
errRMS  = zeros(1, nSeeds);        % RMS error across bins for each seed
peakAbs = zeros(1, nSeeds);        % peak |input|, useful for range sizing

for s = 1:nSeeds
    rng(s);
    x = randn(1,N) + 1i*randn(1,N);
    if(s ==1)
    buildInstrumentedMex('sdf_r2dif_fft', '-args', ...
    {x, coder.Constant(N), coder.Constant(D), T})
    end    
    
    [y, latency] = sdf_r2dif_fft_mex(x, N, D, T);

    Y_bitrev = y(latency+1 : latency+N);
    Y        = zeros(1, N);
    Y(brIdx) = Y_bitrev;           % undo bit-reversal via the index table
    Y = Y*16;

    Yref = fft(x);
    e    = Y - Yref;

    errMax(s)  = max(abs(e));
    errRMS(s)  = sqrt(mean(abs(e).^2));
    peakAbs(s) = max(abs(x));
end

%% ---- Summary ----
[worstErr, worstSeed] = max(errMax);
fprintf('Seeds run                : %d\n',     nSeeds);
fprintf('Pipeline latency         : %d cycles\n', latency);
fprintf('Worst-case max abs error : %.3e  (seed %d)\n', worstErr, worstSeed);
fprintf('Mean of per-seed max err : %.3e\n',   mean(errMax));
fprintf('Mean RMS error           : %.3e\n',   mean(errRMS));
fprintf('Peak |x| seen            : %.4f\n',   max(peakAbs));



%% ---- Plots ----
figure('Name','Monte Carlo error summary');

subplot(2,2,1);
semilogy(1:nSeeds, errMax, '.-'); grid on;
xlabel('seed'); ylabel('max |error|');
title('Worst bin error per seed');

subplot(2,2,2);
histogram(log10(errMax + eps), 20); grid on;
xlabel('log_{10} max |error|'); ylabel('count');
title('Error distribution across seeds');

% Re-run the worst seed so we can plot its spectrum
rng(worstSeed);
xw = complex(randn(1,N), randn(1,N));
[yw, latency] = sdf_r2dif_fft_mex(xw, N, D, T);
Yw = zeros(1, N);
Yw(brIdx) = yw(latency+1 : latency+N);
Yref_w = fft(xw);
%sqnr
Td = sdf_types('double');
Tf = sdf_types('fixed');

rng(1);
x = complex(randn(1,N), randn(1,N));

[yd, lat] = sdf_r2dif_fft(x, N, D, Td);
[yf, ~]   = sdf_r2dif_fft(x, N, D, Tf);

Yd = yd(lat+1:lat+N);
Yf = double(yf(lat+1:lat+N));

SQNR = 10*log10( sum(abs(Yd).^2) / sum(abs(Yf - Yd).^2) );
fprintf('SQNR: %.2f dB\n', SQNR);
if SQNR > 40
    fprintf('PASS - SQNR is above 40 db');
else
    fprintf('FAIL - SQNR is under 40 db');
end

subplot(2,2,3);
stem(0:N-1, abs(Yref_w), 'filled'); hold on;
stem(0:N-1, abs(Yw), 'x', 'LineWidth', 1.5);
legend('fft(x)', 'SDF model', 'Location','best'); grid on;
xlabel('bin k'); ylabel('|X[k]|');
title(sprintf('Worst seed (%d): spectrum', worstSeed));

subplot(2,2,4);
stem(0:N-1, abs(Yw - Yref_w)); grid on;
xlabel('bin k'); ylabel('|error|');
title(sprintf('Worst seed (%d): error per bin', worstSeed));

%% ===================================================================
function idx = bit_reverse_index(N)
% Returns idx such that Y(idx) = Y_bitrev places each sample in its
% natural-order bin. Computed once instead of per frame.
    nb  = log2(N);
    idx = zeros(1, N);
    for n = 0:N-1
        r = bin2dec(fliplr(dec2bin(n, nb)));
        idx(n+1) = r + 1;
    end
end