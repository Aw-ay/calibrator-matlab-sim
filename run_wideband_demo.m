function result = run_wideband_demo(output_dir)
    % 紧凑宽带计量示例，无需运行长时域正式仿真；全部输入均明确为合成。

    if nargin < 1
        output_dir = fullfile(fileparts(mfilename('fullpath')), 'results', 'ota_wideband');
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    comparison = rtsim.replay.compare_wideband_delay();
    [measurements, cfg] = rtsim.calibration.synthetic_frequency_measurements();
    cal = rtsim.calibration.fit_frequency_calibration(measurements, cfg);
    data = rtsim.verification.synthetic_metrology_inputs();
    budget = rtsim.verification.metrology_budget(data, 20000);
    writetable(comparison, fullfile(output_dir, 'delay_comparison.csv'));
    writetable(budget.source_table, fullfile(output_dir, 'uncertainty_sources.csv'));
    writetable(budget.output_table, fullfile(output_dir, 'uncertainty_budget.csv'));
    writematrix(data.covariance, fullfile(output_dir, 'uncertainty_input_covariance.csv'));
    writematrix(budget.jacobian, fullfile(output_dir, 'uncertainty_jacobian.csv'));
    writematrix(budget.covariance, fullfile(output_dir, 'uncertainty_output_covariance.csv'));
    result = struct('delay_comparison', comparison, 'calibration', cal, 'budget', budget, ...
        'qualification', 'SYNTHETIC', 'output_dir', output_dir);
    save(fullfile(output_dir, 'wideband_demo.mat'), 'result', 'measurements', 'cfg');
    fig = figure('Visible', 'off', 'Position', [100 100 1100 650]);
    cleanup = onCleanup(@()close(fig));
    metrics = {'max_amplitude_error_db', 'max_phase_error_deg', 'max_group_delay_error_ns', ...
        'max_zdr_error_db', 'max_phidp_error_deg'};
    labels = {'Amplitude error (dB)', 'Phase error (deg)', 'Group delay error (ns)', ...
        'H/V ZDR error (dB)', 'H/V phase error (deg)'};
    methods = unique(string(comparison.method), 'stable');
    for k = 1:numel(metrics)
        subplot(2, 3, k);
        hold on;
        for method = methods'
            idx = string(comparison.method) == method;
            semilogy(comparison.bandwidth_mhz(idx), max(comparison.(metrics{k})(idx), 1e-12), '-o');
        end

        set(gca, 'YScale', 'log');
        xlabel('Complex bandwidth (MHz)');
        ylabel(labels{k});
        grid on;
    end

    legend(methods, 'Location', 'best', 'Interpreter', 'none');
    subplot(2, 3, 6);
    axis off;
    text(0, 0.9, {'SYNTHETIC / floating reference'; 'Fs = 62.5 MS/s'; 'H delay = 0.37 sample'; ...
        'V delay = 0.61 sample'; '7th order / 8 taps'; 'Fixed latency removed in metrics'; ...
        'FARROW overlaps LAGRANGE'}, 'Interpreter', 'none');
    exportgraphics(fig, fullfile(output_dir, 'delay_comparison.png'), 'Resolution', 130);
    fid = fopen(fullfile(output_dir, 'wideband_report.md'), 'w', 'n', 'UTF-8');
    assert(fid >= 0);
    cleaner = onCleanup(@()fclose(fid));
    fprintf(fid, '# 宽带计量合成示例\n\n资格：SYNTHETIC；无VNA、校准证书、RTL或板卡测量。\n\n');
    fprintf(fid, '## 分数延迟\n\nB定义为复基带[-B/2,B/2]，Fs=62.5MS/s。');
    fprintf(fid, '比较1/2/5/10/20MHz；H/V分别0.37/0.61样点。\n');
    fprintf(fid, 'LINEAR固定延迟0，其余8tap流式固定延迟4样点；表内误差已扣除理想总延迟。\n');
    fprintf(fid, '整捕获随机插值附加延迟0，调用方必须先完成捕获。FARROW为Lagrange多项式浮点结构。\n');
    fprintf(fid, '完整幅相、群延迟和极化差分见delay_comparison.csv及PNG。\n\n');
    fprintf(fid, '## 独立频率校准\n\n101个训练频点，80个不同留出频点及不同复极化激励。');
    fprintf(fid, '只有合成测量生成端知道二阶MIMO响应，估计器只收到X/Y。\n');
    fprintf(fid, '因果逆FIR %d taps，固定延迟%d样点，留出复误差%.6g。\n', ...
        cfg.tap_count, cal.latency_samples, cal.holdout.relative_complex_error);
    fprintf(fid, '留出最大幅度误差%.6g dB、相位误差%.6g deg；数字全频域峰值逆增益%.6g。\n', ...
        cal.holdout.max_amplitude_error_db, cal.holdout.max_phase_error_deg, cal.implemented_peak_gain);
    fprintf(fid, '域仅range=2、T=25°C、P=-30dBm及[-10,10]MHz，未伪造温度/功率扫域。\n\n');
    fprintf(fid, '## 不确定度\n\n26个声明的合成标准不确定度及完整协方差；相关H/V增益、相位与方向图系数0.8。\n');
    fprintf(fid, '源顺序见uncertainty_sources.csv；输入协方差、Jacobian与输出协方差均可复算。\n');
    fprintf(fid, '功率取H极化；RCS方程为pH+40log10((R+dr)/R)-2(patternH+sH*attitude)。\n');
    fprintf(fid, 'delay=2dr/c+clock+cable+estimator；frequency=standard+oscillator+estimator。\n');
    fprintf(fid, 'ZDR=pH-pV+estimator，PhiDP=phaseH-phaseV+estimator；共同项按协方差抵消。\n');
    fprintf(fid, '其余完整方程见metrology_budget.m；R=1000m，方向图斜率H/V=0.05/0.03 dB/deg。\n');
    fprintf(fid, '扩展不确定度U=k*u，k=2对应正态近似95.45%%，不表示实测覆盖资格。\n');
    fprintf(fid, '20000次固定seed=7741蒙特卡洛使用非线性RCS距离项，和一阶解析预算比较。\n\n');
    fprintf(fid, '|量|标准u|扩展U|MC标准u|\n|---|---:|---:|---:|\n');
    for k = 1:6
        fprintf(fid, '|%s|%.8g|%.8g|%.8g|\n', budget.output_names(k), budget.standard(k), ...
            budget.expanded(k), budget.mc_standard(k));
    end

    disp(cal.holdout);
    disp(budget.output_table);
end
