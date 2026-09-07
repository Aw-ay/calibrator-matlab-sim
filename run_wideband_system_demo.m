function comparison = run_wideband_system_demo()
    % 正式500MS/s输入链上的合成宽带闭环；测量拟合器不接收真实FIR。

    cfg = rtsim.config.default_config();
    cfg.radar.pulse_count = 1;
    cfg.radar.bandwidth_Hz = 10e6;
    cfg.sim.duration_s = 200e-6;
    cfg.replay.interpolation_method = 'LAGRANGE';
    cfg.output.save = false;
    reference = rtsim.sim.simulate_case(cfg, 'WIDEBAND_REFERENCE', []);
    [measurement, fitCfg] = rtsim.calibration.synthetic_frequency_measurements();
    txCal = rtsim.calibration.fit_frequency_calibration(measurement, fitCfg);

    % 公共接收网络位于量程分叉之前，三个量程共用同一频响校准。

    measurement.domain.range_index = 1:3;
    rxCal = rtsim.calibration.fit_frequency_calibration(measurement, fitCfg);
    h = complex(zeros(3, 2, 2));
    h(1, :, :) = reshape([0.91, 0.04; 0.01i, 1.06], 1, 2, 2);
    h(2, :, :) = reshape([0.09, -0.022i; 0.025, -0.07], 1, 2, 2);
    h(3, 2, 2) = 0.012;

    % 零插抽头确保500MS/s物理网络和62.5MS/s基带测量具有同一H(f)。

    rxPlant = complex(zeros(2 * cfg.pl.decimation + 1, 2, 2));
    rxPlant(1:cfg.pl.decimation:end, :, :) = h;
    cfg.calibration.wideband = struct('enabled', true, 'rx', rxCal, 'tx', txCal, ...
        'rx_plant_coeff', rxPlant, 'tx_plant_coeff', h, ...
        'operating_power_dbm', -30, 'tx_range_index', 2);
    cfg.instrument.tx_rf_tail_bound_samples = 2;
    cfg.replay.interpolation_method = 'LAGRANGE';
    cfg.output.save = true;
    calibrated = rtsim.sim.simulate_case(cfg, 'WIDEBAND_SYSTEM', []);
    comparison = struct('qualification', 'SYNTHETIC', ...
        'relative_waveform_error', norm(calibrated.radar_iq - reference.radar_iq, 'fro') / ...
        max(norm(reference.radar_iq, 'fro'), eps), ...
        'reference_range_m', reference.observables.range_m, ...
        'calibrated_range_m', calibrated.observables.range_m, ...
        'rx_holdout', rxCal.holdout, 'tx_holdout', txCal.holdout, ...
        'output_dir', calibrated.output_dir);
    save(fullfile(calibrated.output_dir, 'wideband_system_comparison.mat'), 'comparison');
    disp(comparison);
end
