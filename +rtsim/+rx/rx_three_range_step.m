function [rangeSignals, st, diag] = rx_three_range_step(commonIQ, st, cfgRanges, plantCond)
    % RX_THREE_RANGE_STEP 从同一公共 H/V 复包络生成三档支路。

    arguments
        commonIQ {mustBeNumeric}
        st struct
        cfgRanges struct
        plantCond = [] %#ok<INUSA>
    end

    assert(size(commonIQ, 2) == 2, 'rtsim:rx:InvalidRangeInput', '输入必须为 N×2 的 H/V 复包络。');
    assert(isfield(cfgRanges, 'gains') && isequal(size(cfgRanges.gains), [1 3]), ...
        'rtsim:rx:InvalidRangeConfig', 'gains 必须为 1×3。');
    assert(isfield(cfgRanges, 'response') && isequal(size(cfgRanges.response), [2 2 3]), ...
        'rtsim:rx:InvalidRangeConfig', 'response 必须为 2×2×3。');
    noisePower = localField(cfgRanges, 'noise_power_W', 0);
    if isscalar(noisePower)
        noisePower = repmat(noisePower, 1, 3);
    end

    assert(isequal(size(noisePower), [1 3]) && all(noisePower >= 0), ...
        'rtsim:rx:InvalidRangeConfig', 'noise_power_W 必须是非负标量或 1×3。');

    rangeSignals = complex(zeros(size(commonIQ, 1), 2, 3));
    [allNoise, st] = localComplexNoise([size(commonIQ, 1), 2, 3], st, 1002);
    for k = 1:3
        branch = double(commonIQ) * transpose(cfgRanges.response(:, :, k));
        noise = sqrt(noisePower(k) / 2) .* allNoise(:, :, k);
        rangeSignals(:, :, k) = cfgRanges.gains(k) .* branch + noise;
    end

    st.sample_count = localField(st, 'sample_count', uint64(0)) + uint64(size(commonIQ, 1));
    diag = struct('branch_noise_power_W', noisePower, ...
        'common_noise_reinjected', false, 'model_scope', "MEMORYLESS_ENVELOPE_MATRIX");
end

function value = localField(s, name, defaultValue)
    if isfield(s, name)
        value = s.(name);
    else
        value = defaultValue;
    end
end

function [z, st] = localComplexNoise(sz, st, defaultSeed)
    channels = prod(sz(2:end));
    stream = localStream(st, defaultSeed);
    draws = randn(stream, 2 * channels, sz(1)).';
    z = reshape(draws(:, 1:2:end) + 1i * draws(:, 2:2:end), sz);
    st.rng_state = stream.State;
end

function stream = localStream(st, defaultSeed)
    stream = RandStream('mt19937ar', 'Seed', double(localField(st, 'seed', defaultSeed)));
    if isfield(st, 'rng_state')
        stream.State = st.rng_state;
    end
end
