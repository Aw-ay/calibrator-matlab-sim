function result = run_array_demo(output_dir)
    % 阵列合成验证示例；无实测AEP、噪声温度或硬件验收资格。

    root = fileparts(mfilename('fullpath'));
    if nargin < 1
        output_dir = fullfile(root, 'results', ['ARRAY_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    fc = 3e9;
    cfg = rtsim.radar_array.default_array_config(fc);
    n = size(cfg.positions_m, 1);
    k = (1:n)';
    cfg.tx_error = [(1 + .12 * sin(k)) .* exp(.25i * cos(k)), (1 + .09 * cos(k)) .* exp(-.2i * sin(k))];
    cfg.rx_error = [(1 + .08 * cos(k)) .* exp(-.18i * k / n), (1 + .11 * sin(k)) .* exp(.3i * k / n)];

    % 正交馈入编码从实际阵元模型生成测量；求解器完全不接触真值配置。

    m = 2 * n;
    design = exp(2i * pi * (0:m - 1)' * (0:n - 1) / m) / sqrt(n);
    holdout_design = exp(2i * pi * ((.37:m - .63)' / m) * (0:n - 1)) / sqrt(n);
    [ytx, yrx] = measure_codes(cfg, design, fc);
    [htx, hrx] = measure_codes(cfg, holdout_design, fc);
    txfit = rtsim.radar_array.array_calibration_solver(design, ytx, 1e-10);
    rxfit = rtsim.radar_array.array_calibration_solver(design, yrx, 1e-10);
    result.calibration.tx_holdout_before = norm(htx - holdout_design * ones(n, 2), 'fro') / norm(htx, 'fro');
    result.calibration.rx_holdout_before = norm(hrx - holdout_design * ones(n, 2), 'fro') / norm(hrx, 'fro');
    result.calibration.tx_holdout_after = ...
        norm(htx - holdout_design * txfit.channel_response, 'fro') / norm(htx, 'fro');
    result.calibration.rx_holdout_after = ...
        norm(hrx - holdout_design * rxfit.channel_response, 'fro') / norm(hrx, 'fro');
    corrected = cfg;
    corrected.weights_tx = 1 ./ txfit.channel_response;
    corrected.weights_rx = conj(1 ./ rxfit.channel_response);

    % 可辨识通道误差演示后再加入合成嵌入式方向图，显式保留残余极化扫描效应。

    cfg.aep_direction_slope = [.04 + .08i + zeros(n, 1), -.05 - .06i + zeros(n, 1)];
    corrected.aep_direction_slope = cfg.aep_direction_slope;
    az = -90:.2:90;
    scan = [0 25];
    power_before = zeros(numel(az), 2);
    power_after = zeros(numel(az), 2);
    for s = 1:2
        cfg.steer_az_deg = scan(s);
        corrected.steer_az_deg = scan(s);
        for q = 1:numel(az)
            u = [cosd(az(q)); sind(az(q)); 0];
            j = rtsim.radar_array.array_response(cfg, u, fc, 0);
            jc = rtsim.radar_array.array_response(corrected, u, fc, 0);
            power_before(q, s) = abs(j(1, 1))^2;
            power_after(q, s) = abs(jc(1, 1))^2;
        end

        result.beams(s).command_az_deg = scan(s);
        result.beams(s).before = rtsim.radar_array.beam_cut_metrics(az, power_before(:, s));
        result.beams(s).after = rtsim.radar_array.beam_cut_metrics(az, power_after(:, s));
        [~, ~, info] = rtsim.radar_array.array_response(corrected, [cosd(scan(s)); sind(scan(s)); 0], fc, 0);
        result.beams(s).polarization_and_power = info;
    end

    result.qualification = 'SYNTHETIC_FIXTURE_NOT_MEASURED_AEP_OR_HARDWARE_ACCEPTANCE';
    result.calibration.qualification = '独立正交编码训练与偏移编码留出；仅通道复增益拟合';
    result.noise_qualification = '未提供真实系统噪声温度，G/T保持NaN';
    result.normalization = '每输入极化总馈入功率1W；Rx白噪声权范数1；校正后重新归一化';
    result.output_dir = output_dir;
    save(fullfile(output_dir, 'array_demo.mat'), 'result', 'cfg', 'corrected', 'az', 'power_before', 'power_after', ...
        'design', 'holdout_design', 'ytx', 'yrx', 'htx', 'hrx', 'txfit', 'rxfit');
    fid = fopen(fullfile(output_dir, 'array_demo.json'), 'w', 'n', 'UTF-8');
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, jsonencode(result, 'PrettyPrint', true), 'char');
    clear cleaner;
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 700]);
    cleaner = onCleanup(@() close(fig));
    subplot(2, 1, 1);
    plot(az, 10 * log10(max(power_before, 1e-8)), '--', 'LineWidth', 1.1);
    hold on;
    plot(az, 10 * log10(max(power_after, 1e-8)), 'LineWidth', 1.4);
    grid on;
    ylim([-35 15]);
    xlabel('方位角（度）');
    ylabel('H极化方向功率（dB）');
    title('4×4半波长阵列：扫描与独立通道校准（合成数据）');
    legend('0° 校准前', '25° 校准前', '0° 校准后', '25° 校准后', 'Location', 'best');
    subplot(2, 1, 2);
    bar(20 * log10(max([result.calibration.tx_holdout_before result.calibration.tx_holdout_after; ...
        result.calibration.rx_holdout_before result.calibration.rx_holdout_after], 1e-15)));
    set(gca, 'XTickLabel', {'Tx', 'Rx'});
    grid on;
    ylabel('独立留出相对残差（dB）');
    legend('校准前', '拟合后', 'Location', 'best');
    title('独立偏移编码验证；缺实测AEP与噪声温度');
    exportgraphics(fig, fullfile(output_dir, '阵列扫描与校准.png'), 'Resolution', 150);
end

function [tx, rx] = measure_codes(plant, design, fc)
    % 真实plant仅用于生成复测量；训练和留出分别调用独立激励。

    tx = complex(zeros(size(design, 1), 2));
    rx = tx;
    for row = 1:size(design, 1)
        plant.weights_tx = repmat(design(row, :).', 1, 2);
        plant.weights_rx = conj(plant.weights_tx);
        [a, b] = rtsim.radar_array.array_response(plant, [1; 0; 0], fc, 0);
        tx(row, :) = diag(a).';
        rx(row, :) = diag(b).';
    end
end
