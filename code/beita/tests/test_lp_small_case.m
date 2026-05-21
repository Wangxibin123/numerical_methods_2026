% TEST_LP_SMALL_CASE  Hand-verifiable 2x2 LP.
%
%   S = [10; 5]
%   D = [8; 7]
%   C = [1 10;
%        2  1]
%
% Optimal LP should:
%   - send 8 from zone 1 → zone 1's deficit at cost 1   (well, 1->1 wait — i=j cost is 1? let me re-read)
%
% Actually with C(i,j) the cost of dispatching from i to j and diagonal not zero
% here, the optimum is:
%   x_11 = 8 (cost 8)   serves D_1 = 8 from zone 1 (cheap)
%   x_22 = 5 (cost 5)   serves part of D_2 from zone 2 cheaper than 1→2
%   u_2  = 2            still 2 unmet demand at zone 2
% Total cost = 8 + 5 + lambda*2.
%
% With lambda large, LP prefers to fill all D_2 from zone 1 (cost 10 each)
% rather than leave unmet — but zone 1 still has only 10 - 8 = 2 capacity left,
% so x_12 = 2, u_2 = 0, extra cost = 20.
%
% We test the LARGE-LAMBDA case (lambda = 1000): LP should use all surplus.

clear; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));

S = [10; 5];
D = [8; 7];
C = [1 10;
     2  1];
lambda = 1000;

result = solve_rebalance_lp(S, D, C, lambda);

assert(result.feasible, 'LP should be feasible');
assert(all(size(result.X) == [2, 2]), 'X must be 2x2');

X = result.X;
fprintf('X =\n'); disp(X);
fprintf('u_pred = '); disp(result.u_pred(:)');
fprintf('objective = %.4f\n', result.objective);
fprintf('empty cost = %.4f\n', result.empty_cost);

% supply not exceeded
assert(sum(X(1, :)) <= S(1) + 1e-6, 'supply 1 exceeded');
assert(sum(X(2, :)) <= S(2) + 1e-6, 'supply 2 exceeded');

% with lambda large enough, total dispatch + u should cover D
covered = sum(X, 1)' + result.u_pred;
assert(all(covered >= D - 1e-6), 'D not covered (with slack)');

% with lambda=1000, prefer routing low-cost paths:
%   X(1,1) ≈ 8  uses cheapest entry
%   X(2,2) ≈ 5
%   X(1,2) ≈ 2 (zone 1's remaining 2 → zone 2)
%   u_2    ≈ 0
EPS = 1e-3;
assert(abs(X(1, 1) - 8) < EPS, sprintf('expected X(1,1)≈8, got %.4f', X(1, 1)));
assert(abs(X(2, 2) - 5) < EPS, sprintf('expected X(2,2)≈5, got %.4f', X(2, 2)));
assert(abs(X(1, 2) - 2) < EPS, sprintf('expected X(1,2)≈2, got %.4f', X(1, 2)));
assert(abs(result.u_pred(2)) < EPS, sprintf('expected u_2≈0, got %.4f', result.u_pred(2)));

fprintf('test_lp_small_case PASSED\n');
