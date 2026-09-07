function result = run_ota_demo(basis)
    % 用用户提供的2.8GHz联合激励场运行正式采样链单模式实验。
    % 默认Ludwig-3仅为未确认假设；不代表完整Jones或双端口校准资格。

    if nargin == 0
        basis = 'LUDWIG3';
    end

    root = fileparts(mfilename('fullpath'));
    cfg = rtsim.config.default_config();
    cfg.radar.pulse_count = 1;
    cfg.sim.duration_s = 200e-6;
    cfg.target.reference_plane = 'RP1';
    cfg.target.polar_matrix = diag([1, 0]);
    cfg.antenna.pattern = struct('kind', 'CST_FARFIELD', ...
        'file', fullfile(root, 'uav_pattern', 'farfield_resolution1deg.txt'), ...
        'frequency_Hz', 2.8e9, 'excited_port', 'JOINT_HV', 'basis', basis, ...
        'metadata_verified', false, 'mode', 'EXCITATION_MODE_ONLY');
    cfg.antenna.excitation_mode_only = true;

    % 将ANT +Z主瓣指向位于ENU原点的雷达。

    cfg.antenna.mounting.pitch_offset_deg = -90;
    cfg.replay.interpolation_method = 'LAGRANGE';
    result = rtsim.sim.simulate_case(cfg, 'OTA_JOINT_MODE', []);
    fprintf('联合模式实验：%s；基定义假设=%s；完整Jones资格=false。\n', result.output_dir, basis);
end
