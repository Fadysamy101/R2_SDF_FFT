function [y, latency] = sdf_r2dif_fft(x, N, D, T) %#codegen


    latency = sum(D);
    total   = N + latency;

    tw1 = cast(coder.const(tw_rom(D(1))), 'like', T.tw);
    tw2 = cast(coder.const(tw_rom(D(2))), 'like', T.tw);
    tw3 = cast(coder.const(tw_rom(D(3))), 'like', T.tw);
    tw4 = cast(coder.const(tw_rom(D(4))), 'like', T.tw);

    %% ---- Delay lines: one named variable per stage, own type each ----
    fifo1 = complex(zeros(1, D(1), 'like', T.fifo1));
    fifo2 = complex(zeros(1, D(2), 'like', T.fifo2));
    fifo3 = complex(zeros(1, D(3), 'like', T.fifo3));
    fifo4 = complex(zeros(1, D(4), 'like', T.fifo4));

    cnt = zeros(1, 4);                 % free-running counters (control, not data)
    y   = complex(zeros(1, total, 'like', T.y));

    zeroIn = complex(zeros(1, 1, 'like', T.x));   % flush value

    for c = 1:total
        if c <= N
            s0 = cast(x(c), 'like', T.x);
        else
            s0 = zeroIn;               % flush the pipe
        end

        [s1, fifo1, cnt(1)] = sdf_stage(s0, fifo1, cnt(1), D(1), tw1, T.bf1, T.mul1);
        [s2, fifo2, cnt(2)] = sdf_stage(s1, fifo2, cnt(2), D(2), tw2, T.bf2, T.mul2);
        [s3, fifo3, cnt(3)] = sdf_stage(s2, fifo3, cnt(3), D(3), tw3, T.bf3, T.bf3);
        [s4, fifo4, cnt(4)] = sdf_stage(s3, fifo4, cnt(4), D(4), tw4, T.bf4, T.bf4);

        y(c) = cast(s4, 'like', T.y);
    end
end

%% ===================================================================
function [out, fifo, cnt] = sdf_stage(sample, fifo, cnt, Ds, tw, Tbf, Tmul)


    period = 2*Ds;
    popped = fifo(1);                  % value stored Ds cycles ago

    if cnt < Ds
        % ---- load phase: store new sample, pass the old one through ----
        fifo = [fifo(2:end), cast(sample, 'like', fifo)];
        out  = cast(popped, 'like', Tbf);
    else
        % ---- butterfly phase ----
        k       = cnt - Ds;                                   
        sum_ab  = bitsra(popped + sample, 1);
        diff_ab = bitsra(popped - sample, 1);
        
        sum_ab  = cast(sum_ab, 'like', Tbf);
        diff_ab = apply_twiddle(cast(diff_ab, 'like', Tmul), k, Ds, tw, Tmul);
        fifo    = [fifo(2:end), cast(diff_ab, 'like', fifo)];   % -> out later
        out     = sum_ab;
    end

    cnt = mod(cnt + 1, period);
end


function z = apply_twiddle(d, k, Ds, tw, Tmul)


    if k == 0                                  % W^0 = +1, pass through
        z = cast(d, 'like', Tmul);
    elseif 2*k == Ds                           % W^(period/4) = -j
        z = cast(complex(imag(d), -real(d)), 'like', Tmul);
    else                                       % general complex multiply
        z = cast(d * tw(k+1), 'like', Tmul);
    end
end


function tw = tw_rom(Ds)
    tw = complex(zeros(1, Ds));
    for k = 0:Ds-1
        tw(k+1) = exp(-1j*2*pi*k/(2*Ds));
    end
end