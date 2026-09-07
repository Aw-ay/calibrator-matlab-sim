function result = run_stage_a(cfg)
    % 运行固定平台标定仪闭环；在命令窗口输入 run_stage_a 即可。

    if nargin == 0
        cfg = rtsim.config.default_config();
    end

    assert(all(cfg.platform.velocity_mps == 0) && all(cfg.platform.acceleration_mps2 == 0) && ...
        cfg.platform.roll_rate_dps == 0 && cfg.platform.pitch_rate_dps == 0 && ...
        cfg.platform.yaw_rate_dps == 0, 'rtsim:StageAStatic', '阶段 A 必须为固定平台。');
    result = rtsim.sim.simulate_case(cfg, 'A', []);
end
