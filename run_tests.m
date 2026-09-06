function report = run_tests()
    % 一键执行全部类式测试，输出实际结果及原始四十项规格的覆盖边界。

    root = fileparts(mfilename('fullpath'));
    originalPath = path;
    cleanup = onCleanup(@() path(originalPath));
    addpath(root);
    cfg = rtsim.config.default_config();
    report = rtsim.verification.run_acceptance_suite(cfg, fullfile(root, 'tests'), cfg.seed);
    assert(report.automatic.failed == 0 && report.automatic.incomplete == 0, 'rtsim:TestFailure', ...
        '存在失败或未完成的自动测试，请查看 results/acceptance。');
end
