function result = run_stage_b(cfg)
    % 阶段 B 只更换平台适配，仪器核心与 A 完全相同。

    if nargin == 0
        cfg = rtsim.config.apply_case_profile(rtsim.config.default_config(), 'B1');
    end

    result = rtsim.sim.simulate_case(cfg, 'B', []);
end
