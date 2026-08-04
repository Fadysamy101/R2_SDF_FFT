function T = sdf_types(mode)

    if nargin < 1
        mode = 'double';
    end

    switch lower(mode)

        case 'double'
            p = double([]);
            T = fill_uniform(p);
        case 'single'
            p = single([]);
            T = fill_uniform(p);

        case 'fixed'
            T.x     = fi([], 1, 4+12, 12);
            T.tw    = fi([], 1, 2+14, 14);

            T.bf1   = fi([], 1, 4+12, 12);
            T.mul1  = fi([], 1, 4+12, 12);
            T.fifo1 = fi([], 1, 4+12, 12);

            T.bf2   = fi([], 1, 4+12, 12);
            T.mul2  = fi([], 1, 4+12, 12);
            T.fifo2 = fi([], 1, 4+12, 12);

            T.bf3   = fi([], 1, 4+12, 12);
            T.fifo3 = fi([], 1, 4+12, 12);

            T.bf4   = fi([], 1, 4+12, 12);
            T.fifo4 = fi([], 1, 4+12, 12);

            T.y     = fi([], 1, 4+12, 12);
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
    T.fifo3 = p;   T.bf3 = p;
    T.fifo4 = p;   T.bf4 = p;
    T.y     = p;
end
