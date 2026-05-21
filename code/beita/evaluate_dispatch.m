function ev = evaluate_dispatch(Q_current, P_true_next, X, C, baseline_unmet)
% EVALUATE_DISPATCH  Compute realised metrics from a dispatch matrix X.
%
% Inputs:
%   Q_current      K x 1   current-hour dropoff count (supply proxy)
%   P_true_next    K x 1   ACTUAL next-hour pickup demand (ground truth)
%   X              K x K   dispatch decisions (rows = source, cols = dest)
%   C              K x K   cost matrix (miles)
%   baseline_unmet scalar  total unmet demand under no-rebalance (for reduction ratio).
%                          Pass [] or NaN to skip reduction computation.
%
% Outputs:
%   ev.effective_supply  K x 1
%   ev.real_unmet        K x 1 (zone-level)
%   ev.total_unmet       scalar sum of real_unmet
%   ev.empty_cost        scalar sum(C .* X)
%   ev.service_rate      1 - total_unmet / max(sum(P_true_next), eps)
%   ev.reduction_rate    (baseline_unmet - total_unmet) / max(baseline_unmet, eps)
%   ev.unit_cost         empty_cost / max(baseline_unmet - total_unmet, eps)

    Q_current = Q_current(:);
    P_true_next = P_true_next(:);
    K = numel(Q_current);
    if numel(P_true_next) ~= K
        error('Q_current and P_true_next must be same length');
    end
    if any(size(X) ~= [K, K])
        error(sprintf('X must be %dx%d', K, K));
    end

    outflow = sum(X, 2);
    inflow  = sum(X, 1)';
    effective_supply = Q_current - outflow + inflow;
    real_unmet = max(P_true_next - effective_supply, 0);

    ev.effective_supply = effective_supply;
    ev.real_unmet       = real_unmet;
    ev.total_unmet      = sum(real_unmet);
    ev.empty_cost       = sum(sum(C .* X));

    EPS = 1e-9;
    ev.service_rate = 1 - ev.total_unmet / max(sum(P_true_next), EPS);

    if nargin >= 5 && ~isempty(baseline_unmet) && ~isnan(baseline_unmet)
        ev.reduction_rate = (baseline_unmet - ev.total_unmet) / max(baseline_unmet, EPS);
        improvement = baseline_unmet - ev.total_unmet;
        if improvement > EPS
            ev.unit_cost = ev.empty_cost / improvement;
        else
            ev.unit_cost = NaN;
        end
    else
        ev.reduction_rate = NaN;
        ev.unit_cost = NaN;
    end
end
