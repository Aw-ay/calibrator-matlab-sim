function [y, state, diag] = apply_mimo_fir(x, state, coeff)
    % 因果MIMO FIR：coeff(tap,输出极化,输入极化)，零状态初始输入为[]。

    validateattributes(x, {'numeric'}, {'2d', 'ncols', 2, 'finite'});
    if size(coeff, 2) ~= 2 || size(coeff, 3) ~= 2 || isempty(coeff) || any(~isfinite(coeff), 'all')
        error('rtsim:calibration:FirShape', '系数必须为有限Nx2x2数组。');
    end

    n = size(coeff, 1);
    if isempty(state)
        state = struct('history', zeros(n - 1, 2));
    end

    if ~isequal(size(state.history), [n - 1, 2])
        error('rtsim:calibration:FirStateMismatch', 'FIR历史长度或通道数不匹配。');
    end

    data = [state.history; x];
    y = complex(zeros(size(x)));
    for o = 1:2
        for i = 1:2
            z = filter(coeff(:, o, i), 1, data(:, i));
            y(:, o) = y(:, o) + z(n:end);
        end
    end

    state.history = data(end - n + 2:end, :);
    diag = struct('tap_count', n, 'causal', true, 'qualification', 'FLOATING_REFERENCE');
end
