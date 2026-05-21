function cfg = config_project()
% CONFIG_PROJECT  Project-wide constants for the 北太天元 pipeline.
%
% All other scripts call this once. Edit defaults here, not inline.

    here = fileparts(mfilename('fullpath'));
    repo_root = fullfile(here, '..', '..');

    cfg.repo_root      = char(repo_root);
    cfg.processed_dir  = fullfile(cfg.repo_root, 'data', 'processed');
    cfg.tables_dir     = fullfile(cfg.repo_root, 'results', 'tables');
    cfg.figures_dir    = fullfile(cfg.repo_root, 'results', 'figures');

    if ~exist(cfg.tables_dir,  'dir'); mkdir(cfg.tables_dir);  end
    if ~exist(cfg.figures_dir, 'dir'); mkdir(cfg.figures_dir); end

    % files inside data/processed/
    cfg.panel_csv          = fullfile(cfg.processed_dir, 'panel_numeric.csv');
    cfg.panel_csv_noheader = fullfile(cfg.processed_dir, 'panel_numeric_noheader.csv');
    cfg.panel_cols_txt     = fullfile(cfg.processed_dir, 'panel_columns.txt');
    cfg.zone_meta_csv      = fullfile(cfg.processed_dir, 'zone_meta.csv');
    cfg.top_zones_csv      = fullfile(cfg.processed_dir, 'top_zones.csv');
    cfg.cost_matrix_csv    = fullfile(cfg.processed_dir, 'cost_matrix_topK.csv');
    cfg.test_hours_csv     = fullfile(cfg.processed_dir, 'test_hours.csv');

    % model / experiment hyper-parameters
    cfg.alpha_ridge      = 1.0;          % Ridge penalty
    % Lambda: penalty (miles) per 1 unit of UNMET demand. Setting it well above
    % the average OD distance (≈ 5 mi) makes the LP willing to dispatch even
    % far-away surplus to serve a deficit. We use 20 so the LP operates in the
    % regime where it can show its global-optimisation advantage over greedy.
    cfg.lambda_unmet     = 20.0;
    cfg.lambda_grid      = [1, 2, 5, 10, 15, 20, 30, 50, 100, 200];

    % Monte Carlo
    cfg.mc_n_scenarios   = 200;
    cfg.mc_distribution  = 'poisson';    % 'poisson' | 'bootstrap'
    cfg.rng_seed         = 20260521;

    % split fractions used to verify panel split_id
    cfg.train_frac = 0.70;
    cfg.val_frac   = 0.15;

    % feature list to use as Ridge inputs (must exist in panel_columns.txt)
    cfg.ridge_features = { ...
        'pickup_count', 'dropoff_count', ...
        'lag_pickup_1h', 'lag_pickup_2h', ...
        'lag_dropoff_1h', 'lag_dropoff_2h', ...
        'rolling_pickup_mean_6h', 'rolling_pickup_mean_24h', ...
        'rolling_dropoff_mean_6h', ...
        'same_hour_prev_day_pickup', 'same_hour_prev_week_pickup', ...
        'hour_sin', 'hour_cos', 'weekday', 'is_weekend' ...
    };
end
