function result = array_calibration_solver(design, measurement, regularization)
    % 只接收独立可知激励A和复测量Y，拟合Y=A*g；禁止传入plant真值。

    if nargin < 3
        regularization = 0;
    end

    validateattributes(regularization, {'numeric'}, {'scalar', 'nonnegative', 'finite'});
    if size(design, 1) ~= size(measurement, 1) || any(~isfinite(design(:))) || ...
            any(~isfinite(measurement(:)))
        error('rtsim:array:Measurement', '测量与设计矩阵行数必须一致且有限。');
    end

    n = size(design, 2);
    if rank(design) < n
        error('rtsim:array:Unidentifiable', '测量不能辨识全部通道，需要独立方向或正交激励。');
    end

    result.channel_response = [design; sqrt(regularization) * eye(n)] \ ...
        [measurement; zeros(n, size(measurement, 2))];
    result.residual = measurement - design * result.channel_response;
    result.relative_residual = norm(result.residual, 'fro') / max(norm(measurement, 'fro'), realmin);
    result.condition_number = cond(design);
    result.regularization = regularization;
    result.qualification = 'FIT_TO_SUPPLIED_COMPLEX_MEASUREMENTS';
end
