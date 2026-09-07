function [measurement, st, diag] = tx_monitor_step(tap, st, monitorCfg, clockTruth)
    % TX_MONITOR_STEP 经独立参考链响应、偏置、时钟相位和噪声生成监测量。

    arguments
        tap (:, 2) double
        st (1, 1) struct
        monitorCfg (1, 1) struct
        clockTruth (1, 1) struct
    end

    need(monitorCfg, {'response_matrix', 'bias', 'noise_std', 'seed'});
    need(clockTruth, {'phase_error_rad'});
    if ~isfield(st, 'sample_index')
        st.sample_index = 0;
    end

    if ~isfield(st, 'rng_state')
        stream = RandStream('mt19937ar', 'Seed', monitorCfg.seed);
        st.rng_seed = monitorCfg.seed;
    else
        if st.rng_seed ~= monitorCfg.seed
            error('rtsim:tx:MonitorSeedChanged', '有状态监测过程中不能更改随机种子。');
        end

        stream = RandStream('mt19937ar', 'Seed', monitorCfg.seed);
        stream.State = st.rng_state;
    end

    % 每个样点固定抽取 H-I、H-Q、V-I、V-Q，保证任意分块得到相同随机序列。

    n = size(tap, 1);
    draws = reshape(randn(stream, 4 * n, 1), 4, n).';
    noise = monitorCfg.noise_std / sqrt(2) * complex(draws(:, [1 3]), draws(:, [2 4]));
    st.rng_state = stream.State;
    bias = reshape(monitorCfg.bias, 1, []);
    iq = tap * monitorCfg.response_matrix.' .* exp(1i * clockTruth.phase_error_rad) + bias + noise;
    measurement.iq = iq;
    measurement.power_W = mean(abs(iq).^2, 1);
    measurement.phase_rad = angle(mean(iq, 1));
    measurement.model_scope = "independent noisy monitor observation";
    st.sample_index = st.sample_index + size(tap, 1);
    diag.source = "independent_monitor_chain";
end

function need(s, n)
    for k = 1:numel(n)
        if ~isfield(s, n{k})
            error('rtsim:tx:MissingField', '缺少必需字段%s。', n{k});
        end
    end
end
