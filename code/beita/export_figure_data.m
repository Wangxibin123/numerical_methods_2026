function export_figure_data(data, dispatch_log, mc_last, cfg)
% EXPORT_FIGURE_DATA  Persist the data backing the 5 required figures so a
% Python helper (07_render_figures.py) can rasterise them.
%
% Baltamatica community edition lacks figure/plot/print, so we keep ALL
% computation in 北太天元 and delegate only the pixel-pushing to Python
% matplotlib.
%
% Writes (under cfg.tables_dir):
%   fig_data_demand_pattern.csv      24 cols (hour 0..23) x 7 rows (weekday 0..6)
%   fig_data_supply_demand_gap.csv   K rows; cols: zone_id, zone_name, Q, P_true, gap
%   fig_data_dispatch_comparison.csv H rows; per test hour: unmet_no, unmet_g, unmet_l,
%                                    cost_no, cost_g, cost_l
%   fig_data_top_flows.csv           Top-N rows of aggregated LP flows
%   fig_data_monte_carlo.csv         M rows x 6 (unmet/service for each of 3 policies)

    if ~exist(cfg.tables_dir, 'dir'); mkdir(cfg.tables_dir); end

    write_demand_pattern(data, cfg);
    write_supply_demand_gap(dispatch_log, data, cfg);
    write_dispatch_comparison(dispatch_log, cfg);
    write_top_flows(dispatch_log, data, cfg);
    if ~isempty(mc_last) && isfield(mc_last, 'unmet')
        write_monte_carlo(mc_last, cfg);
    end
end


function write_demand_pattern(data, cfg)
    p = data.panel;
    hod = double(p.hour_of_day);
    wd  = double(p.weekday);
    pu  = double(p.pickup_count);
    mask = (p.split_id == 0);

    sum_g = zeros(7, 24);
    cnt_g = zeros(7, 24);
    for r = 1:numel(hod)
        if ~mask(r); continue; end
        i = wd(r) + 1;
        j = hod(r) + 1;
        sum_g(i, j) = sum_g(i, j) + pu(r);
        cnt_g(i, j) = cnt_g(i, j) + 1;
    end
    mean_g = sum_g ./ max(cnt_g, 1);

    out = fullfile(cfg.tables_dir, 'fig_data_demand_pattern.csv');
    fid = fopen(out, 'w');
    % header: weekday,h00,h01,...,h23
    fprintf(fid, 'weekday');
    for j = 0:23
        fprintf(fid, ',h%02d', j);
    end
    fprintf(fid, '\n');
    for i = 1:7
        fprintf(fid, '%d', i - 1);
        for j = 1:24
            fprintf(fid, ',%.6f', mean_g(i, j));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
    fprintf('  written %s\n', out);
end


function write_supply_demand_gap(dispatch_log, data, cfg)
    % pick hour with largest predicted total deficit
    [~, idx] = max(arrayfun(@(d) sum(d.D), dispatch_log));
    dl = dispatch_log(idx);
    K = numel(dl.D);

    out = fullfile(cfg.tables_dir, 'fig_data_supply_demand_gap.csv');
    fid = fopen(out, 'w');
    fprintf(fid, 'hour_index,zone_pos,zone_id,zone_name,borough,Q_current,P_true_next,gap\n');
    for k = 1:K
        nm = '';
        br = '';
        if isfield(data, 'zone_meta') && isfield(data.zone_meta, 'zone_name') ...
                && numel(data.zone_meta.zone_name) >= k
            nm = data.zone_meta.zone_name{k};
        end
        if isfield(data, 'zone_meta') && isfield(data.zone_meta, 'borough') ...
                && numel(data.zone_meta.borough) >= k
            br = data.zone_meta.borough{k};
        end
        % strip commas from labels to keep csv clean
        nm = strrep(nm, ',', ' ');
        br = strrep(br, ',', ' ');
        gap = dl.Q_current(k) - dl.P_true_next(k);
        fprintf(fid, '%d,%d,%d,%s,%s,%.6f,%.6f,%.6f\n', ...
            dl.hour_index, k, double(data.top_zones(k)), nm, br, ...
            dl.Q_current(k), dl.P_true_next(k), gap);
    end
    fclose(fid);
    fprintf('  written %s\n', out);
end


function write_dispatch_comparison(dispatch_log, cfg)
    H = numel(dispatch_log);
    out = fullfile(cfg.tables_dir, 'fig_data_dispatch_comparison.csv');
    fid = fopen(out, 'w');
    fprintf(fid, ['test_hour_pos,hour_index,' ...
                  'unmet_no,unmet_greedy,unmet_lp,' ...
                  'cost_no,cost_greedy,cost_lp,' ...
                  'srv_no,srv_greedy,srv_lp\n']);
    for h = 1:H
        ev0 = dispatch_log(h).ev_no;
        evg = dispatch_log(h).ev_greedy;
        evl = dispatch_log(h).ev_lp;
        fprintf(fid, '%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
            h, dispatch_log(h).hour_index, ...
            ev0.total_unmet, evg.total_unmet, evl.total_unmet, ...
            0.0, evg.empty_cost, evl.empty_cost, ...
            ev0.service_rate, evg.service_rate, evl.service_rate);
    end
    fclose(fid);
    fprintf('  written %s\n', out);
end


function write_top_flows(dispatch_log, data, cfg)
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
        flows = zeros(0, 3);
    else
        flows = sortrows(flows, -3);
    end

    n = min(20, size(flows, 1));
    out = fullfile(cfg.tables_dir, 'fig_data_top_flows.csv');
    fid = fopen(out, 'w');
    fprintf(fid, 'rank,src_pos,dst_pos,src_zone_id,dst_zone_id,src_name,dst_name,total_units\n');
    for r = 1:n
        i = flows(r, 1); j = flows(r, 2); v = flows(r, 3);
        zi = double(data.top_zones(i)); zj = double(data.top_zones(j));
        ni = ''; nj = '';
        if isfield(data, 'zone_meta') && isfield(data.zone_meta, 'zone_name')
            if numel(data.zone_meta.zone_name) >= i
                ni = strrep(data.zone_meta.zone_name{i}, ',', ' ');
            end
            if numel(data.zone_meta.zone_name) >= j
                nj = strrep(data.zone_meta.zone_name{j}, ',', ' ');
            end
        end
        fprintf(fid, '%d,%d,%d,%d,%d,%s,%s,%.6f\n', r, i, j, zi, zj, ni, nj, v);
    end
    fclose(fid);
    fprintf('  written %s\n', out);
end


function write_monte_carlo(mc, cfg)
    M = size(mc.unmet, 1);
    out = fullfile(cfg.tables_dir, 'fig_data_monte_carlo.csv');
    fid = fopen(out, 'w');
    fprintf(fid, ['scenario,' ...
                  'unmet_no,unmet_greedy,unmet_lp,' ...
                  'srv_no,srv_greedy,srv_lp\n']);
    for m = 1:M
        fprintf(fid, '%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', m, ...
            mc.unmet(m, 1), mc.unmet(m, 2), mc.unmet(m, 3), ...
            mc.service(m, 1), mc.service(m, 2), mc.service(m, 3));
    end
    fclose(fid);
    fprintf('  written %s\n', out);
end
