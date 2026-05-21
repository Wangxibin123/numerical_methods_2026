% RUN_ALL_TESTS  Run every test_*.m in this directory.
clear; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));

tests = {
    'test_lp_small_case'
    'test_no_deficit_case'
    'test_no_surplus_case'
};

passed = 0;
failed = 0;
for k = 1:numel(tests)
    name = tests{k};
    fprintf('\n--- %s ---\n', name);
    try
        run(fullfile(here, [name '.m']));
        passed = passed + 1;
    catch err
        failed = failed + 1;
        fprintf('FAIL: %s\n', err.message);
    end
end

fprintf('\n=========================\n');
fprintf('passed %d / %d\n', passed, passed + failed);
if failed > 0
    error('%d test(s) failed', failed);
end
