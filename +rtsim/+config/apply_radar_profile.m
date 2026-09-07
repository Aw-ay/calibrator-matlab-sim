function cfg = apply_radar_profile(cfg, profile)
    % 雷达任务与采样实现可独立选择。

    switch upper(char(profile))
        case {'SMOKE', 'ALGORITHM_SMOKE'}
            values = [10e-6, 1e6, 1e3, 4];
        case {'SHORT_PULSE', 'NEAR_RANGE'}
            values = [2e-6, 2e6, 3e3, 64];
        case {'NORMAL_LFM', 'NORMAL_WEATHER'}
            values = [40e-6, 5e6, 1e3, 64];
        case {'LONG_RANGE_LFM', 'LONG_RANGE'}
            values = [120e-6, 2e6, 500, 64];
        case {'HIGH_PRF', 'SEVERE_WEATHER'}
            values = [20e-6, 5e6, 3.3e3, 128];
        case 'CALIBRATION'
            values = [cfg.radar.pulse_width_s, cfg.radar.bandwidth_Hz, 1 / cfg.radar.pri_s, cfg.radar.pulse_count];
        otherwise
            error('rtsim:RadarProfile', '未知雷达模式：%s', profile);
    end

    cfg.radar.profile = upper(char(profile));
    cfg.radar.pulse_width_s = values(1);
    cfg.radar.bandwidth_Hz = values(2);
    cfg.radar.pri_s = 1 / values(3);
    cfg.radar.pulse_count = values(4);
    cfg.sim.duration_s = cfg.radar.start_s + (cfg.radar.pulse_count - 1) * cfg.radar.pri_s + ...
        max(cfg.radar.pri_s, 2 * cfg.target.range_m / cfg.constants.c_mps + cfg.radar.pulse_width_s + 10e-6);
    cfg.sim.max_samples = max(cfg.sim.max_samples, ceil(cfg.sim.duration_s * cfg.pl.output_fs_Hz));
    cfg = rtsim.config.derive_config(cfg);
end
