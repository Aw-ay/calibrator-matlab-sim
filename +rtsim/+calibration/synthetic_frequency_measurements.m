function [m, cfg] = synthetic_frequency_measurements()
    % 合成独立频点激励测量示例；真实响应只在本生成端使用，绝非VNA实测。

    fs = 62.5e6;
    cfg = struct('sample_rate_hz', fs, 'tap_count', 33, 'latency_samples', 12, ...
        'regularization', 1e-7, 'max_inverse_gain', 3);
    f = linspace(-10e6, 10e6, 101)';
    fh = linspace(-9.95e6, 9.95e6, 80)';
    m = make_measurement(f, fs, false);
    m.domain = struct('range_index', 2, 'temperature_c', [25 25], 'power_dbm', [-30 -30], ...
        'frequency_hz', [-10e6 10e6]);
    m.qualification = 'SYNTHETIC';
    m.source = '声明的合成二阶MIMO响应，无实测温度/功率扫域';
    m.holdout = make_measurement(fh, fs, true);
end

function m = make_measurement(f, fs, holdout)
    X = complex(zeros(2, 3, numel(f)));
    Y = X;
    for k = 1:numel(f)
        z = exp(-2i * pi * f(k) / fs);
        H = [0.91 + 0.09 * z, 0.04 - 0.022i * z; 0.025 * z + 0.01i, 1.06 - 0.07 * z + 0.012 * z^2];
        if holdout
            X(:, :, k) = [exp(0.31i * k), 0.7 * exp(-0.27i * k), 1 + 0.3i; ...
                0.8 * exp(-0.19i * k), exp(0.13i * k), 0.4 - 0.9i];
        else
            X(:, :, k) = [1, 0, exp(0.21i * k); 0, 1, 0.6 * exp(-0.17i * k)];
        end

        Y(:, :, k) = H * X(:, :, k);
    end

    m = struct('frequency_hz', f, 'excitation', X, 'response', Y);
end
