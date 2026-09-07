function link = ota_link_state(cfg, patterns, nominalPatterns, truth, estimate, time_s)
    % 真实传播和观测补偿分别构造；RP2采用统一ENU横向实基中的复电场。

    actual = rtsim.airborne.antenna_pose_step(truth, cfg.antenna.mounting, ...
        cfg.antenna.lever_arm_body_m, cfg.antenna.vibration);
    observed = rtsim.airborne.antenna_pose_step(estimate, cfg.antenna.mounting, ...
        cfg.antenna.lever_arm_body_m, struct());
    p = actual.phase_center_position_m(:);
    pe = observed.phase_center_position_m(:);
    [ut, ur, meta] = rtsim.pattern.build_antenna_jones(patterns, actual, -p, cfg.radar.fc_Hz);
    if size(ut, 2) == 1
        if ~cfg.antenna.excitation_mode_only || ~strcmp(cfg.target.reference_plane, 'RP1')
            error('rtsim:JointExcitationScope', '联合激励场只允许显式单模式RP1实验，不能用于完整RP2双极化补偿。');
        end

        % 第一维仅为有效联合模式，不是物理H端口；第二模式不可辨识且禁用。

        ut = [ut, zeros(2, 1)];
        ur = [ur; zeros(1, 2)];
        if norm(cfg.target.polar_matrix - diag([cfg.target.polar_matrix(1, 1), 0]), 'fro') > 1e-12
            error('rtsim:JointExcitationOperator', '单模式实验的目标算子只能使用(1,1)元素。');
        end
    end

    if any(~isfinite(ut), 'all') || any(~isfinite(ur), 'all')
        error('rtsim:PatternCoverage', '当前频率或视线超出方向图有效范围。');
    end

    [rt, rr, arrayMeta] = rtsim.radar_array.array_response(cfg.radar.array, p, cfg.radar.fc_Hz, time_s);
    switch upper(cfg.target.reference_plane)
        case 'RP1'
            operator = cfg.target.polar_matrix;
        case 'RP2_OTA'
            [et, er] = rtsim.pattern.build_antenna_jones(nominalPatterns, observed, -pe, cfg.radar.fc_Hz);
            if ~isequal(size(et), [2 2]) || any(~isfinite(et), 'all') || ...
                    min(svd(et)) < 1 / cfg.antenna.max_inverse_gain
                error('rtsim:PatternInverse', '名义Jones不完整或逆增益超限，无法执行RP2补偿。');
            end

            operator = et \ cfg.target.polar_matrix / er;
        otherwise
            error('rtsim:ReferencePlane', '目标参考面只能为RP1或RP2_OTA。');
    end

    estimate.position_m = pe;
    estimate.velocity_mps = observed.phase_center_velocity_mps(:);
    link = struct('tx_uav', ut, 'rx_uav', ur, 'tx_radar', rt, 'rx_radar', rr, ...
        'position_m', p, 'estimate', estimate, 'polar_operator', operator, ...
        'truth_pose', actual, 'estimated_pose', observed, 'pattern_meta', meta, 'array_meta', arrayMeta);
end
