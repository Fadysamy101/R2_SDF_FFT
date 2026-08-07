function [y0, y1] = butterfly(x0, x1, W, T)
    x0 = cast(x0, 'like', T.x0);
    x1 = cast(x1, 'like', T.x1) * W;
    y0 = x0 + x1;
    y1 = x0 - x1;

end

