function report = run_acceptance_suite(cfg, tests, seedList)
    % 自动测试通过不等于原规格全部硬件/计量场景通过，两份结果分开报告。

    results = runtests(tests);
    outDir = fullfile(cfg.output.root, 'acceptance');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    save(fullfile(outDir, 'test_results.mat'), 'results', 'seedList');
    automatic = table({results.Name}.', [results.Passed].', [results.Failed].', [results.Incomplete].', ...
        [results.Duration].', ...
        'VariableNames', {'name', 'passed', 'failed', 'incomplete', 'duration_s'});
    writetable(automatic, fullfile(outDir, 'automatic_tests.csv'), 'Encoding', 'UTF-8');
    report.automatic = struct('total', numel(results), 'passed', sum([results.Passed]), ...
        'failed', sum([results.Failed]), 'incomplete', sum([results.Incomplete]));
    names = {'配置', '输入资料', '样点时间', '坐标', '坐标基', '方向图', '极化', '单程链路', '多径', '波形检测', ...
        '线性保护', '噪声', '转换器频率', '分块不变性', '时延记账', 'MTS通道', '三档资格', 'RAM生命周期', '检测PDW', ...
        '虚拟距离', '调度', '数据流', '相位多普勒', '校准', '相参信号源', '安全配置', '真值隔离', '定点HDL', '雷达解算', ...
        'B到A退化', '姿态', '运动杆臂', '温度供电', 'EMC时钟导航', '机体散射', '计量统计', '随机极化', '适用域', '频率子信道', '任务存储'};
    status = repmat({'NOT_RUN'}, 40, 1);
    note = repmat({'部分算法由 automatic_tests.csv 验证；原规格完整子场景尚未全部执行。'}, 40, 1);
    blocked = [2, 6, 16, 28, 38];
    status(blocked) = {'BLOCKED_MISSING_DATA'};
    note(blocked) = {'缺少原始实测/板卡/RTL输入；理想假设或软件测试不能替代。'};
    status([37, 39]) = {'NOT_APPLICABLE'};
    note([37, 39]) = {'可选随机天气与频率子信道未启用。'};

    % T30 是明确的独立退化断言，可由对应测试结果完整判定。
    idx = find(contains({results.Name}, 'stationaryRegression'));
    if ~isempty(idx) && all([results(idx).Passed])
        status{30} = 'PASS';
        note{30} = '相同配置、种子和静止平台下 A/B 波形与 PDW 一致。';
    elseif ~isempty(idx)
        status{30} = 'FAIL';
        note{30} = '静止 A/B 回归失败。';
    end

    report.original_spec = table(compose('T%02d', (1:40).'), names.', status, note, 'VariableNames', {'id', ...
        'name', 'status', 'scope'});
    writetable(report.original_spec, fullfile(outDir, 'original_spec_matrix.csv'), 'Encoding', 'UTF-8');
    report.scope = '自动测试结果按真实运行统计；原规格覆盖不自动升级为 PASS。';
    fid = fopen(fullfile(outDir, 'summary.json'), 'w', 'n', 'UTF-8');
    clean = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', jsonencode(struct('automatic', report.automatic, 'scope', report.scope), 'PrettyPrint', true));
    fprintf('\n自动测试：%d/%d 通过，失败 %d，未完成 %d。\n', report.automatic.passed, report.automatic.total, ...
        report.automatic.failed, report.automatic.incomplete);
end
