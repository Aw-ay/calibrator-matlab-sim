function [response, validity] = pattern_interpolator(patterns, query)
    % PATTERN_INTERPOLATOR 对复Jones场作局部反距离插值。
    % 插值限制在实测角频包络内，不跨越未测区域外推；方位距离按360度周期计算。

    if strcmpi(patterns.kind, 'IDEAL')
        response = eye(2);
        validity = struct('valid', true, 'reason', 'IDEAL_MODEL', 'extrapolated', false);
        return
    end

    az = query.az_deg;
    el = query.el_deg;
    freq = query.freq_Hz;
    inside = el >= patterns.el_range_deg(1) && el <= patterns.el_range_deg(2) && ...
        freq >= patterns.freq_range_Hz(1) && freq <= patterns.freq_range_Hz(2);
    azSpan = diff(patterns.az_range_deg);
    if azSpan < 359
        inside = inside && az >= patterns.az_range_deg(1) && az <= patterns.az_range_deg(2);
    end

    if ~inside
        response = nan(2);
        validity = struct('valid', false, 'reason', 'OUTSIDE_MEASURED_DOMAIN', 'extrapolated', true);
        return
    end

    daz = abs(patterns.az_deg - az);
    daz = min(daz, 360 - daz);
    elScale = max(diff(patterns.el_range_deg), 1);
    freqScale = max(diff(patterns.freq_range_Hz), max(abs(freq), 1) * eps);
    d = sqrt((daz / 180).^2 + ((patterns.el_deg - el) / elScale).^2 + ((patterns.freq_Hz - freq) / freqScale).^2);
    [dSorted, index] = sort(d);
    exact = dSorted <= 1e-12;
    if any(exact)
        response = mean(patterns.jones_samples(:, :, index(exact)), 3);
    else
        count = min(8, numel(index));
        index = index(1:count);
        weights = 1 ./ d(index);
        weights = weights / sum(weights);
        response = zeros(2);
        for k = 1:count
            response = response + weights(k) * patterns.jones_samples(:, :, index(k));
        end
    end

    validity = struct('valid', all(isfinite(response), 'all'), 'reason', 'INTERPOLATED_WITHIN_DOMAIN', ...
        'extrapolated', false, 'has_phase', patterns.has_phase);
end
