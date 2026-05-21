function X = greedy_rebalance(S, D, C)
% GREEDY_REBALANCE  Nearest-neighbour greedy dispatch baseline.
%
% For each deficit zone (largest D first), pull from the cheapest available
% surplus zone until the deficit is filled or supply is exhausted.
%
% Returns:
%   X : K x K dispatch matrix (continuous, same units as S/D)

    S = S(:); D = D(:);
    K = numel(S);
    if numel(D) ~= K
        error('S and D must be same length');
    end
    if any(size(C) ~= [K, K])
        error('cost matrix must be %dx%d', K, K);
    end

    X = zeros(K, K);
    s = S;
    d = D;

    % deficit zones sorted by largest D first
    [~, deficit_order] = sort(d, 'descend');

    for jj = 1:numel(deficit_order)
        j = deficit_order(jj);
        if d(j) <= 0
            break;
        end

        % candidate suppliers: cheapest C(i,j) first, only those with s(i) > 0
        costs = C(:, j);
        [~, supplier_order] = sort(costs, 'ascend');
        for ii = 1:numel(supplier_order)
            i = supplier_order(ii);
            if s(i) <= 0
                continue;
            end
            send = min(s(i), d(j));
            X(i, j) = X(i, j) + send;
            s(i) = s(i) - send;
            d(j) = d(j) - send;
            if d(j) <= 0
                break;
            end
        end
    end
end
