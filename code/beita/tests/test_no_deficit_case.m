% TEST_NO_DEFICIT_CASE  D = [0; 0]  → LP should output X = 0, u = 0.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));

S = [4; 6];
D = [0; 0];
C = [0  1.5;
     1.7 0];
lambda = 5;

result = solve_rebalance_lp(S, D, C, lambda);

assert(result.feasible, 'LP should be feasible');
EPS = 1e-6;
assert(all(abs(result.X(:)) < EPS), 'expected X all zeros');
assert(all(abs(result.u_pred) < EPS), 'expected u all zeros');
assert(abs(result.empty_cost) < EPS, 'expected zero empty cost');

fprintf('test_no_deficit_case PASSED\n');
