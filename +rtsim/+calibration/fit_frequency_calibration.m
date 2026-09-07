function cal = fit_frequency_calibration(m, cfg)
    % 仅由独立激励/响应测量估计H(f)，再拟合带显式固定延迟的因果逆FIR。
    % m.excitation/response为2xExK复频点；真实plant不是此函数的输入。

    f = m.frequency_hz(:);
    fs = cfg.sample_rate_hz;
    nt = cfg.tap_count;
    latency = cfg.latency_samples;
    validateattributes(fs, {'numeric'}, {'scalar', 'real', 'positive', 'finite'});
    validateattributes(nt, {'numeric'}, {'scalar', 'integer', '>=', 2});
    validateattributes(latency, {'numeric'}, {'scalar', 'integer', '>=', 0, '<', nt});
    validateattributes(cfg.regularization, {'numeric'}, {'scalar', 'real', 'positive', 'finite'});
    validateattributes(cfg.max_inverse_gain, {'numeric'}, {'scalar', 'real', 'positive', 'finite'});
    if numel(unique(f)) < max(5, ceil(nt / 2)) || any(~isfinite(f)) || any(abs(f) >= fs / 2)
        error('rtsim:calibration:InsufficientFrequencyData', '频点不足、重复或超出Nyquist域，不能声明宽带资格。');
    end

    if size(m.excitation, 1) ~= 2 || size(m.response, 1) ~= 2 || ...
            ~isequal(size(m.excitation), size(m.response)) || size(m.excitation, 3) ~= numel(f)
        error('rtsim:calibration:MeasurementShape', '激励及响应必须为同形2xExK数组。');
    end

    H = complex(zeros(2, 2, numel(f)));
    target = H;
    clipped = false(numel(f), 1);
    for k = 1:numel(f)
        X = m.excitation(:, :, k);
        Y = m.response(:, :, k);
        if any(~isfinite(X), 'all') || any(~isfinite(Y), 'all') || rank(X) < 2
            error('rtsim:calibration:ExcitationRank', '每频点必须有两个线性独立且有限的极化激励。');
        end

        H(:, :, k) = Y / X;
        [U, S, V] = svd(H(:, :, k));
        singular = diag(S);
        inverse = singular ./ (singular.^2 + cfg.regularization);
        clipped(k) = any(inverse > cfg.max_inverse_gain);
        inverse = min(inverse, cfg.max_inverse_gain);
        target(:, :, k) = V * diag(inverse) * U' * exp(-2i * pi * f(k) * latency / fs);
    end

    A = exp(-2i * pi * f * (0:nt - 1) / fs);
    coeff = complex(zeros(nt, 2, 2));
    for o = 1:2
        for i = 1:2
            coeff(:, o, i) = [A; sqrt(cfg.regularization) * eye(nt)] \ ...
                [reshape(target(o, i, :), [], 1); zeros(nt, 1)];
        end
    end

    % 在整个数字频域检查实现后的增益，避免带限逆问题在带外放大。

    grid = linspace(-fs / 2, fs / 2, 2049)';
    F = exp(-2i * pi * grid * (0:nt - 1) / fs);
    peak = 0;
    for k = 1:numel(grid)
        C = reshape(F(k, :) * reshape(coeff, nt, 4), 2, 2);
        peak = max(peak, norm(C, 2));
    end

    scale = min(1, cfg.max_inverse_gain / max(peak, eps));
    coeff = coeff * scale;
    cal = struct('coeff', coeff, 'latency_samples', latency, 'sample_rate_hz', fs, ...
        'domain', m.domain, 'frequency_hz', f, 'estimated_response', H, ...
        'qualification', 'BLOCKED_MISSING_HOLDOUT', 'gain_limit_applied', any(clipped) || scale < 1, ...
        'implemented_peak_gain', peak * scale, 'holdout', struct('relative_complex_error', NaN), ...
        'regularization', cfg.regularization, 'fixed_latency_seconds', latency / fs);
    if min(f) > m.domain.frequency_hz(1) || max(f) < m.domain.frequency_hz(2)
        error('rtsim:calibration:OutOfDomain', '测量频点必须覆盖声明频域。');
    end

    if isfield(m, 'holdout') && ~isempty(m.holdout)
        h = m.holdout;
        hf = h.frequency_hz(:);
        errors = [];
        references = [];
        amp = [];
        phase = [];
        for k = 1:numel(hf)
            q = struct('range_index', m.domain.range_index, 'temperature_c', mean(m.domain.temperature_c), ...
                'power_dbm', mean(m.domain.power_dbm), 'frequency_hz', hf(k));
            rtsim.calibration.validate_frequency_domain(cal, q);
            C = reshape(exp(-2i * pi * hf(k) * (0:nt - 1) / fs) * reshape(coeff, nt, 4), 2, 2);
            recovered = C * h.response(:, :, k) * exp(2i * pi * hf(k) * latency / fs);
            reference = h.excitation(:, :, k);
            errors = [errors; recovered(:) - reference(:)]; %#ok<AGROW>
            references = [references; reference(:)]; %#ok<AGROW>
            valid = abs(reference) > 1e-8;
            ratio = recovered(valid) ./ reference(valid);
            amp = [amp; 20 * log10(abs(ratio))]; %#ok<AGROW>
            phase = [phase; angle(ratio) * 180 / pi]; %#ok<AGROW>
        end

        cal.holdout = struct('relative_complex_error', norm(errors) / max(norm(references), eps), ...
            'max_amplitude_error_db', max(abs(amp)), 'max_phase_error_deg', max(abs(phase)), ...
            'frequency_count', numel(hf), 'fixed_delay_removed_samples', latency);
        if isfield(m, 'qualification') && strcmpi(m.qualification, 'SYNTHETIC')
            cal.qualification = 'SYNTHETIC';
        else
            cal.qualification = 'MEASURED_INPUT_NOT_SYSTEM_QUALIFIED';
        end
    end
end
