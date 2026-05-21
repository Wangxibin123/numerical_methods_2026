function make_core_figures(data, dispatch_log, mc_last, cfg)
% MAKE_CORE_FIGURES  Produce the five required figures from the simulation.
%
% Inputs:
%   data         : output of load_processed_data
%   dispatch_log : struct array, one entry per simulated test hour, with fields
%                    .hour_index .S .D .Q_current .P_true_next .ev_no .ev_greedy
%                    .ev_lp .X_lp .X_greedy
%   mc_last      : output of monte_carlo_robustness for the LAST test hour
%   cfg          : project config
%
% Writes 5 PNGs to results/figures/.

    if ~exist(cfg.figures_dir, 'dir'); mkdir(cfg.figures_dir); end

    plot_demand_pattern(data, cfg);
    plot_supply_demand_gap(dispatch_log, data, cfg);
    plot_dispatch_comparison(dispatch_log, cfg);
    plot_top_flows(dispatch_log, data, cfg);
    plot_mc_boxplot(mc_last, cfg);
end


function plot_demand_pattern(data, cfg)
    % aggregate pickup_count by hour_of_day x weekday, across all training rows
    p = data.panel;
    hod = double(p.hour_of_day);
    wd  = double(p.weekday);
    pu  = double(p.pickup_count);
    mask = (p.split_id == 0);

    grid = zeros(7, 24);
    cnt  = zeros(7, 24);
    for r = 1:numel(hod)
        if ~mask(r); continue; end
        i = wd(r) + 1;
        j = hod(r) + 1;
        grid(i, j) = grid(i, j) + pu(r);
        cnt(i, j)  = cnt(i, j) + 1;
    end
    grid = grid ./ max(cnt, 1);

    f = figure('Visible', 'off', 'Position', [100 100 800 360]);
    imagesc(0:23, 0:6, grid);
    colorbar;
    xlabel('hour of day'); ylabel('weekday (0=Mon)');
    set(gca, 'YDir', 'normal');
    title('Mean pickup per zone-hour (training period)');

    out = fullfile(cfg.figures_dir, 'fig_demand_pattern.png');
    print(f, out, '-dpng', '-r150');
    close(f);
    fprintf('  → %s\n', out);
end


function plot_supply_demand_gap(dispatch_log, data, cfg)
    % choose the hour with the largest total deficit
    [~, idx] = max(arrayfun(@(d) sum(d.D), dispatch_log));
    dl = dispatch_log(idx);
    K = numel(dl.D);

    B = dl.Q_current - dl.P_true_next;   % > 0 surplus, < 0 deficit
    [~, order] = sort(B, 'ascend');
    B_sorted = B(order);

    f = figure('Visible', 'off', 'Position', [100 100 1000 360]);
    bar(1:K, B_sorted);
    grid on;
    xlabel('zone rank (most-deficit → most-surplus)');
    ylabel('Q\_current - P\_true\_next');
    title(sprintf('Supply–demand gap at hour\\_index = %d', dl.hour_index));

    out = fullfile(cfg.figures_dir, 'fig_supply_demand_gap.png');
    print(f, out, '-dpng', '-r150');
    close(f);
    fprintf('  → %s\n', out);
end


function plot_dispatch_comparison(dispatch_log, cfg)
    H = numel(dispatch_log);
    unmet = zeros(H, 3);
    cost  = zeros(H, 3);
    for h = 1:H
        unmet(h, :) = [dispatch_log(h).ev_no.total_unmet, ...
                       dispatch_log(h).ev_greedy.total_unmet, ...
                       dispatch_log(h).ev_lp.total_unmet];
        cost(h, :)  = [0, dispatch_log(h).ev_greedy.empty_cost, ...
                          dispatch_log(h).ev_lp.empty_cost];
    end

    f = figure('Visible', 'off', 'Position', [100 100 900 700]);
    subplot(2, 1, 1);
    bar(unmet, 'grouped');
    legend({'no rebalance', 'greedy', 'LP'}, 'Location', 'northwest');
    grid on; xlabel('test hour'); ylabel('total real unmet demand');
    title('Unmet demand by policy across test hours');

    subplot(2, 1, 2);
    bar(cost, 'grouped');
    legend({'no rebalance', 'greedy', 'LP'}, 'Location', 'northwest');
    grid on; xlabel('test hour'); ylabel('empty distance cost (miles)');
    title('Empty distance cost by policy');

    out = fullfile(cfg.figures_dir, 'fig_dispatch_comparison.png');
    print(f, out, '-dpng', '-r150');
    close(f);
    fprintf('  → %s\n', out);
end


function plot_top_flows(dispatch_log, data, cfg)
    % aggregate X_lp across all test hours, then take top-10 flows
    K = size(dispatch_log(1).X_lp, 1);
    X_agg = zeros(K, K);
    for h = 1:numel(dispatch_log)
        X_agg = X_agg + dispatch_log(h).X_lp;
    end
    flows = [];
    for i = 1:K
        for j = 1:K
            if i ~= j && X_agg(i, j) > 0
                flows = [flows; i, j, X_agg(i, j)]; %#ok<AGROW>
            end
        end
    end
    if isempty(flows)
        f = figure('Visible', 'off', 'Position', [100 100 600 360]);
        text(0.3, 0.5, 'no LP flows recorded');
        axis off;
        out = fullfile(cfg.figures_dir, 'fig_top_flows.png');
        print(f, out, '-dpng', '-r150');
        close(f);
        fprintf('  → %s (empty)\n', out);
        return;
    end
    flows = sortrows(flows, -3);
    n = min(10, size(flows, 1));
    top = flows(1:n, :);

    labels = cell(n, 1);
    for k = 1:n
        i = top(k, 1); j = top(k, 2);
        labels{k} = sprintf('%s → %s', short_label(data, i), short_label(data, j));
    end

    f = figure('Visible', 'off', 'Position', [100 100 900 480]);
    barh(top(:, 3));
    set(gca, 'YTick', 1:n, 'YTickLabel', labels, 'YDir', 'reverse');
    xlabel('Total dispatched units (sum over test hours)');
    title('Top-10 LP rebalancing flows');
    grid on;

    out = fullfile(cfg.figures_dir, 'fig_top_flows.png');
    print(f, out, '-dpng', '-r150');
    close(f);
    fprintf('  → %s\n', out);
end


function s = short_label(data, k)
    if isfield(data, 'zone_meta') && isfield(data.zone_meta, 'zone_name') ...
            && numel(data.zone_meta.zone_name) >= k
        nm = data.zone_meta.zone_name{k};
        if numel(nm) > 16; nm = [nm(1:14), '..']; end
        s = nm;
    else
        s = sprintf('zone_%d', double(data.top_zones(k)));
    end
end


function plot_mc_boxplot(mc_last, cfg)
    if isempty(mc_last) || ~isfield(mc_last, 'unmet')
        return;
    end

    f = figure('Visible', 'off', 'Position', [100 100 900 380]);
    subplot(1, 2, 1);
    simple_box(mc_last.unmet, {'no', 'greedy', 'LP'});
    title('Unmet demand distribution (Monte Carlo)');
    ylabel('total real unmet demand');
    grid on;

    subplot(1, 2, 2);
    simple_box(mc_last.service, {'no', 'greedy', 'LP'});
    title('Service rate distribution');
    ylabel('service rate');
    grid on;

    out = fullfile(cfg.figures_dir, 'fig_monte_carlo_boxplot.png');
    print(f, out, '-dpng', '-r150');
    close(f);
    fprintf('  → %s\n', out);
end


function simple_box(M, labels)
% Box-plot stand-in without Statistics Toolbox: median + IQR box + min/max whisker.
    n_cols = size(M, 2);
    hold on;
    for c = 1:n_cols
        v = sort(M(:, c));
        q1 = v(max(1, floor(numel(v) * 0.25)));
        med = v(max(1, floor(numel(v) * 0.5)));
        q3 = v(max(1, floor(numel(v) * 0.75)));
        lo = min(v); hi = max(v);
        w = 0.3;
        rectangle('Position', [c - w/2, q1, w, q3 - q1], 'EdgeColor', 'k');
        plot([c - w/2, c + w/2], [med, med], 'k-', 'LineWidth', 2);
        plot([c, c], [lo, q1], 'k-');
        plot([c, c], [q3, hi], 'k-');
        plot([c - w/4, c + w/4], [lo, lo], 'k-');
        plot([c - w/4, c + w/4], [hi, hi], 'k-');
    end
    set(gca, 'XTick', 1:n_cols, 'XTickLabel', labels);
    xlim([0.5, n_cols + 0.5]);
end
