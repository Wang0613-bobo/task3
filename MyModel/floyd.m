function [D, P] = floyd(W)
    % 输入参数 W：邻接矩阵
    % 输出参数 D：最短路径长度
    % 输出参数 P：最短路径

    n = size(W,1);
    D = W;
    P = repmat(1:n,[n 1]);

    for k = 1:n
        for i = 1:n
            for j = 1:n
                if D(i,j) > D(i,k) + D(k,j)
                    D(i,j) = D(i,k) + D(k,j);
                    P(i,j) = P(k,j);
                end
            end
        end
    end

    % 对角线为零
    D = D - diag(diag(D));
    P = P - diag(diag(P));
end