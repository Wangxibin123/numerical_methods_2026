function data = load_processed_data(cfg)
% LOAD_PROCESSED_DATA  Read processed CSVs into a single struct.
%
% Returns:
%   data.panel        struct of column-arrays for all panel columns
%   data.col_names    cell array of column names (in panel order)
%   data.top_zones    K x 1 zone ids
%   data.cost_matrix  K x K cost (miles)
%   data.zone_meta    struct with .zone_id .zone_name .borough (cellstrs)
%   data.test_hours   M x 1 hour_index values to simulate dispatch on
%
% Uses readtable when available; falls back to csvread with no-header file.

    if ~exist(cfg.panel_cols_txt, 'file')
        error('missing panel_columns.txt; run python preprocessing first');
    end
    col_names = read_lines(cfg.panel_cols_txt);
    data.col_names = col_names;

    % ---------- panel ----------
    panel_mat = try_read_panel(cfg);
    if size(panel_mat, 2) ~= numel(col_names)
        error('panel column count mismatch: file has %d, columns.txt %d', ...
              size(panel_mat, 2), numel(col_names));
    end
    panel = struct();
    for k = 1:numel(col_names)
        panel.(col_names{k}) = panel_mat(:, k);
    end
    data.panel = panel;

    % ---------- top zones ----------
    tz = try_csvread_skip_header(cfg.top_zones_csv);
    data.top_zones = int32(tz(:, 1));

    % ---------- cost matrix ----------
    if ~exist(cfg.cost_matrix_csv, 'file')
        error('missing cost matrix: %s', cfg.cost_matrix_csv);
    end
    data.cost_matrix = csvread(cfg.cost_matrix_csv);
    K = numel(data.top_zones);
    if any(size(data.cost_matrix) ~= [K, K])
        error('cost matrix shape %dx%d, expected %dx%d', ...
              size(data.cost_matrix, 1), size(data.cost_matrix, 2), K, K);
    end

    % ---------- zone meta ----------
    data.zone_meta = read_zone_meta(cfg.zone_meta_csv, data.top_zones);

    % ---------- test hours ----------
    th = try_csvread_skip_header(cfg.test_hours_csv);
    % file has columns hour_iso, hour_index → hour_index is column 2 (or 1 if iso dropped)
    if size(th, 2) >= 2
        data.test_hours = int64(th(:, end));   % last column is hour_index
    else
        data.test_hours = int64(th(:, 1));
    end

    fprintf('[load] panel rows=%d cols=%d  K=%d  test_hours=%d\n', ...
            size(panel_mat, 1), size(panel_mat, 2), K, numel(data.test_hours));
end


function panel_mat = try_read_panel(cfg)
% Prefer csvread on the noheader file (works everywhere); fall back to readtable.
    if exist(cfg.panel_csv_noheader, 'file')
        panel_mat = csvread(cfg.panel_csv_noheader);
        return;
    end
    if exist(cfg.panel_csv, 'file')
        try
            T = readtable(cfg.panel_csv);
            panel_mat = table2array(T);
            return;
        catch
            % manual parse: skip first line, read rest
            panel_mat = csvread(cfg.panel_csv, 1, 0);
            return;
        end
    end
    error('no panel csv found in %s', cfg.processed_dir);
end


function lines = read_lines(path)
    fid = fopen(path, 'r');
    if fid < 0
        error('cannot open %s', path);
    end
    cleanup = onCleanup(@() fclose(fid));
    lines = {};
    while true
        ln = fgetl(fid);
        if ~ischar(ln); break; end
        ln = strtrim(ln);
        if isempty(ln); continue; end
        lines{end+1, 1} = ln; %#ok<AGROW>
    end
end


function M = try_csvread_skip_header(path)
% Read CSV that may have header line. csvread refuses non-numeric, so we
% first try plain csvread, then csvread skipping line 0.
    try
        M = csvread(path);
        return;
    catch
        try
            M = csvread(path, 1, 0);
            return;
        catch
            % fall back to readtable
            T = readtable(path);
            M = [];
            for c = 1:width(T)
                col = T{:, c};
                if iscell(col)
                    % try to parse iso strings — keep NaN if not numeric
                    n = numel(col);
                    nums = nan(n, 1);
                    for ii = 1:n
                        v = str2double(col{ii});
                        if ~isnan(v); nums(ii) = v; end
                    end
                    M = [M, nums]; %#ok<AGROW>
                else
                    M = [M, double(col)]; %#ok<AGROW>
                end
            end
        end
    end
end


function meta = read_zone_meta(path, top_zones)
    meta.zone_id   = top_zones;
    meta.zone_name = cell(numel(top_zones), 1);
    meta.borough   = cell(numel(top_zones), 1);
    if ~exist(path, 'file')
        for k = 1:numel(top_zones)
            meta.zone_name{k} = sprintf('Zone_%d', top_zones(k));
            meta.borough{k}   = 'Unknown';
        end
        return;
    end
    try
        T = readtable(path);
    catch
        % stub fallback
        for k = 1:numel(top_zones)
            meta.zone_name{k} = sprintf('Zone_%d', top_zones(k));
            meta.borough{k}   = 'Unknown';
        end
        return;
    end
    has_id   = ismember('zone_id',   T.Properties.VariableNames);
    has_name = ismember('zone_name', T.Properties.VariableNames);
    has_bor  = ismember('borough',   T.Properties.VariableNames);
    if ~has_id
        return;
    end
    ids = double(T.zone_id);
    for k = 1:numel(top_zones)
        idx = find(ids == double(top_zones(k)), 1, 'first');
        if isempty(idx)
            meta.zone_name{k} = sprintf('Zone_%d', top_zones(k));
            meta.borough{k}   = 'Unknown';
        else
            if has_name
                v = T.zone_name(idx);
                if iscell(v); meta.zone_name{k} = v{1}; else; meta.zone_name{k} = char(v); end
            else
                meta.zone_name{k} = sprintf('Zone_%d', top_zones(k));
            end
            if has_bor
                v = T.borough(idx);
                if iscell(v); meta.borough{k} = v{1}; else; meta.borough{k} = char(v); end
            else
                meta.borough{k} = 'Unknown';
            end
        end
    end
end
