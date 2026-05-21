function pred = predict_ridge(data, split, cfg, hm_pred)
% PREDICT_RIDGE  Closed-form ridge regression for next-hour pickup.
%
%   beta_hat = (X'X + alpha I)^{-1} X' y
%   y_hat   = X beta_hat       (clipped to >= 0)
%
% Inputs:
%   data      : output of load_processed_data
%   split     : output of split_train_test
%   cfg       : output of config_project (uses cfg.alpha_ridge, cfg.ridge_features)
%   hm_pred   : output of predict_historical_mean (reuses .true_y, .has_next)
%
% Outputs:
%   pred.full        N x 1  fitted y_hat on all panel rows
%   pred.train       y_hat on training set
%   pred.val
%   pred.test
%   pred.beta        (d+1) x 1 with intercept first
%   pred.feature_names cellstr matching beta order (cell{1} = '(intercept)')

    feats = cfg.ridge_features;
    p = data.panel;

    % build design matrix
    X = zeros(numel(p.zone_id), numel(feats));
    for j = 1:numel(feats)
        name = feats{j};
        if ~isfield(p, name)
            error('feature %s not in panel', name);
        end
        X(:, j) = double(p.(name));
    end

    y = hm_pred.true_y;
    has_next = hm_pred.has_next;

    train_keep = split.train_mask & has_next;
    Xtr = X(train_keep, :);
    ytr = y(train_keep);

    % column-standardise X for numerical stability; recover beta in original scale
    mu = mean(Xtr, 1);
    sigma = std(Xtr, 0, 1);
    sigma(sigma == 0) = 1.0;
    Xtr_s = (Xtr - mu) ./ sigma;

    % add intercept
    Xtr_a = [ones(size(Xtr_s, 1), 1), Xtr_s];
    d = size(Xtr_a, 2);
    I = eye(d);
    I(1, 1) = 0;     % don't penalise intercept

    A = Xtr_a' * Xtr_a + cfg.alpha_ridge * I;
    b = Xtr_a' * ytr;
    beta_s = A \ b;

    % apply standardisation to full X
    X_s = (X - mu) ./ sigma;
    X_a = [ones(size(X_s, 1), 1), X_s];
    yhat = max(X_a * beta_s, 0);

    pred.full = yhat;
    pred.train = yhat(split.train_idx);
    pred.val   = yhat(split.val_idx);
    pred.test  = yhat(split.test_idx);
    pred.beta  = beta_s;
    pred.feature_names = ['(intercept)', feats(:)']';
    pred.mu = mu;
    pred.sigma = sigma;
end
