function mc = monte_carlo_robustness(vec, X_no, X_greedy, X_lp, C, cfg, residuals)
% MONTE_CARLO_ROBUSTNESS  Evaluate fixed dispatch policies under demand noise.
%
% For each Monte Carlo scenario m = 1..M:
%   sample tilde_P ~ Poisson(P_hat_next)   if cfg.mc_distribution == 'poisson'
%   sample tilde_P = max(P_hat_next + bootstrap(residuals), 0)  if 'bootstrap'
%
% Then evaluate the THREE FIXED dispatch matrices against tilde_P (not re-solved):
%   no-rebalance, greedy, LP.
%
% Returns:
%   mc.unmet      M x 3  total real-unmet per scenario [no, greedy, lp]
%   mc.service    M x 3
%   mc.cost       M x 3  (no-rebalance cost = 0, greedy & lp from C .* X)
%   mc.summary    struct with mean/median/q05/q95 per policy

    Q_cur = vec.Q_current(:);
    P_hat = vec.P_hat_next(:);
    K = numel(Q_cur);
    M = cfg.mc_n_scenarios;

    rng_seed_local = cfg.rng_seed;
    rng(rng_seed_local, 'twister');

    mc.unmet   = zeros(M, 3);
    mc.service = zeros(M, 3);
    mc.cost    = zeros(M, 3);
    mc.policies = {'no_rebalance', 'greedy', 'lp'};

    cost_no     = 0.0;
    cost_greedy = sum(sum(C .* X_greedy));
    cost_lp     = sum(sum(C .* X_lp));

    use_bootstrap = strcmpi(cfg.mc_distribution, 'bootstrap');
    if use_bootstrap && (nargin < 7 || isempty(residuals))
        warning('bootstrap requested but no residuals supplied — falling back to Poisson');
        use_bootstrap = false;
    end

    for m = 1:M
        if use_bootstrap
            r = residuals(randi(numel(residuals), K, 1));
            P_sim = max(P_hat + r, 0);
        else
            P_sim = poisson_sample(P_hat);
        end

        % no-rebalance
        ev0 = evaluate_dispatch(Q_cur, P_sim, zeros(K, K), C, []);
        % greedy
        evg = evaluate_dispatch(Q_cur, P_sim, X_greedy, C, []);
        % lp
        evl = evaluate_dispatch(Q_cur, P_sim, X_lp, C, []);

        mc.unmet(m, :)   = [ev0.total_unmet, evg.total_unmet, evl.total_unmet];
        mc.service(m, :) = [ev0.service_rate, evg.service_rate, evl.service_rate];
        mc.cost(m, :)    = [cost_no, cost_greedy, cost_lp];
    end

    mc.summary = struct();
    names = mc.policies;
    for c = 1:3
        s.mean_unmet     = mean(mc.unmet(:, c));
        s.median_unmet   = median(mc.unmet(:, c));
        s.q95_unmet      = quantile_safe(mc.unmet(:, c), 0.95);
        s.mean_service   = mean(mc.service(:, c));
        s.q05_service    = quantile_safe(mc.service(:, c), 0.05);
        s.empty_cost     = mc.cost(1, c);
        mc.summary.(names{c}) = s;
    end
end


function out = poisson_sample(lambda)
% Simple per-element Poisson sampler. lambda is a vector, possibly with zeros.
    out = zeros(size(lambda));
    for i = 1:numel(lambda)
        L = lambda(i);
        if L <= 0
            out(i) = 0;
        elseif L < 30
            out(i) = knuth_poisson(L);
        else
            % normal approximation for large lambda
            out(i) = max(0, round(L + sqrt(L) * randn()));
        end
    end
end


function k = knuth_poisson(lambda)
    L = exp(-lambda);
    k = 0;
    p = 1;
    while true
        k = k + 1;
        p = p * rand();
        if p <= L
            k = k - 1;
            return;
        end
        if k > 1e6  % safety
            return;
        end
    end
end


function q = quantile_safe(v, p)
% Built-in quantile may be unavailable in 北太天元; use linear interp on sort.
    v = sort(v(:));
    n = numel(v);
    if n == 0
        q = NaN; return;
    end
    h = (n - 1) * p + 1;
    h_lo = max(1, floor(h));
    h_hi = min(n, ceil(h));
    if h_lo == h_hi
        q = v(h_lo);
    else
        q = v(h_lo) + (h - h_lo) * (v(h_hi) - v(h_lo));
    end
end
