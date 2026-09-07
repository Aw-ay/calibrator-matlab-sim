function [response, meta] = sample_farfield(pattern, theta_deg, phi_deg, frequency_Hz)
    % SAMPLE_FARFIELD 规则网格复数双线性插值，方位周期接缝无需重排原始样本。
    % 单文件输出2×1激励模式场；两份已知独立激励恢复后输出2×2 Jones。

    meta = struct('valid', true, 'reason', 'COMPLEX_REGULAR_GRID', 'extrapolated', false, ...
        'has_phase', true, 'has_full_jones', pattern.has_full_jones, ...
        'full_polarization_qualified', pattern.full_polarization_qualified, ...
        'metadata_verified', pattern.metadata_verified, 'mode', pattern.mode, 'basis', pattern.basis);
    nport = size(pattern.field_samples, 4);
    response = complex(nan(2, nport));
    frequencyKnown = isfinite(pattern.frequency_Hz);
    if ~isscalar(theta_deg) || ~isscalar(phi_deg) || ~isfinite(theta_deg) || ~isfinite(phi_deg) || ...
            theta_deg < 0 || theta_deg > 180 || ...
            (frequencyKnown && (~isfinite(frequency_Hz) || ...
            abs(frequency_Hz - pattern.frequency_Hz) > max(1, abs(pattern.frequency_Hz)) * 1e-12))
        meta.valid = false;
        meta.reason = 'OUTSIDE_MEASURED_DOMAIN';
        meta.extrapolated = true;
        return
    end

    if ~frequencyKnown && isfinite(frequency_Hz)
        meta.valid = false;
        meta.reason = 'UNKNOWN_SOURCE_FREQUENCY';
        return
    end

    nt = numel(pattern.theta_deg);
    np = numel(pattern.phi_deg);
    t = theta_deg / 180 * (nt - 1);
    p = mod(phi_deg, 360) / 360 * np;
    ti = min(floor(t) + 1, nt - 1);
    a = t - (ti - 1);
    pi = floor(p) + 1;
    pj = mod(pi, np) + 1;
    b = p - floor(p);
    F = pattern.field_samples;
    response = reshape((1 - a) * (1 - b) * F(ti, pi, :, :) + a * (1 - b) * F(ti + 1, pi, :, :) + ...
        (1 - a) * b * F(ti, pj, :, :) + a * b * F(ti + 1, pj, :, :), 2, nport);
end
