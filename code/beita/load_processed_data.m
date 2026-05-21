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
% Uses fopen + sscanf for numeric panels (Baltamatica csvread is unreliable on
% delimited matrices; readtable works but is too slow for 100k-row panels).

    if ~exist(cfg.panel_cols_txt, 'file')
        error('missing panel_columns.txt; run python preprocessing first');
    end
    col_names = read_lines(cfg.panel_cols_txt);
    data.col_names = col_names;
    n_cols = numel(col_names);

    % ---------- panel ----------
    panel_mat = read_numeric_csv(cfg.panel_csv_noheader, n_cols);
    if size(panel_mat, 2) ~= n_cols
        error(sprintf('panel column count mismatch: file has %d, columns.txt %d', ...
              size(panel_mat, 2), n_cols));
    end
    panel = struct();
    for k = 1:n_cols
        panel.(col_names{k}) = panel_mat(:, k);
    end
    data.panel = panel;

    % ---------- top zones (skip 1-line header) ----------
    tz_mat = read_numeric_csv(cfg.top_zones_csv, 1, 1);
    data.top_zones = int32(tz_mat(:, 1));
    K = numel(data.top_zones);

    % ---------- cost matrix (no header, K x K) ----------
    if ~exist(cfg.cost_matrix_csv, 'file')
        error(sprintf('missing cost matrix: %s', cfg.cost_matrix_csv));
    end
    data.cost_matrix = read_numeric_csv(cfg.cost_matrix_csv, K);
    if any(size(data.cost_matrix) ~= [K, K])
        error(sprintf('cost matrix shape %dx%d, expected %dx%d', ...
              size(data.cost_matrix, 1), size(data.cost_matrix, 2), K, K));
    end

    % ---------- zone meta (has text columns; use readtable) ----------
    data.zone_meta = read_zone_meta(cfg.zone_meta_csv, data.top_zones);

    % ---------- test hours (skip 1-line header; last col is hour_index) ----------
    th_mat = read_test_hours(cfg.test_hours_csv);
    data.test_hours = int64(th_mat(:, end));

    fprintf('[load] panel rows=%d cols=%d  K=%d  test_hours=%d\n', ...
            size(panel_mat, 1), size(panel_mat, 2), K, numel(data.test_hours));
end


function lines = read_lines(path)
    fid = fopen(path, 'r');
    if fid < 0
        error(sprintf('cannot open %s', path));
    end
    lines = {};
    try
        while true
            ln = fgetl(fid);
            if ~ischar(ln); break; end
            ln = strtrim(ln);
            if isempty(ln); continue; end
            lines{end+1, 1} = ln; %#ok<AGROW>
        end
        fclose(fid);
    catch err
        fclose(fid);
        rethrow(err);
    end
end


function M = read_numeric_csv(path, n_cols, skip_lines)
% Fast generic CSV reader: fopen → fread → sscanf.
% Works for noheader files; pass skip_lines=1 to skip a header line.
    if nargin < 3
        skip_lines = 0;
    end
    if ~exist(path, 'file')
        error(sprintf('missing %s', path));
    end
    fid = fopen(path, 'r');
    if fid < 0
        error(sprintf('cannot open %s', path));
    end
    % skip header lines if requested
    for i = 1:skip_lines
        fgetl(fid);
    end
    % slurp rest as char
    buf = fread(fid, '*char')';
    fclose(fid);
    % replace commas with spaces so sscanf treats them as whitespace
    buf = strrep(buf, ',', ' ');
    nums = sscanf(buf, '%f');
    if isempty(nums)
        M = zeros(0, n_cols);
        return;
    end
    n_total = numel(nums);
    if mod(n_total, n_cols) ~= 0
        error(sprintf('parse error: %d numbers cannot reshape to N x %d', ...
            n_total, n_cols));
    end
    M = reshape(nums, n_cols, [])';
end


function th = read_test_hours(path)
% test_hours.csv has columns: hour_iso, hour_index
% hour_iso is a string with no commas inside. We use a custom parse that
% takes only the LAST comma-separated field per line as numeric.
    fid = fopen(path, 'r');
    if fid < 0
        error(sprintf('cannot open %s', path));
    end
    rows = {};
    try
        % skip header
        hdr = fgetl(fid); %#ok<NASGU>
        while true
            ln = fgetl(fid);
            if ~ischar(ln); break; end
            ln = strtrim(ln);
            if isempty(ln); continue; end
            ix = strfind(ln, ',');
            if isempty(ix)
                v = str2double(ln);
            else
                v = str2double(ln(ix(end)+1:end));
            end
            if ~isnan(v)
                rows{end+1, 1} = v; %#ok<AGROW>
            end
        end
        fclose(fid);
    catch err
        fclose(fid);
        rethrow(err);
    end
    th = zeros(numel(rows), 1);
    for k = 1:numel(rows)
        th(k) = rows{k};
    end
end


function meta = read_zone_meta(path, top_zones)
    meta.zone_id   = top_zones;
    meta.zone_name = cell(numel(top_zones), 1);
    meta.borough   = cell(numel(top_zones), 1);
    for k = 1:numel(top_zones)
        meta.zone_name{k} = sprintf('Zone_%d', top_zones(k));
        meta.borough{k}   = 'Unknown';
    end
    if ~exist(path, 'file')
        return;
    end

    % zone_meta.csv has columns: zone_id, zone_name, borough — strings inside
    % Parse manually so we don't depend on readtable's text handling.
    fid = fopen(path, 'r');
    if fid < 0
        return;
    end
    try
        hdr = fgetl(fid); %#ok<NASGU>
        while true
            ln = fgetl(fid);
            if ~ischar(ln); break; end
            ln = strtrim(ln);
            if isempty(ln); continue; end
            parts = split_csv_line(ln);
            if numel(parts) < 1; continue; end
            zid = str2double(parts{1});
            if isnan(zid); continue; end
            idx = find(double(top_zones) == zid, 1, 'first');
            if isempty(idx); continue; end
            if numel(parts) >= 2; meta.zone_name{idx} = parts{2}; end
            if numel(parts) >= 3; meta.borough{idx}   = parts{3}; end
        end
        fclose(fid);
    catch err
        fclose(fid);
        rethrow(err);
    end
end


function parts = split_csv_line(ln)
% naive comma split — our CSV writer ensures no commas inside text fields
    parts = {};
    rest = ln;
    while true
        ix = strfind(rest, ',');
        if isempty(ix)
            parts{end+1} = rest; %#ok<AGROW>
            break;
        end
        parts{end+1} = rest(1:ix(1)-1); %#ok<AGROW>
        rest = rest(ix(1)+1:end);
    end
end
