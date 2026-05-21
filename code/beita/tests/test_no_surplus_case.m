% TEST_NO_SURPLUS_CASE  S = [0; 0]  → LP should output X = 0, u = D.
clear; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));

S = [0; 0];
D = [5; 3];
C = [0 2;
     2 0];
lambda = 5;

result = solve_rebalance_lp(S, D, C, lambda);

assert(result.feasible, 'LP should be feasible');
EPS = 1e-6;
assert(all(abs(result.X(:)) < EPS), 'expected X all zeros');

% u must equal D exactly (no dispatch possible)
assert(abs(result.u_pred(1) - D(1)) < EPS, 'expected u_1 = D_1');
assert(abs(result.u_pred(2) - D(2)) < EPS, 'expected u_2 = D_2');
assert(abs(result.empty_cost) < EPS, 'expected zero empty cost');

% objective = lambda * sum(D)
expected_obj = lambda * sum(D);
assert(abs(result.objective - expected_obj) < 1e-4, ...
       sprintf('expected objective = %.4f, got %.4f', expected_obj, result.objective));

fprintf('test_no_surplus_case PASSED\n');
