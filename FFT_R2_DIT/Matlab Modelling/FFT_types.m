function T = FFT_types(dt)
switch dt
    case 'double'
        T.x   = complex(double([]));
        T.W   = complex(double([]));
        T.x0   = complex(double([]));
        T.x1   = complex(double([]));
        T.s1  = complex(double([]));  
        T.s2  = complex(double([]));  
        T.s3   = complex(double([])); 
        T.s4   = complex(double([]));

    case 'single'
        T.x   = complex(single([]));
        T.W   = complex(single([]));
        T.x0   = complex(single([]));
        T.x1   = complex(single([]));
        T.s1  = complex(single([]));  
        T.s2  = complex(single([]));
        T.s3   = complex(single([]));
        T.s4   = complex(single([]));
              
     case 'FxPt' % Word Length = 12 bits
        T.x   = fi(complex(0,0), 1, 3 + 9, 9);    % Input: 3 int, 9 frac  
        T.W   = fi(complex(0,0), 1, 2 + 10, 10);  % Twiddle: 2 int, 10 frac 
        T.x0   = fi(complex(0,0), 1, 5 + 7, 7);    % Butterfly input 1: 5 int, 7 frac 
        T.x1   = fi(complex(0,0), 1, 5 + 7, 7);    % Butterfly input 2: 5 int, 7 frac 
        T.s1  = fi(complex(0,0), 1, 4 + 8, 8);    % First Stage output: 4 int, 8 frac 
        T.s2  = fi(complex(0,0), 1, 4 + 8, 8);    % Second Stage output: 4 int, 8 frac 
        T.s3   = fi(complex(0,0), 1, 5 + 7, 7);    % third Stage output: 5 int, 7 frac 
        T.s4   = fi(complex(0,0), 1, 5 + 7, 7);    % fourth Stage output: 5 int, 7 frac 
        
end

end