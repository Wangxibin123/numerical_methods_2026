function pred = predict_historical_mean(data, split)
% PREDICT_HISTORICAL_MEAN  Forecast next-hour pickup by (zone, weekday, hour_of_day) mean.
%
%   y_hat_{i,t+1} = mean over training set of P_{i,s} where
%                   hour_of_day(s) == hour_of_day(t+1) and
%                   weekday(s)     == weekday(t+1)
%
% Returns:
%   pred.train, pred.val, pred.test  vectors aligned with split.{train,val,test}_idx
%   pred.full                        full-length vector aligned with data.panel rows
%   pred.true_y                      full-length real next-hour pickup
%   pred.has_next                    boolean mask: does this row have a "next" hour?
%
% Note: Baltamatica community ed lacks containers.Map. We use a dense 3D array
% indexed by [zone_position, weekday, hour_of_day] for O(1) lookup.

    [next_pickup, has_next] = compute_next_pickup(data);
    pred.true_y = next_pickup;
    pred.has_next = has_next;

    p = data.panel;
    zones = double(p.zone_id);
    hod = double(p.hour_of_day);   % 0..23
    wd  = double(p.weekday);       % 0..6
    N = numel(zones);

    % map each zone_id to a 1..K position
    top_zones = double(p.zone_id(:));
    uz = unique(top_zones);
    K = numel(uz);
    zone_pos = zeros(max(uz) + 1, 1);
    zone_pos(uz + 1) = 1:K;
    pos_all = zone_pos(zones + 1);            % N x 1

    % accumulate train sums/counts into a [K, 7, 24] cube
    sum_cube = zeros(K, 7, 24);
    cnt_cube = zeros(K, 7, 24);

    train_keep = split.train_mask & has_next;
    pos_tr = pos_all(train_keep);
    wd_tr  = wd(train_keep);
    hod_tr = hod(train_keep);
    next_tr = next_pickup(train_keep);

    % vectorised accumulation
    for r = 1:numel(pos_tr)
        i = pos_tr(r);
        j = wd_tr(r) + 1;
        k = hod_tr(r) + 1;
        sum_cube(i, j, k) = sum_cube(i, j, k) + next_tr(r);
        cnt_cube(i, j, k) = cnt_cube(i, j, k) + 1;
    end

    global_mean = mean(next_tr);
    mean_cube = sum_cube ./ max(cnt_cube, 1);
    % cells with zero count fall back to global mean
    miss = (cnt_cube == 0);
    mean_cube(miss) = global_mean;

    yhat = zeros(N, 1);
    for r = 1:N
        yhat(r) = mean_cube(pos_all(r), wd(r) + 1, hod(r) + 1);
    end
    pred.full = max(yhat, 0);

    pred.train = pred.full(split.train_idx);
    pred.val   = pred.full(split.val_idx);
    pred.test  = pred.full(split.test_idx);
end


function [next_p, has_next] = compute_next_pickup(data)
% For each panel row r, pick up the row immediately after r if it belongs to
% the same zone and has hour_index = current + 1.  The python preprocessing
% guarantees rows are sorted by (zone_id, hour_index) ascending.
    p = data.panel;
    zones = double(p.zone_id);
    hi = double(p.hour_index);
    pickups = double(p.pickup_count);
    N = numel(zones);

    next_p = zeros(N, 1);
    has_next = false(N, 1);

    next_zone = zones(2:end);
    next_hi   = hi(2:end);
    cur_zone  = zones(1:end-1);
    cur_hi    = hi(1:end-1);
    valid = (next_zone == cur_zone) & (next_hi == cur_hi + 1);
    next_p(1:N-1) = valid .* pickups(2:end);
    has_next(1:N-1) = valid;

    if ~all(valid)
        % defensive fallback: shouldn't trigger given the validated panel
        n_gap = sum(~valid) - 50;  % each zone has one "last" hour, expected = K
        if n_gap > 0
            warning('panel contiguity off by %d (beyond per-zone last-hour)', n_gap);
        end
    end
end
