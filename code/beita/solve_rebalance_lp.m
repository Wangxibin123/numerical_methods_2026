function result = solve_rebalance_lp(S, D, C, lambda_unmet)
% SOLVE_REBALANCE_LP  Solve the empty-vehicle rebalancing LP via linprog.
%
%   min  sum_{i,j} c_{ij} x_{ij} + lambda * sum_j u_j
%   s.t. sum_j x_{ij}        <=  S_i           for all i
%        sum_i x_{ij} + u_j  >=  D_j           for all j
%        x_{ij} >= 0,  u_j >= 0
%
% Variable ordering (column-major):
%   [ x_11; x_21; ...; x_K1;        % column 1 of X (all rows for dest 1)
%     x_12; x_22; ...; x_K2;        % column 2 of X
%     ...
%     x_1K; x_2K; ...; x_KK;        % column K of X
%     u_1; u_2; ...; u_K ]
%
% I.e. if we reshape the first K*K entries with reshape(., K, K), the (i,j)
% entry equals x_{ij}. This matches C(:) when C is given as K x K row=src col=dst.
%
% Outputs:
%   result.X           K x K dispatch matrix (rounded? no — keep continuous)
%   result.u_pred      K x 1 unmet predicted demand
%   result.objective   scalar LP objective at optimum
%   result.exitflag    linprog exit flag
%   result.empty_cost  sum(C .* X) — empty distance cost only
%   result.feasible    logical

    S = S(:); D = D(:);
    K = numel(S);
    if numel(D) ~= K
        error('S and D must be same length');
    end
    if any(size(C) ~= [K, K])
        error('cost matrix must be %dx%d', K, K);
    end

    nx = K * K;            % x_ij entries
    nu = K;                % u_j entries
    nvar = nx + nu;

    % --------- objective f' * z ---------
    f = [C(:); lambda_unmet * ones(nu, 1)];

    % --------- inequality A z <= b ---------
    % supply: sum_j x_ij <= S_i  → for each row i, K x_ij's are summed
    % demand: sum_i x_ij + u_j >= D_j  →  -sum_i x_ij - u_j <= -D_j
    A = zeros(2 * K, nvar);
    b = zeros(2 * K, 1);

    % supply constraints
    for i = 1:K
        for j = 1:K
            % x_{ij} sits at position (j-1)*K + i  (column-major X)
            pos = (j - 1) * K + i;
            A(i, pos) = 1;
        end
        b(i) = S(i);
    end

    % demand constraints (negated)
    for j = 1:K
        for i = 1:K
            pos = (j - 1) * K + i;
            A(K + j, pos) = -1;
        end
        A(K + j, nx + j) = -1;
        b(K + j) = -D(j);
    end

    lb = zeros(nvar, 1);
    ub = [];

    opts = build_linprog_opts();

    [z, fval, exitflag, ~] = linprog(f, A, b, [], [], lb, ub, opts);

    result.exitflag = exitflag;
    result.feasible = (exitflag == 1) && ~isempty(z);

    if ~result.feasible
        warning('linprog did not return optimal solution (exitflag = %d)', exitflag);
        if isempty(z)
            z = zeros(nvar, 1);
            fval = NaN;
        end
    end

    x = z(1:nx);
    u = z(nx+1:end);
    X = reshape(x, K, K);

    result.X = X;
    result.u_pred = u;
    result.objective = fval;
    result.empty_cost = sum(sum(C .* X));
end


function opts = build_linprog_opts()
    try
        opts = optimoptions('linprog', 'Display', 'off');
    catch
        try
            opts = optimset('Display', 'off');
        catch
            opts = [];
        end
    end
end
