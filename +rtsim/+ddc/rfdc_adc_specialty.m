function result = rfdc_adc_specialty(cfg)
    % 数微秒4GS/s实ADC专项；正RF复包络乘负NCO恢复，第二Nyquist区不额外共轭。

    arguments
        cfg.fc_Hz (1, 1) double = 2.8e9
        cfg.duration_s (1, 1) double = 4e-6
        cfg.tone_Hz (1, 1) double = 3e6
        cfg.amplitude (1, 1) double = 0.2
        cfg.bits (1, 1) double = 16
        cfg.jitter_rms_s (1, 1) double = 0
        cfg.seed (1, 1) double = 20260906
        cfg.quantization_enabled (1, 1) logical = true
    end

    assert(cfg.duration_s <= 20e-6 && cfg.duration_s > 0, 'rtsim:SpecialtyWindow', '专项只允许20us以内短窗。');
    assert(cfg.fc_Hz >= 2.7e9 && cfg.fc_Hz <= 3e9, 'rtsim:RFCarrier', 'RF载频范围2.7至3.0GHz。');
    fs = 4e9;
    d = 8;
    t = (0:ceil(cfg.duration_s * fs) - 1)' / fs;
    stream = RandStream('mt19937ar', 'Seed', cfg.seed);
    sampleTime = t + cfg.jitter_rms_s * randn(stream, size(t));
    adc = 2 * cfg.amplitude * real(exp(1i * 2 * pi * (cfg.fc_Hz + cfg.tone_Hz) * sampleTime));
    if cfg.quantization_enabled
        lsb = 2 / 2^cfg.bits;
        adc = max(-1, min(1 - lsb, round(adc / lsb) * lsb));
    end

    mixed = adc .* exp(-1i * 2 * pi * cfg.fc_Hz * t);
    fir = rtsim.ddc.design_pl_filter(fs, d, 20e6);
    [out, ~] = rtsim.ddc.halfband_decimator(mixed, struct(), fir);
    delay = (numel(fir.coefficients) - 1) / (2 * fs);
    physicalTime = (0:numel(out) - 1)' / (fs / d) - delay;
    ideal = cfg.amplitude * exp(1i * 2 * pi * cfg.tone_Hz * physicalTime);
    valid = physicalTime > delay;
    result = struct('adc_fs_Hz', fs, 'output_fs_Hz', fs / d, 'nyquist_zone', floor(cfg.fc_Hz / (fs / 2)) + 1, ...
        'aliased_carrier_Hz', mod(cfg.fc_Hz + fs / 2, fs) - fs / 2, ...
        'nco_sign', -1, 'output', out, 'ideal_500M', ideal, 'physical_time_s', physicalTime, ...
        'available_time_s', (0:numel(out) - 1)' / (fs / d), 'group_delay_s', delay, ...
        'relative_rms_error', norm(out(valid) - ideal(valid)) / norm(ideal(valid)));
end
