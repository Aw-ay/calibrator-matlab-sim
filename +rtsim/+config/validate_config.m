function report = validate_config(cfg, capabilities)
    % 只接受已实现的复包络模式；不把演示采样率当实 ADC 配置。

    if nargin < 2
        capabilities = [];
    end

    assert(strcmp(cfg.fidelity, 'ENVELOPE'), 'rtsim:UnsupportedFidelity', '当前闭环仅支持 ENVELOPE。');
    fs = cfg.pl.output_fs_Hz;
    assert(cfg.rfdc.output_fs_Hz == cfg.rfdc.interface_clock_Hz * cfg.rfdc.samples_per_clock && ...
        fs == cfg.rfdc.output_fs_Hz / cfg.pl.decimation && ...
        cfg.pl.output_samples_per_clock == 1, 'rtsim:RateMismatch', '采样率、SPC与抽取率矛盾。');
    assert(cfg.baseband.usable_bandwidth_Hz < fs, 'rtsim:Bandwidth', '有效带宽必须小于核心采样率。');
    assert(cfg.rf.fc_Hz >= 2.7e9 && cfg.rf.fc_Hz <= 3e9, 'rtsim:RFCarrier', 'RF载频必须在2.7至3.0GHz。');
    if strcmp(cfg.sampling_profile, 'RFSOC_SYSTEM_EQUIVALENT')
        assert(cfg.adc.fs_real_Hz == 4e9 && cfg.adc.fs_real_Hz / 8 == cfg.rfdc.output_fs_Hz && ...
            cfg.rfdc.samples_per_clock == 8 && cfg.rfdc.interface_clock_Hz == 62.5e6 && ...
            cfg.pl.decimation == 8 && fs == 62.5e6, 'rtsim:RateMismatch', '正式档必须满足4G/8=500M、8SPC及D8→62.5M。');
    end
    cfg = rtsim.config.derive_config(cfg);
    if cfg.pl.decimation > 1
        response = abs(fft(cfg.pl.filter.coefficients, 65536));
        frequencies = (0:65535) * cfg.rfdc.output_fs_Hz / 65536;
        pass = response(frequencies <= cfg.pl.filter.passband_Hz);
        stop = response(frequencies >= cfg.pl.filter.stopband_Hz & frequencies <= cfg.rfdc.output_fs_Hz / 2);
        assert(max(abs(20 * log10(pass))) <= cfg.pl.filter.max_passband_ripple_dB && ...
            -20 * log10(max(stop)) >= cfg.pl.filter.min_stopband_attenuation_dB, ...
            'rtsim:FIRSpecification', '实际FIR通带或阻带响应未满足声明。');
    end
    validateattributes(fs, {'numeric'}, {'scalar', 'finite', 'positive'});
    validateattributes(cfg.sim.block_size, {'numeric'}, {'scalar', 'integer', 'positive'});
    validateattributes(cfg.radar.pulse_count, {'numeric'}, {'scalar', 'integer', 'positive'});
    assert(cfg.radar.pulse_width_s > 0 && cfg.radar.pulse_width_s < cfg.radar.pri_s, 'rtsim:PulseTiming', ...
        '脉宽必须大于零且严格小于 PRI。');
    assert(cfg.radar.bandwidth_Hz > 0 && cfg.radar.bandwidth_Hz <= cfg.baseband.usable_bandwidth_Hz, ...
        'rtsim:Bandwidth', '信号带宽必须为正且不超过声明的有效基带带宽。');
    assert(ismember(cfg.instrument.mode, {'MUTE', 'LIVE', 'DRFM', 'DDS', 'AWG'}), 'rtsim:Mode', '信号源模式不支持。');
    if strcmp(cfg.instrument.mode, 'LIVE')
        assert((strcmp(cfg.channel.kind, ...
            'CABLE') || cfg.instrument.isolated_ports) && ~cfg.instrument.physical_loopback, 'rtsim:UnsafeLive', ...
            'LIVE 仅允许电缆或隔离端口，且禁止物理正反馈回环。');
    end

    assert(all(isfinite(cfg.platform.position_m)) && norm(cfg.platform.position_m) > 0, 'rtsim:Position', '物理距离必须为正。');
    assert(cfg.target.range_m > 0 && isfinite(cfg.target.range_m), 'rtsim:Target', '目标距离必须为正。');
    assert(isequal(size(cfg.target.polar_matrix), [2, 2]), 'rtsim:Polarization', '目标极化矩阵必须为 2×2。');
    assert(cfg.capture.bank_count >= 1 && ...
        cfg.capture.bank_capacity_samples >= cfg.capture.required_capacity_samples && ...
        cfg.radar.pulse_width_s <= cfg.capture.max_pulse_s, 'rtsim:Capacity', '捕获容量不足或脉宽超出声明。');
    assert(cfg.sim.duration_s * fs <= cfg.sim.max_samples, 'rtsim:MemoryLimit', '记录长度超过内存保护上限，请缩短窗口。');
    assert(~any(structfun(@(x) logical(x), cfg.options)), 'rtsim:OptionalDisabled', '未确认扩展不能直接开启。');
    assert(strcmp(cfg.target.phase_policy, 'INDEPENDENT_DOPPLER'), 'rtsim:PhasePolicy', '当前仅实现明确标注的独立多普勒体制。');
    assert(cfg.dataflow.dma_bytes_per_s >= 0, 'rtsim:Service', '服务率不能为负。');
    validateattributes(cfg.capture.bank_count, {'numeric'}, {'scalar', 'integer', 'positive'});
    validateattributes(cfg.instrument.source_start_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(cfg.channel.cable_gain, {'numeric'}, {'scalar', 'finite'});
    validateattributes(cfg.channel.cable_delay_s, {'numeric'}, {'scalar', 'finite', 'real', 'nonnegative'});
    assert(ismember(cfg.channel.kind, {'OTA', 'CABLE'}), 'rtsim:Channel', '信道仅支持 OTA/CABLE。');
    assert(cfg.instrument.tx_limit > 0 && isfinite(cfg.instrument.tx_limit), 'rtsim:TxLimit', '发射限幅必须为有限正值。');
    if strcmp(cfg.instrument.mode, 'AWG')
        assert(isfield(cfg.instrument, 'awg_table') && size(cfg.instrument.awg_table, ...
            2) == 2 && all(isfinite(cfg.instrument.awg_table(:))), 'rtsim:AWGData', 'AWG 需要有限 N×2 模板。');
    end

    report = struct('status', 'PASS', 'scope', '复包络配置检查', 'capabilities', capabilities);
end
