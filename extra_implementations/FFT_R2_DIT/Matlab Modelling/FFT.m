function s4 = FFT(x, T) %#codegen
N = 16;

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


s1 = zeros(size(x), 'like', T.s1);
s2 = zeros(size(x), 'like', T.s2);
s3 = zeros(size(x), 'like', T.s3);
s4 = zeros(size(x), 'like', T.s4);

x = cast(x, 'like', T.x);

%================ Stage 1 =====================

[s1(1), s1(2)]  =  butterfly(x(1), x(9), W(1), T);

[s1(3), s1(4)]  =  butterfly(x(5), x(13), W(1), T);

[s1(5), s1(6)]  =  butterfly(x(3), x(11), W(1), T);

[s1(7), s1(8)]  =  butterfly(x(7), x(15), W(1), T);

[s1(9), s1(10)] =  butterfly(x(2), x(10), W(1), T);

[s1(11), s1(12)] = butterfly(x(6), x(14), W(1), T);

[s1(13), s1(14)] = butterfly(x(4), x(12), W(1), T);

[s1(15), s1(16)] = butterfly(x(8), x(16), W(1), T);

fprintf("====stage 1====\n");
for i = 1:N
    disp(s1(i));
end
fprintf("\n\n");
%================ Stage 2 =====================

[s2(1), s2(3)] = butterfly(s1(1), s1(3), W(1), T);

[s2(2), s2(4)] = butterfly(s1(2), s1(4), W(5), T); 

[s2(5), s2(7)] = butterfly(s1(5), s1(7), W(1), T);

[s2(6), s2(8)] = butterfly(s1(6), s1(8), W(5), T); 

[s2(9), s2(11)] = butterfly(s1(9), s1(11), W(1), T);

[s2(10), s2(12)] = butterfly(s1(10), s1(12), W(5), T); 

[s2(13), s2(15)] = butterfly(s1(13), s1(15), W(1), T);

[s2(14), s2(16)] = butterfly(s1(14), s1(16), W(5), T);

fprintf("====stage 2====\n");
for i = 1:N
    disp(s2(i));
end
fprintf("\n\n");
%================ Stage 3 =====================

[s3(1), s3(5)] = butterfly(s2(1), s2(5), W(1), T);

[s3(2), s3(6)] = butterfly(s2(2), s2(6), W(3), T); 

[s3(3), s3(7)] = butterfly(s2(3), s2(7), W(5), T);

[s3(4), s3(8)] = butterfly(s2(4), s2(8), W(7), T); 

[s3(9), s3(13)] = butterfly(s2(9), s2(13), W(1), T);

[s3(10), s3(14)] = butterfly(s2(10), s2(14), W(3), T); 

[s3(11), s3(15)] = butterfly(s2(11), s2(15), W(5), T);

[s3(12), s3(16)] = butterfly(s2(12), s2(16), W(7), T);

fprintf("====stage 3====\n");
for i = 1:N
    disp(s3(i));
end
fprintf("\n\n");
%================ Stage 4 =====================

[s4(1), s4(9)] = butterfly(s3(1), s3(9), W(1), T);

[s4(2), s4(10)] = butterfly(s3(2), s3(10), W(2), T); 

[s4(3), s4(11)] = butterfly(s3(3), s3(11), W(3), T);

[s4(4), s4(12)] = butterfly(s3(4), s3(12), W(4), T); 

[s4(5), s4(13)] = butterfly(s3(5), s3(13), W(5), T);

[s4(6), s4(14)] = butterfly(s3(6), s3(14), W(6), T); 

[s4(7), s4(15)] = butterfly(s3(7), s3(15), W(7), T);

[s4(8), s4(16)] = butterfly(s3(8), s3(16), W(8), T);

fprintf("====stage 4====\n");
for i = 1:N
    disp(s4(i));
end
fprintf("\n\n");