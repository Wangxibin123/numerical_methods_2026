function split = split_train_test(data, cfg)
% SPLIT_TRAIN_TEST  Verify the panel's split_id and expose index sets.
%
% Inputs:
%   data : output from load_processed_data
%   cfg  : output from config_project
%
% Outputs:
%   split.train_mask  logical (N x 1)
%   split.val_mask    logical (N x 1)
%   split.test_mask   logical (N x 1)
%   split.train_idx   indices where split_id == 0
%   split.val_idx     indices where split_id == 1
%   split.test_idx    indices where split_id == 2

    sid = data.panel.split_id;
    split.train_mask = (sid == 0);
    split.val_mask   = (sid == 1);
    split.test_mask  = (sid == 2);
    split.train_idx  = find(split.train_mask);
    split.val_idx    = find(split.val_mask);
    split.test_idx   = find(split.test_mask);

    n = numel(sid);
    fr = [sum(split.train_mask), sum(split.val_mask), sum(split.test_mask)] / n;
    fprintf('[split] train=%.3f val=%.3f test=%.3f (target %.2f/%.2f/%.2f)\n', ...
        fr(1), fr(2), fr(3), cfg.train_frac, cfg.val_frac, ...
        1 - cfg.train_frac - cfg.val_frac);

    if abs(fr(1) - cfg.train_frac) > 0.05 || abs(fr(2) - cfg.val_frac) > 0.05
        warning('split fractions deviate from config — verify Python preprocess');
    end
end
