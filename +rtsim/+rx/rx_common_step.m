function [out, st, diag] = rx_common_step(portIQ, st, cfgRf, plantCond)
    % RX_COMMON_STEP 三档分路前的公共增益、噪声和幅度限幅模型。

    arguments
        portIQ {mustBeNumeric}
        st struct
        cfgRf struct
        plantCond = [] %#ok<INUSA>
    end

    gain = localField(cfgRf, 'gain', 1);
    noisePower = localField(cfgRf, 'noise_power_W', 0);
    limit = localField(cfgRf, 'saturation_amplitude', Inf);
    assert(isscalar(gain) && isfinite(gain), 'rtsim:rx:InvalidCommonConfig', 'gain 必须是有限标量。');
    assert(isscalar(noisePower) && noisePower >= 0, 'rtsim:rx:InvalidCommonConfig', 'noise_power_W 必须非负。');
    assert(isscalar(limit) && limit > 0, 'rtsim:rx:InvalidCommonConfig', 'saturation_amplitude 必须为正。');

    % 每个样点一次取出全部 H/V 的实虚部，使固定随机种子时块切分不改变序列。

    [unitNoise, st] = localComplexNoise(size(portIQ), st, 1001);
    noise = sqrt(noisePower / 2) .* unitNoise;
    beforeClip = gain .* double(portIQ) + noise;
    mag = abs(beforeClip);
    clipped = mag > limit;
    out = beforeClip;
    out(clipped) = beforeClip(clipped) ./ mag(clipped) .* limit;
    st.sample_count = localField(st, 'sample_count', uint64(0)) + uint64(size(portIQ, 1));
    diag = struct('clipped', clipped, 'injected_noise_power_W', mean(abs(noise(:)).^2), ...
        'noise_location', "COMMON_BEFORE_RANGE_SPLIT");
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
