function metrics = beam_cut_metrics(angles_deg, power)
    % 主瓣排除至两侧首个局部极小值（第一零点采样近似），避免把裙边当旁瓣。

    a = angles_deg(:);
    p = power(:);
    if numel(a) < 5 || numel(a) ~= numel(p) || any(diff(a) <= 0) || any(p < 0)
        error('rtsim:array:Cut', '切面必须有递增角度和匹配的非负功率。');
    end

    [peak, k] = max(p);
    p = p / max(peak, realmin);
    l = k;
    r = k;
    while l > 1 && p(l) > .5
        l = l - 1;
    end

    while r < numel(p) && p(r) > .5
        r = r + 1;
    end

    metrics.pointing_deg = a(k);
    metrics.hpbw_deg = NaN;
    if l < k && r > k && p(l) <= .5 && p(r) <= .5
        left = interp1(p(l:l + 1), a(l:l + 1), .5);
        right = interp1(p(r - 1:r), a(r - 1:r), .5);
        metrics.hpbw_deg = right - left;
    end

    left_null = k;
    right_null = k;
    while left_null > 1 && p(left_null - 1) <= p(left_null)
        left_null = left_null - 1;
    end

    while right_null < numel(p) && p(right_null + 1) <= p(right_null)
        right_null = right_null + 1;
    end

    side = [p(1:left_null - 1); p(right_null + 1:end)];
    metrics.sll_dB = NaN;
    if ~isempty(side)
        metrics.sll_dB = 10 * log10(max(max(side), realmin));
    end

    metrics.main_lobe_exclusion_deg = [a(left_null) a(right_null)];
    metrics.sll_definition = '主瓣排除至两侧首个局部极小值；切面覆盖不足则NaN';
end
