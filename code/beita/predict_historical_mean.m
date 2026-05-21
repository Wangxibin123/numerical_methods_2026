function pred = predict_historical_mean(data, split)
% PREDICT_HISTORICAL_MEAN  Forecast next-hour pickup by (zone, weekday, hour_of_day) mean.
%
% Definition (matches report Eq. for Model 1):
%     y_hat_{i,t+1} = mean over training set of P_{i,s} where
%                     hour_of_day(s) == hour_of_day(t+1) and
%                     weekday(s)     == weekday(t+1)
%
% Returns:
%   pred.train, pred.val, pred.test  vectors aligned with split.{train,val,test}_idx
%   pred.full                        full-length vector aligned with data.panel rows
%   pred.true_y                      full-length real next-hour pickup
%
% Note: the panel was built sorted by zone_id then hour_index; therefore for any
% row r whose zone is z and hour_index = h, the "next hour" target is the row
% at zone z, hour h+1. We construct that by aligning per-zone shifts.

    [next_pickup, has_next] = compute_next_pickup(data);
    pred.true_y = next_pickup;
    pred.has_next = has_next;

    p = data.panel;
    zones = p.zone_id;
    hod = p.hour_of_day;
    wd  = p.weekday;
    N = numel(zones);

    % key = (zone, weekday, hour_of_day)  → use a hash-style accumulator
    % keys are int: zone*1000 + weekday*100 + hour_of_day  (top zones fit)
    keys_all = double(zones) * 10000 + double(wd) * 100 + double(hod);

    % build training accumulators
    train_mask = split.train_mask & has_next;
    keys_tr = keys_all(train_mask);
    next_tr = next_pickup(train_mask);

    % accumulate sum & count
    uniq_keys = unique(keys_tr);
    sum_map = containers.Map('KeyType', 'double', 'ValueType', 'double');
    cnt_map = containers.Map('KeyType', 'double', 'ValueType', 'double');
    for k = 1:numel(uniq_keys)
        mask = (keys_tr == uniq_keys(k));
        sum_map(uniq_keys(k)) = sum(next_tr(mask));
        cnt_map(uniq_keys(k)) = sum(mask);
    end

    % global fallback
    global_mean = mean(next_tr);

    yhat = zeros(N, 1);
    for i = 1:N
        k = keys_all(i);
        if isKey(sum_map, k)
            yhat(i) = sum_map(k) / max(cnt_map(k), 1);
        else
            yhat(i) = global_mean;
        end
    end
    pred.full = max(yhat, 0);

    pred.train = pred.full(split.train_idx);
    pred.val   = pred.full(split.val_idx);
    pred.test  = pred.full(split.test_idx);
end


function [next_p, has_next] = compute_next_pickup(data)
% For each panel row, look up the SAME zone, NEXT hour_index. has_next = false
% when this row is the last hour for its zone.
    p = data.panel;
    zones = double(p.zone_id);
    hi = double(p.hour_index);
    pickups = double(p.pickup_count);
    N = numel(zones);

    next_p = zeros(N, 1);
    has_next = false(N, 1);

    % the panel is sorted by zone_id then hour_index in Python preprocess; we
    % rely on that for an O(N) sweep instead of a hash lookup.
    %   panel[r+1] corresponds to next hour iff zone_id matches and
    %   hour_index increments by 1.
    for r = 1:(N - 1)
        if zones(r + 1) == zones(r) && hi(r + 1) == hi(r) + 1
            next_p(r) = pickups(r + 1);
            has_next(r) = true;
        end
    end
    % defensive: if assumption was violated, fall back to a map lookup
    if ~all(has_next(1:N-1))
        warning('panel not strictly contiguous per-zone — building hashed next lookup');
        key2idx = containers.Map('KeyType', 'double', 'ValueType', 'double');
        for r = 1:N
            k = zones(r) * 1e9 + hi(r);
            key2idx(k) = r;
        end
        next_p(:) = 0;
        has_next(:) = false;
        for r = 1:N
            k = zones(r) * 1e9 + (hi(r) + 1);
            if isKey(key2idx, k)
                next_p(r) = pickups(key2idx(k));
                has_next(r) = true;
            end
        end
    end
end
