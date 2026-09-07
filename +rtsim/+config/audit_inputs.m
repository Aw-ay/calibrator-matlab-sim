function audit = audit_inputs(projectRoot, cfg)
    % 记录资料缺失，不用理想天线替代实测天线资格。

    audit.model = '假设复包络参考模型';
    audit.profile = cfg.profile;
    audit.project_root = projectRoot;
    audit.pattern_status = 'BLOCKED_MISSING_DATA';
    audit.calibration_status = 'SYNTHETIC_MEASUREMENTS';
    audit.hardware_status = 'BLOCKED_MISSING_DATA';
    audit.missing = {'实测全极化复方向图', '独立实测 RX/TX 校准数据', '精确板卡与 RTL 配置', '原文 assets 图像'};
    if isfield(cfg, 'antenna') && strcmpi(cfg.antenna.pattern.kind, 'CST_FARFIELD')
        audit.pattern_status = 'PARTIAL_EXCITATION_FIELD_PENDING_METADATA';
        audit.pattern_note = '已提供2.8GHz联合HV激励场；相对激励幅相、极化基和独立激励场待确认。';
    end
end
