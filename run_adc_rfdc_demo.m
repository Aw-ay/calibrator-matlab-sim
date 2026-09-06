function result = run_adc_rfdc_demo()
    % 独立运行4GS/s短窗专项；不在长时间A/B主链中展开实RF样点。
    root = fileparts(mfilename('fullpath'));
    originalPath = path;
    restorePath = onCleanup(@() path(originalPath));
    addpath(root);
    result.nominal = rtsim.ddc.rfdc_adc_specialty();
    result.impaired = rtsim.ddc.rfdc_adc_specialty('jitter_rms_s', 1e-12, 'bits', 8);
    report = struct('model', '4GS/s 实RF短窗 → DDC/D8 → 500MS/s复IQ', ...
        'adc_fs_Hz', result.nominal.adc_fs_Hz, 'output_fs_Hz', result.nominal.output_fs_Hz, ...
        'nyquist_zone', result.nominal.nyquist_zone, 'nco_sign', result.nominal.nco_sign, ...
        'nominal_relative_rms_error', result.nominal.relative_rms_error, ...
        'impaired_relative_rms_error', result.impaired.relative_rms_error, ...
        'impaired_jitter_rms_s', 1e-12, 'impaired_adc_bits', 8, ...
        'scope', '合成单音验证；不是RFDC厂商位精确模型或板卡测试');
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
    outDir = fullfile(root, 'results', ['ADC_RFDC_' stamp]);
    mkdir(outDir);
    result.report = report;
    result.output_dir = outDir;
    save(fullfile(outDir, 'result.mat'), 'result');
    fid = fopen(fullfile(outDir, '专项报告.json'), 'w', 'n', 'UTF-8');
    assert(fid >= 0, 'rtsim:Output', '无法创建专项报告。');
    closeFile = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', jsonencode(report, 'PrettyPrint', true));
    clear closeFile;
    sources = dir(fullfile(root, '**', '*.m'));
    files = struct('paths', {fullfile({sources.folder}, {sources.name})}, ...
        'project_root', root, 'out_dir', outDir);
    rtsim.verification.write_run_manifest(struct('window_s', 4e-6, 'fc_Hz', 2.8e9, ...
        'tone_Hz', 3e6, 'nominal_adc_bits', 16), files, struct('matlab', version), ...
        struct('scenario', 20260906), report);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1000, 600]);
    closeFigure = onCleanup(@() close(fig));
    tiledlayout(2, 1, 'TileSpacing', 'compact');
    nominal = result.nominal;
    t = nominal.physical_time_s * 1e6;
    nexttile;
    plot(t, real(nominal.output), t, real(nominal.ideal_500M), '--');
    xlabel('物理样点时间 / μs');
    ylabel('复包络实部');
    title('短窗实RF采样、DDC与理想500MS/s参考');
    legend('4GS/s专项输出', '理想复基带');
    grid on;
    nexttile;
    plot(t, abs(nominal.output - nominal.ideal_500M), ...
        t, abs(result.impaired.output - result.impaired.ideal_500M));
    xlabel('物理样点时间 / μs');
    ylabel('复误差幅度');
    legend('16位、零抖动', '8位、1ps抖动');
    title('启动暂态保留在图中；RMS比较排除FIR启动区');
    grid on;
    exportgraphics(fig, fullfile(outDir, '专项结果.png'), 'Resolution', 150);
    fprintf('ADC/RFDC专项：相对RMS误差 %.6g；结果：%s\n', ...
        nominal.relative_rms_error, outDir);
end
