function [clocks, st] = clock_model_step(grid, st, cfgClock, plantCond)
    % CLOCK_MODEL_STEP 生成名义频偏、时间偏置和可选随机游走的观测误差。

    arguments
        grid struct
        st struct
        cfgClock struct
        plantCond = [] %#ok<INUSA>
    end

    rtsim.time.validate_time_grid(grid);
    required = {'frequency_offset_ppm', 'time_offset_s', 'random_walk_std_s_per_sqrt_s'};
    assert(all(isfield(cfgClock, required)), 'rtsim:time:InvalidClockConfig', '时钟配置字段不完整。');
    assert(cfgClock.random_walk_std_s_per_sqrt_s >= 0, 'rtsim:time:InvalidClockConfig', '随机游走强度必须非负。');
    n = double(grid.count);
    dt = 1 / grid.fs_Hz;
    elapsed0 = localField(st, 'elapsed_s', 0);
    walk0 = localField(st, 'walk_error_s', 0);
    if cfgClock.random_walk_std_s_per_sqrt_s == 0
        walk = walk0 + zeros(n, 1);
    else
        stream = localStream(st, 1005);
        increments = cfgClock.random_walk_std_s_per_sqrt_s * sqrt(dt) * randn(stream, n, 1);
        st.rng_state = stream.State;
        walk = walk0 + cumsum(increments);
    end

    localTime = elapsed0 + (0:n - 1).' * dt;
    timeError = cfgClock.time_offset_s + cfgClock.frequency_offset_ppm * 1e-6 .* localTime + walk;
    clocks = struct('time_error_s', timeError, ...
        'frequency_offset_fraction', cfgClock.frequency_offset_ppm * 1e-6, ...
        'clock_id', grid.clock_id, 'model_scope', "NOMINAL_OFFSET_FREQUENCY_AND_RANDOM_WALK");
    st.elapsed_s = elapsed0 + n * dt;
    st.walk_error_s = walk0;
    if n > 0
        st.walk_error_s = walk(end);
    end

    st.sample_count = localField(st, 'sample_count', uint64(0)) + grid.count;
end

function value = localField(s, name, defaultValue)
    if isfield(s, name)
        value = s.(name);
    else
        value = defaultValue;
    end
end

function stream = localStream(st, defaultSeed)
    stream = RandStream('mt19937ar', 'Seed', double(localField(st, 'seed', defaultSeed)));
    if isfield(st, 'rng_state')
        stream.State = st.rng_state;
    end
end
