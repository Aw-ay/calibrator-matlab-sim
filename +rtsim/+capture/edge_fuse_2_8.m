function edges = edge_fuse_2_8(selectedIQ, window, edgeCfg)
    % EDGE_FUSE_2_8 融合2点阈值插值和8点局部拟合的上升沿。

    power = max(0, sum(abs(selectedIQ).^2, 2) - field_or(edgeCfg, 'noise_power', 0));
    first = max(1, window(1));
    last = min(numel(power), window(2));
    p = power(first:last);
    definition = upper(string(edgeCfg.level_definition));
    peak = max(p);
    if definition == "HALF_POWER"
        threshold = 0.5 * peak;
    elseif definition == "HALF_AMPLITUDE"
        threshold = 0.25 * peak;
    else
        error('rtsim:capture:EdgeLevel', '仅支持HALF_POWER或HALF_AMPLITUDE。');
    end

    crossing = find(p(1:end - 1) < threshold & p(2:end) >= threshold, 1);
    edges = struct('valid', false, 'quality', 'LOW', 'threshold_power', threshold, 'two_point_index', NaN, ...
        'eight_point_index', NaN, 'fused_index', NaN, 'covariance_samples2', Inf, 'reason', 'NO_MONOTONIC_CROSSING');
    if isempty(crossing) || peak <= 0
        return
    end

    slope = p(crossing + 1) - p(crossing);
    if slope <= eps(max(peak, 1))
        edges.reason = 'FLAT_EDGE';
        return
    end

    two = first + crossing - 1 + (threshold - p(crossing)) / slope;
    ids = max(1, crossing - 3):min(numel(p), crossing + 4);
    x = (first + ids - 1).';
    y = p(ids);
    X = [ones(numel(x), 1), x];
    beta = X \ y;
    residual = y - X * beta;
    if beta(2) <= 0 || numel(x) < 4
        edges.reason = 'INSUFFICIENT_LOCAL_DATA';
        return
    end

    eight = (threshold - beta(1)) / beta(2);
    variance = max(sum(residual.^2) / max(numel(x) - 2, 1), eps(max(peak, 1))^2);
    varTwo = max(variance / slope^2, 1e-6);
    varEight = max(variance / (beta(2)^2 * numel(x)), 1e-6);
    fused = (two / varTwo + eight / varEight) / (1 / varTwo + 1 / varEight);
    covariance = 1 / (1 / varTwo + 1 / varEight);
    edges = struct('valid', true, 'quality', 'GOOD', 'threshold_power', threshold, 'two_point_index', two, ...
        'eight_point_index', eight, 'fused_index', fused, 'covariance_samples2', covariance, 'reason', '');
end

function value = field_or(s, name, default)
    if isfield(s, name)
        value = s.(name);
    else
        value = default;
    end
end
