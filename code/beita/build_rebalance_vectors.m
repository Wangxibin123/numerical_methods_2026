function vec = build_rebalance_vectors(data, hour_index, predictor_yhat_full)
% BUILD_REBALANCE_VECTORS  Construct S, D, Q_current, P_true_next for one hour.
%
% Inputs:
%   data                : output of load_processed_data
%   hour_index          : scalar Unix hour to simulate (e.g. one element of test_hours)
%   predictor_yhat_full : N x 1 vector aligned with data.panel rows
%                         (= predictor.full from predict_historical_mean / predict_ridge)
%
% Outputs (all K x 1 with K = number of top zones, ordered by data.top_zones):
%   vec.Q_current       dropoff_count at current hour
%   vec.P_hat_next      predicted next-hour pickup
%   vec.P_true_next     true next-hour pickup (for evaluation)
%   vec.S               max(Q_current - P_hat_next, 0)  surplus
%   vec.D               max(P_hat_next - Q_current, 0)  deficit (predicted)
%   vec.hour_index      input hour_index
%   vec.row_idx         row indices in panel for the current hour, in zone order
%   vec.next_row_idx    row indices in panel for hour+1, in zone order (NaN if missing)

    p = data.panel;
    zones = double(data.top_zones);
    K = numel(zones);
    hour_index = double(hour_index);

    vec.hour_index = hour_index;
    vec.Q_current  = zeros(K, 1);
    vec.P_hat_next = zeros(K, 1);
    vec.P_true_next= zeros(K, 1);
    vec.row_idx    = nan(K, 1);
    vec.next_row_idx = nan(K, 1);

    zid = double(p.zone_id);
    hi  = double(p.hour_index);
    pu  = double(p.pickup_count);
    do  = double(p.dropoff_count);

    for k = 1:K
        z = zones(k);
        cur = find(zid == z & hi == hour_index, 1, 'first');
        nxt = find(zid == z & hi == hour_index + 1, 1, 'first');
        if isempty(cur)
            % zone missing at this hour shouldn't happen with a full grid; treat as 0
            vec.Q_current(k)  = 0;
            vec.P_hat_next(k) = 0;
        else
            vec.row_idx(k)    = cur;
            vec.Q_current(k)  = do(cur);
            vec.P_hat_next(k) = max(predictor_yhat_full(cur), 0);
        end
        if isempty(nxt)
            vec.P_true_next(k) = 0;
        else
            vec.next_row_idx(k) = nxt;
            vec.P_true_next(k)  = pu(nxt);
        end
    end

    vec.S = max(vec.Q_current  - vec.P_hat_next, 0);
    vec.D = max(vec.P_hat_next - vec.Q_current, 0);
end
