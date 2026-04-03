function [fUp, fDown] = getFUpAndFDown(G, D, n)
%     D = 1;          % ãÐÖµ
%     n = 2;          % HillÏµÊý
    fUp = G.^n / (D.^n + G.^n);
    fDown = D.^n / (D.^n + G.^n);
end


