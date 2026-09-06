function results = run_demo()
    % 生成固定平台与飞行平台演示，保存中文图表和可重复配置。

    root = fileparts(mfilename('fullpath'));
    addpath(root);
    cfg = rtsim.config.default_config();
    results.A = run_stage_a(cfg);
    cfg = rtsim.config.apply_case_profile(cfg, 'B1');
    results.B = run_stage_b(cfg);
    fprintf('阶段 A 结果：%s\n阶段 B 结果：%s\n', results.A.output_dir, results.B.output_dir);
end
