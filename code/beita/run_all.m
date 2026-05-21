% RUN_ALL  One-click pipeline for the 北太天元 portion of the project.
%
%   1. load processed CSVs
%   2. split train / val / test
%   3. fit historical-mean + ridge predictors
%   4. write prediction_metrics.csv
%   5. for each test hour: build vectors, run no-rebalance / greedy / LP
%   6. write dispatch_metrics.csv
%   7. lambda sensitivity sweep
%   8. Monte Carlo robustness on last test hour
%   9. export figure-source CSVs (Python renders the PNGs)

clear;

here = fileparts(mfilename('fullpath'));
addpath(here);

fprintf('== run_all start ==\n');
cfg = config_project();

% ---------- 1. load ----------
data = load_processed_data(cfg);

% ---------- 2. split ----------
split = split_train_test(data, cfg);

% ---------- 3. predict ----------
fprintf('\n-- predictor 1: historical mean --\n');
hm = predict_historical_mean(data, split);
[mae_h, rmse_h, smape_h] = pred_metrics(hm.full, hm.true_y, split.test_mask & hm.has_next);
fprintf('historical_mean test: MAE=%.3f RMSE=%.3f sMAPE=%.4f\n', mae_h, rmse_h, smape_h);

fprintf('\n-- predictor 2: ridge regression --\n');
rg = predict_ridge(data, split, cfg, hm);
% ridge shares the same target as hm (same next-hour pickup)
[mae_r, rmse_r, smape_r] = pred_metrics(rg.full, hm.true_y, split.test_mask & hm.has_next);
fprintf('ridge           test: MAE=%.3f RMSE=%.3f sMAPE=%.4f (alpha=%.2f)\n', ...
        mae_r, rmse_r, smape_r, cfg.alpha_ridge);

% ---------- 4. prediction_metrics.csv ----------
pm = fopen(fullfile(cfg.tables_dir, 'prediction_metrics.csv'), 'w');
fprintf(pm, 'model,split,MAE,RMSE,sMAPE\n');
fprintf(pm, 'historical_mean,test,%.6f,%.6f,%.6f\n', mae_h, rmse_h, smape_h);
fprintf(pm, 'ridge,test,%.6f,%.6f,%.6f\n', mae_r, rmse_r, smape_r);
fclose(pm);
fprintf('written prediction_metrics.csv\n');

% pick the better predictor (lower test MAE) for downstream dispatch
if mae_r <= mae_h
    predictor_full = rg.full;
    fprintf('using ridge predictor for dispatch (lower test MAE)\n');
    predictor_name = 'ridge';
else
    predictor_full = hm.full;
    fprintf('using historical-mean predictor for dispatch (lower test MAE)\n');
    predictor_name = 'historical_mean';
end

% ---------- 5. per-test-hour dispatch ----------
fprintf('\n-- dispatch simulation --\n');
n_hours = numel(data.test_hours);
fprintf('%d test hours to simulate\n', n_hours);

dispatch_log = repmat(struct(), n_hours, 1);
C = data.cost_matrix;

for h = 1:n_hours
    hi = data.test_hours(h);
    vec = build_rebalance_vectors(data, hi, predictor_full);

    % baseline: no rebalance
    X0 = zeros(size(C));
    ev_no = evaluate_dispatch(vec.Q_current, vec.P_true_next, X0, C, []);

    % greedy
    X_greedy = greedy_rebalance(vec.S, vec.D, C);
    ev_greedy = evaluate_dispatch(vec.Q_current, vec.P_true_next, X_greedy, C, ...
                                  ev_no.total_unmet);

    % LP
    lp = solve_rebalance_lp(vec.S, vec.D, C, cfg.lambda_unmet);
    ev_lp = evaluate_dispatch(vec.Q_current, vec.P_true_next, lp.X, C, ...
                              ev_no.total_unmet);

    dispatch_log(h).hour_index   = hi;
    dispatch_log(h).S            = vec.S;
    dispatch_log(h).D            = vec.D;
    dispatch_log(h).Q_current    = vec.Q_current;
    dispatch_log(h).P_true_next  = vec.P_true_next;
    dispatch_log(h).P_hat_next   = vec.P_hat_next;
    dispatch_log(h).ev_no        = ev_no;
    dispatch_log(h).ev_greedy    = ev_greedy;
    dispatch_log(h).ev_lp        = ev_lp;
    dispatch_log(h).X_greedy     = X_greedy;
    dispatch_log(h).X_lp         = lp.X;

    fprintf('  hour %3d: unmet  no=%6.1f greedy=%6.1f lp=%6.1f   cost greedy=%6.1f lp=%6.1f\n', ...
            h, ev_no.total_unmet, ev_greedy.total_unmet, ev_lp.total_unmet, ...
            ev_greedy.empty_cost, ev_lp.empty_cost);
end

% ---------- 6. dispatch_metrics.csv ----------
dm = fopen(fullfile(cfg.tables_dir, 'dispatch_metrics.csv'), 'w');
fprintf(dm, ['hour_index,policy,unmet_demand,empty_distance_cost,' ...
             'service_rate,reduction_rate,unit_improvement_cost\n']);
for h = 1:n_hours
    hi = dispatch_log(h).hour_index;
    write_dispatch_row(dm, hi, 'no_rebalance', dispatch_log(h).ev_no);
    write_dispatch_row(dm, hi, 'greedy',       dispatch_log(h).ev_greedy);
    write_dispatch_row(dm, hi, 'lp',           dispatch_log(h).ev_lp);
end
fclose(dm);
fprintf('written dispatch_metrics.csv\n');

% ---------- 7. lambda sensitivity ----------
fprintf('\n-- lambda sensitivity --\n');
sweep = fopen(fullfile(cfg.tables_dir, 'sensitivity_lambda.csv'), 'w');
fprintf(sweep, 'lambda,total_unmet,empty_cost,service_rate\n');
hi_last = data.test_hours(end);
vec_last = build_rebalance_vectors(data, hi_last, predictor_full);
ev_no_last = evaluate_dispatch(vec_last.Q_current, vec_last.P_true_next, ...
                               zeros(size(C)), C, []);
for li = 1:numel(cfg.lambda_grid)
    lam = cfg.lambda_grid(li);
    lp = solve_rebalance_lp(vec_last.S, vec_last.D, C, lam);
    evl = evaluate_dispatch(vec_last.Q_current, vec_last.P_true_next, lp.X, C, ...
                            ev_no_last.total_unmet);
    fprintf(sweep, '%.6f,%.6f,%.6f,%.6f\n', lam, ...
            evl.total_unmet, evl.empty_cost, evl.service_rate);
    fprintf('  lambda=%6.2f → unmet=%6.1f cost=%6.1f service=%.4f\n', ...
            lam, evl.total_unmet, evl.empty_cost, evl.service_rate);
end
fclose(sweep);
fprintf('written sensitivity_lambda.csv\n');

% ---------- 8. Monte Carlo on last test hour ----------
fprintf('\n-- Monte Carlo robustness --\n');
last = dispatch_log(end);
mc = monte_carlo_robustness(struct( ...
        'Q_current',   last.Q_current, ...
        'P_hat_next',  last.P_hat_next, ...
        'P_true_next', last.P_true_next), ...
    zeros(size(C)), last.X_greedy, last.X_lp, C, cfg, []);

mcfh = fopen(fullfile(cfg.tables_dir, 'monte_carlo_metrics.csv'), 'w');
fprintf(mcfh, 'policy,mean_unmet,median_unmet,q95_unmet,mean_service,q05_service,empty_cost\n');
pn = mc.policies;
for c = 1:3
    s = mc.summary.(pn{c});
    fprintf(mcfh, '%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
        pn{c}, s.mean_unmet, s.median_unmet, s.q95_unmet, ...
        s.mean_service, s.q05_service, s.empty_cost);
    fprintf('  %-12s mean_unmet=%6.1f q95_unmet=%6.1f mean_srv=%.4f q05_srv=%.4f\n', ...
        pn{c}, s.mean_unmet, s.q95_unmet, s.mean_service, s.q05_service);
end
fclose(mcfh);
fprintf('written monte_carlo_metrics.csv\n');

% ---------- 9. figure data export ----------
fprintf('\n-- figure data export --\n');
export_figure_data(data, dispatch_log, mc, cfg);

fprintf('\n== run_all done ==\n');
fprintf('Run `python code/python/07_render_figures.py` to rasterise PNGs.\n');


% =====================================================================
function [mae, rmse, smape] = pred_metrics(yhat, y, mask)
    yhat = yhat(mask);
    y    = y(mask);
    err  = yhat - y;
    mae  = mean(abs(err));
    rmse = sqrt(mean(err .^ 2));
    smape = mean(2 * abs(err) ./ (abs(y) + abs(yhat) + 1e-9));
end


function write_dispatch_row(fid, hour_index, policy, ev)
    rr = ev.reduction_rate; if isnan(rr); rr_str = 'NA'; else; rr_str = sprintf('%.6f', rr); end
    uc = ev.unit_cost;      if isnan(uc); uc_str = 'NA'; else; uc_str = sprintf('%.6f', uc); end
    fprintf(fid, '%d,%s,%.6f,%.6f,%.6f,%s,%s\n', ...
        hour_index, policy, ev.total_unmet, ev.empty_cost, ...
        ev.service_rate, rr_str, uc_str);
end
