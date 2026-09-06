function operator = solve_regularized_inverse(responseEstimate, constraints)
    % SOLVE_REGULARIZED_INVERSE 求二维频率平坦响应的受限正则逆。

    arguments
        responseEstimate (2, 2) double
        constraints (1, 1) struct
    end

    if ~isfield(constraints, 'lambda') || ~isfield(constraints, 'max_gain')
        error('rtsim:calibration:MissingField', ...
            'constraints必须包含lambda和max_gain。');
    end

    lambda = constraints.lambda;
    maxGain = constraints.max_gain;
    validateattributes(lambda, {'numeric'}, {'scalar', 'real', 'nonnegative', 'finite'});
    validateattributes(maxGain, {'numeric'}, {'scalar', 'real', 'positive', 'nonnan'});

    matrix = responseEstimate' / ...
        (responseEstimate * responseEstimate' + lambda * eye(2));
    unclippedGain = norm(matrix, 2);
    clipped = unclippedGain > maxGain;
    if clipped
        matrix = matrix .* (maxGain / unclippedGain);
    end

    operator.matrix = matrix;
    operator.lambda = lambda;
    operator.max_gain = maxGain;
    operator.unclipped_gain = unclippedGain;
    operator.gain_limited = clipped;
    operator.residual = norm(matrix * responseEstimate - eye(2), 'fro');
    operator.model_scope = "frequency-flat matrix inverse";
end
