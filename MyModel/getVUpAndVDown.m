function [vUp, vDown] = getVUpAndVDown(G, D, n, Sx0)
    alpha = 1;          % α为常量系数
    [fUp, fDown] = getFUpAndFDown(G, D, n);
    
    vUp = alpha * fUp + Sx0;
    vDown = alpha * fDown + Sx0;
end

