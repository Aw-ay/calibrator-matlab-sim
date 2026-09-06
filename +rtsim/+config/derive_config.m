function cfg = derive_config(cfg)
    % 秒参数是时序唯一来源；样点字段仅是本次运行的派生兼容视图。
    fs = cfg.pl.output_fs_Hz;
    validateattributes(cfg.pl.decimation, {'numeric'}, {'scalar', 'finite', 'integer', 'positive'});
    validateattributes(cfg.capture.max_pulse_s, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    assert(cfg.rfdc.output_fs_Hz == cfg.rfdc.interface_clock_Hz * cfg.rfdc.samples_per_clock && ...
        fs == cfg.rfdc.output_fs_Hz / cfg.pl.decimation && cfg.pl.output_samples_per_clock == 1, ...
        'rtsim:RateMismatch', '采样率、SPC与抽取率矛盾。');
    assert(cfg.baseband.usable_bandwidth_Hz > 0 && cfg.baseband.usable_bandwidth_Hz < fs, ...
        'rtsim:Bandwidth', '有效带宽必须小于核心采样率。');
    cfg.rates.fs_record_Hz = fs;
    cfg.rates.fs_rfdc_iq_Hz = cfg.rfdc.output_fs_Hz;
    cfg.rates.fs_adc_real_Hz = cfg.adc.fs_real_Hz;
    cfg.rates.samples_per_clock = cfg.rfdc.samples_per_clock;
    cfg.channel.fs_Hz = fs;
    cfg.radar.fc_Hz = cfg.rf.fc_Hz;
    cfg.channel.fc_Hz = cfg.rf.fc_Hz;
    names = {'pretrigger', 'posttrigger', 'end_hold'};
    for k = 1:numel(names)
        name = names{k};
        validateattributes(cfg.capture.([name '_s']), {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
        cfg.capture.([name '_samples']) = round(cfg.capture.([name '_s']) * fs);
    end
    validateattributes(cfg.capture.end_hold_s, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(cfg.capture.range_select_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(cfg.capture.rx_calibration_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(cfg.capture.bank_prepare_s, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    cfg.capture.max_samples = cfg.capture.bank_capacity_samples;
    cfg.pl.filter = rtsim.ddc.design_pl_filter(cfg.rfdc.output_fs_Hz, cfg.pl.decimation, ...
        cfg.baseband.usable_bandwidth_Hz);
    cfg.pl.group_delay_s = (numel(cfg.pl.filter.coefficients) - 1) / (2 * cfg.rfdc.output_fs_Hz);
    cfg.capture.fir_tail_samples = ceil(2 * cfg.pl.group_delay_s * fs);
    cfg.capture.required_capacity_samples = ceil(cfg.capture.max_pulse_s * fs) + ...
        cfg.capture.pretrigger_samples + max(cfg.capture.posttrigger_samples, cfg.capture.end_hold_samples) + ...
        cfg.capture.fir_tail_samples + 2;
    c = cfg.constants.c_mps;
    cfg.radar.metrics = struct('prf_Hz', 1 / cfg.radar.pri_s, ...
        'unambiguous_range_m', c * cfg.radar.pri_s / 2, ...
        'nyquist_velocity_mps', c / cfg.rf.fc_Hz / cfg.radar.pri_s / 4, ...
        'range_resolution_m', c / (2 * cfg.radar.bandwidth_Hz), ...
        'sample_grid_m', c / (2 * fs), 'sample_period_s', 1 / fs);
end
