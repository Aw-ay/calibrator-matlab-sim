function b = metrology_budget(data, mc_count)
    % 测量方程一阶预算：功率dB、时延ns、频率Hz、ZDR dB、PhiDP deg、RCS dBsm。
    % pH=标准+电缆+RXH+TXH+方向图H+sH姿态+功率估计+多径+温漂，pV同理。
    % tau=2dr/c+时钟+电缆时延+估计；f=频标+本振+估计；ZDR=pH-pV+差分估计。
    % PhiDP=(RX相位H+TX相位H)-(RX相位V+TX相位V)+相位估计，共相位严格抵消。
    % RCS=pH+40log10((R+dr)/R)-2(方向图H+sH姿态)，以下J为零误差处导数。

    if nargin < 2
        mc_count = 20000;
    end

    C = data.covariance;
    n = numel(data.source_names);
    required = ["power_standard", "cable_gain", "rx_gain_h", "rx_gain_v", "tx_gain_h", "tx_gain_v", ...
        "common_phase", "rx_phase_h", "rx_phase_v", "tx_phase_h", "tx_phase_v", ...
        "position", "attitude", "pattern_h", "pattern_v", "clock_time", "cable_delay", ...
        "frequency_standard", "oscillator", "power_estimator", "zdr_estimator", ...
        "phase_estimator", "delay_estimator", "frequency_estimator", "multipath", "temperature_gain"];
    [present, sourceIndex] = ismember(required, string(data.source_names));
    if ~all(present) || numel(unique(sourceIndex)) ~= 26
        error('rtsim:verification:SourceSchema', '预算必须按名称提供全部26个已定义误差源。');
    end

    expectedUnits = ["dB", "dB", "dB", "dB", "dB", "dB", "deg", "deg", "deg", "deg", "deg", ...
        "m", "deg", "dB", "dB", "ns", "ns", "Hz", "Hz", "dB", "dB", "deg", "ns", "Hz", "dB", "dB"];
    if ~isequal(reshape(string(data.source_units(sourceIndex)), 1, []), expectedUnits)
        error('rtsim:verification:SourceUnits', '误差源单位必须与测量方程匹配。');
    end

    if ~isequal(size(C), [n n]) || n ~= 26 || ~isreal(C) || any(~isfinite(C), 'all') || ...
            norm(C - C', 'fro') > 1e-12 * max(norm(C, 'fro'), realmin) || any(diag(C) < 0)
        error('rtsim:verification:InvalidCovariance', '误差源协方差必须有限、实对称且半正定。');
    end

    % 用相关矩阵检查半正定，避免混合量纲让微小方差的负特征值被忽略。

    sd = sqrt(diag(C));
    active = sd > 0;
    if any(abs(C(~active, :)) > 0, 'all')
        error('rtsim:verification:InvalidCovariance', '零方差源不能有非零协方差。');
    end

    R = C(active, active) ./ (sd(active) * sd(active)');
    [V, D] = eig((R + R') / 2);
    eigen = diag(D);
    if any(eigen < -1e-10)
        error('rtsim:verification:InvalidCovariance', '相关矩阵非半正定。');
    end

    validateattributes(data.nominal_range_m, {'numeric'}, {'scalar', 'positive', 'finite'});
    validateattributes(data.coverage_factor, {'numeric'}, {'scalar', 'positive', 'finite'});
    validateattributes(mc_count, {'numeric'}, {'scalar', 'integer', 'nonnegative'});
    s = data.pattern_slope_db_per_deg;
    J = zeros(6, n);
    h = zeros(1, n);
    h([1 2 3 5 14 20 25 26]) = 1;
    h(13) = s(1);
    v = zeros(1, n);
    v([1 2 4 6 15 20 25 26]) = 1;
    v(13) = s(2);
    J(1, :) = h;
    J(2, [12 16 17 23]) = [2e9 / 299792458 1 1 1];
    J(3, [18 19 24]) = 1;
    J(4, :) = h - v;
    J(4, 21) = 1;
    J(5, [8 10 9 11 22]) = [1 1 -1 -1 1];
    J(6, :) = h;
    J(6, 12) = 40 / (log(10) * data.nominal_range_m);
    J(6, 14) = J(6, 14) - 2;
    J(6, 13) = J(6, 13) - 2 * s(1);
    canonical = J;
    J(:, sourceIndex) = canonical;
    output_cov = J * C * J';
    standard = sqrt(max(diag(output_cov), 0));
    outnames = ["power_h_db", "delay_ns", "frequency_hz", "zdr_db", "phidp_deg", "rcs_dbsm"]';
    b = struct('output_names', outnames, 'jacobian', J, 'covariance', output_cov, 'standard', standard, ...
        'expanded', data.coverage_factor * standard, 'coverage_factor', data.coverage_factor, ...
        'coverage_definition', 'k乘标准不确定度；k=2为近似正态95.45%，不保证实测覆盖率', ...
        'qualification', data.qualification, 'input_data', data, 'mc_standard', NaN(6, 1));
    b.source_table = table(data.source_names, data.source_units, sd, data.source_provenance, ...
        'VariableNames', {'source', 'unit', 'standard_uncertainty', 'provenance'});
    b.output_table = table(outnames, standard, b.expanded, ...
        'VariableNames', {'quantity', 'standard_uncertainty', 'expanded_uncertainty'});

    % 对角项与相关交叉项分列，后者可能为负，不能当成独立平方和。

    b.independent_variance = (J.^2) * diag(C);
    b.correlation_variance = diag(output_cov) - b.independent_variance;
    if mc_count > 1
        stream = RandStream('mt19937ar', 'Seed', data.seed);
        delta = zeros(n, mc_count);
        delta(active, :) = diag(sd(active)) * V * diag(sqrt(max(eigen, 0))) * randn(stream, sum(active), mc_count);
        response = J * delta;

        % RCS蒙特卡洛使用原始非线性距离方程，而解析预算采用其Jacobian。

        dr = delta(sourceIndex(12), :);
        r = data.nominal_range_m;
        if any(r + dr <= 0)
            error('rtsim:verification:InvalidRange', 'MC距离越过非正域。');
        end

        response(6, :) = response(6, :) - J(6, sourceIndex(12)) * dr + 40 * log10((r + dr) / r);
        b.mc_standard = std(response, 0, 2);
    end
end
