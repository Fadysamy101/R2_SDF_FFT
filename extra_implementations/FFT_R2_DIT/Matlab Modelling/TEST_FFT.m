clc; clear; close all;

%Create data types table
data_type ='FxPt';      % double, single or FxPt
T = FFT_types(data_type);

%Twiddle factor
W = cast([
    1.00000 + 0.00000i   % W^0
    0.92388 - 0.38268i   % W^1
    0.70711 - 0.70711i   % W^2
    0.38268 - 0.92388i   % W^3
    0.00000 - 1.00000i   % W^4
   -0.38268 - 0.92388i   % W^5
   -0.70711 - 0.70711i   % W^6
   -0.92388 - 0.38268i   % W^7 
   ], 'like', T.W);

% Design Parameters
N = 16;                     % FFT number of points
nseeds = 100;              % Number of random trials
error  = zeros(1, nseeds); % Store error for each trial
sqnr   = zeros(1, nseeds); % Store SQNR per trial

%generate IO files
fft_in   = fopen('FFT_inputs.txt', 'w');
fft_out  = fopen('FFT_outputs.txt', 'w');

fid_in_real   = fopen('FFT_inputs_real.txt', 'w');
fid_in_imag   = fopen('FFT_inputs_imag.txt', 'w');
fid_out_real   = fopen('FFT_outputs_real.txt', 'w');
fid_out_imag   = fopen('FFT_outputs_imag.txt', 'w');

for seed = 1:nseeds
    rng(seed);
    
    %Generate random complex test input signal
    X= randn(1,N) + 1j*randn(1,N);
    x = cast(X, 'like', T.x);
    
    for k = 1:length(x)
    fprintf(fft_in, '%s %s', hex(fi(real(x(k)))), hex(fi(imag(x(k)))));
            fprintf(fid_in_real, '%s ', bin(fi(real(X(k)))));
        fprintf(fid_in_imag, '%s ', bin(fi(imag(X(k)))));
    end

    % First iteration: build instrumented MEX
    if seed == 1
        buildInstrumentedMex FFT -args {x, T};
    end
    
% Call FFT algorithm 
Y = FFT_mex(x, T);

% Verify results
Y_Expected = fft(X);
error(seed) = abs(mean(double(Y) - Y_Expected));
% SQNR calculation
signal_power = sum(abs(Y_Expected).^2);
noise_power = sum(abs(double(Y) - Y_Expected).^2);
sqnr(seed) = 10*log10(signal_power / noise_power);

    for k = 1:length(Y)
        fprintf(fft_out, '%s %s ', bin(fi(real(Y(k)))), bin(fi(imag(Y(k)))));
        fprintf(fid_out_real, '%s ', bin(fi(real(Y(k)))));
        fprintf(fid_out_imag, '%s ', bin(fi(imag(Y(k)))));
    end
    
    % Add newlines for each seed
    fprintf(fft_in, '\n');
    fprintf(fft_out,'\n');
    fprintf(fid_in_real, '\n');
    fprintf(fid_in_imag, '\n');
    fprintf(fid_out_real,'\n');
    fprintf(fid_out_imag,'\n');
end

fclose(fft_in);
fclose(fft_out);
fclose(fid_in_real);
fclose(fid_in_imag);
fclose(fid_out_real);
fclose(fid_out_imag);

avg_sqnr = mean(sqnr); 

figure;
plot(1: nseeds, error, 'LineWidth', 2); grid on;
xlabel('seed', 'FontSize', 14); ylabel('Error', 'FontSize', 14);

figure;   
plot(1:nseeds, sqnr, 'LineWidth', 2); grid on;
xlabel('Seed', 'FontSize', 12); ylabel('SQNR (dB)', 'FontSize', 12);
title(sprintf('SQNR per seed, Average = %.3f dB', avg_sqnr), 'FontSize', 14);

%Show instrumentation results
showInstrumentationResults FFT_mex -proposeFL -defaultDT numerictype(1, 32)