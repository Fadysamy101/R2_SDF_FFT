clear; clc; close all;

%% ---- Configuration ----
N       = 16;
nStages = log2(N);
D       = N ./ (2.^(1:nStages));
nSeeds  = 100;

brIdx = bit_reverse_index(N);

% Types
T  = sdf_types('fixed');   % fixed-point MEX model
Td = sdf_types('double');   % double-precision reference

%% ---- Build MEX once ----
rng(1);
x_build = randn(1,N) + 1i*randn(1,N);

buildInstrumentedMex('sdf_r2dif_fft', '-args', ...
    {x_build, coder.Constant(N), coder.Constant(D), T});

%% ---- Storage ----
errMax  = zeros(1, nSeeds);
errRMS  = zeros(1, nSeeds);
peakAbs = zeros(1, nSeeds);

% Overall SQNR for each seed
SQNR = zeros(1, nSeeds);

% SQNR for every FFT output cycle/bin
sqnrCycle = zeros(nSeeds, N);

%% ---- Monte Carlo loop ----
for s = 1:nSeeds

    rng(s);

    % Random complex input
    x = randn(1,N) + 1i*randn(1,N);

    %% ---- Fixed-point / MEX model ----
    [y_fixed, latency] = sdf_r2dif_fft_mex(x, N, D, T);

    % Remove latency
    Y_fixed_bitrev = y_fixed(latency+1 : latency+N);

    % Undo bit reversal
    Y_fixed = zeros(1,N);
    Y_fixed(brIdx) = Y_fixed_bitrev;

    % Undo the 1/16 scaling applied by the 4 FFT stages
    Y_fixed = Y_fixed * 16;


    %% ---- Double-precision SDF model ----
    [y_double, latency_double] = ...
        sdf_r2dif_fft(x, N, D, Td);

    Y_double_bitrev = ...
        y_double(latency_double+1 : latency_double+N);

    % Undo bit reversal
    Y_double = zeros(1,N);
    Y_double(brIdx) = Y_double_bitrev;

    % Same scaling as fixed-point result
    Y_double = Y_double * 16;


    %% ================================================================
    %  Functional error: fixed-point SDF vs MATLAB FFT
    % ================================================================

    Yref = fft(x);

    e = Y_fixed - Yref;

    errMax(s)  = max(abs(e));
    errRMS(s)  = sqrt(mean(abs(e).^2));
    peakAbs(s) = max(abs(x));


    %% ================================================================
    %  SQNR: fixed-point SDF vs double-precision SDF
    %
    %  This measures fixed-point quantization noise.
    % ================================================================

    e_sqnr = Y_fixed - Y_double;

    signalPower = abs(Y_double).^2;
    errorPower  = abs(e_sqnr).^2;


    % ---- SQNR for each output cycle/bin ----
    for k = 1:N

        if errorPower(k) == 0
            sqnrCycle(s,k) = Inf;
        else
            sqnrCycle(s,k) = ...
                10*log10(signalPower(k) / errorPower(k));
        end

    end


    % ---- Overall SQNR for this FFT frame ----
    totalSignalPower = sum(signalPower);
    totalErrorPower  = sum(errorPower);

    if totalErrorPower == 0
        SQNR(s) = Inf;
    else
        SQNR(s) = 10*log10( ...
            totalSignalPower / totalErrorPower);
    end


    %% ---- Terminal output ----
    fprintf('\nSeed %3d\n', s);
    fprintf('-------------------------------------------------------------\n');

    for k = 1:N
        fprintf(['Cycle %2d | Bin %2d | Functional Error = %10.3e' ...
                 ' | SQNR = %8.2f dB\n'], ...
                 latency+k, k-1, abs(e(k)), sqnrCycle(s,k));
    end

    fprintf('Overall SQNR = %.2f dB\n', SQNR(s));

end


%% ========================================================================
%  Summary
% ========================================================================

[worstErr, worstSeed] = max(errMax);

avgSQNR = mean(SQNR);

% Average SQNR for each output cycle across all seeds
avgSQNR_cycle = mean(sqnrCycle, 1);

fprintf('\n\n');
fprintf('=============================================================\n');
fprintf('                    MONTE CARLO SUMMARY\n');
fprintf('=============================================================\n');

fprintf('Seeds run                : %d\n', nSeeds);
fprintf('FFT size                 : %d\n', N);
fprintf('Pipeline latency         : %d cycles\n', latency);

fprintf('\n');
fprintf('Worst-case max abs error : %.3e  (seed %d)\n', ...
    worstErr, worstSeed);

fprintf('Mean of per-seed max err : %.3e\n', ...
    mean(errMax));

fprintf('Mean RMS error           : %.3e\n', ...
    mean(errRMS));

fprintf('Peak |x| seen            : %.4f\n', ...
    max(peakAbs));

fprintf('\n');
fprintf('Average overall SQNR     : %.2f dB\n', ...
    avgSQNR);

fprintf('Minimum overall SQNR     : %.2f dB\n', ...
    min(SQNR));

fprintf('Maximum overall SQNR     : %.2f dB\n', ...
    max(SQNR));


%% ========================================================================
%  Average SQNR per cycle
% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf('              AVERAGE SQNR PER OUTPUT CYCLE\n');
fprintf('=============================================================\n');

for k = 1:N

    fprintf('Cycle %2d | Bin %2d | Average SQNR = %8.2f dB\n', ...
        latency+k, k-1, avgSQNR_cycle(k));

end

fprintf('\n');
fprintf('Average SQNR across cycles = %.2f dB\n', ...
    mean(avgSQNR_cycle));


%% ---- SQNR pass/fail ----

fprintf('\n');

if avgSQNR > 40
    fprintf('PASS - Average SQNR is above 40 dB\n');
else
    fprintf('FAIL - Average SQNR is under 40 dB\n');
end


%% ========================================================================
%  Plots
% ========================================================================

figSize = [100 100 350 220];


% ---- 1. Worst bin error per seed ----
figure('Name','Worst bin error per seed','Position',figSize);

semilogy(1:nSeeds, errMax, '.-', ...
    'MarkerSize',6,'LineWidth',1);

grid on;
xlabel('seed');
ylabel('max |error|');
title('Worst bin error per seed','FontSize',10);
set(gca,'FontSize',5);


% ---- 2. Error distribution ----
figure('Name','Error distribution across seeds','Position',figSize);

histogram(log10(errMax + eps),20);

grid on;
xlabel('log_{10} max |error|');
ylabel('count');
title('Error distribution across seeds','FontSize',10);
set(gca,'FontSize',6);


% ---- 3. Overall SQNR per seed ----
figure('Name','SQNR per seed','Position',figSize);

plot(1:nSeeds, SQNR, '.-', ...
    'MarkerSize',6,'LineWidth',1);

hold on;
yline(40,'--','40 dB limit');

grid on;
xlabel('seed');
ylabel('SQNR (dB)');
title('Fixed-point SQNR per seed','FontSize',10);



% ---- 4. Average SQNR per output cycle ----
figure('Name','Average SQNR per cycle','Position',figSize);

plot(latency+1:latency+N, avgSQNR_cycle, ...
    '.-','MarkerSize',7,'LineWidth',1);

hold on;
yline(40,'--','40 dB limit');

grid on;
xlabel('output cycle');
ylabel('Average SQNR (dB)');
title('Average SQNR per output cycle','FontSize',10);
set(gca,'FontSize',6);


%% ========================================================================
%  Re-run worst seed for spectrum plots
% ========================================================================

rng(worstSeed);

xw = complex(randn(1,N), randn(1,N));

[yw, latency_w] = ...
    sdf_r2dif_fft_mex(xw, N, D, T);

Yw = zeros(1,N);

Yw(brIdx) = ...
    yw(latency_w+1 : latency_w+N);

Yw = Yw * 16;

Yref_w = fft(xw);


% ---- 5. Worst seed spectrum ----
figure('Name',sprintf('Worst seed (%d) - spectrum',worstSeed), ...
    'Position',figSize);

stem(0:N-1, abs(Yref_w), 'filled');

hold on;

stem(0:N-1, abs(Yw), 'x', ...
    'LineWidth',1.5);

legend('fft(x)', 'SDF model', ...
    'Location','best','FontSize',7);

grid on;
xlabel('bin k');
ylabel('|X[k]|');

title(sprintf('Worst seed (%d): spectrum',worstSeed), ...
    'FontSize',10);

set(gca,'FontSize',6);


% ---- 6. Worst seed error per bin ----
figure('Name',sprintf('Worst seed (%d) - error',worstSeed), ...
    'Position',figSize);

stem(0:N-1, abs(Yw-Yref_w));

grid on;
xlabel('bin k');
ylabel('|error|');

title(sprintf('Worst seed (%d): error per bin',worstSeed), ...
    'FontSize',10);

set(gca,'FontSize',6);


%% ========================================================================
function idx = bit_reverse_index(N)
% Returns idx such that:
% Y(idx) = Y_bitrev placed in natural FFT bin order.

    nb = log2(N);

    idx = zeros(1,N);

    for n = 0:N-1
        r = bin2dec(fliplr(dec2bin(n,nb)));
        idx(n+1) = r + 1;
    end
end