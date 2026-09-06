function audit = audit_inputs(projectRoot, cfg)
% 记录资料缺失，不用理想天线替代实测天线资格。
audit.model='假设复包络参考模型'; audit.profile=cfg.profile;
audit.project_root=projectRoot;
audit.pattern_status='BLOCKED_MISSING_DATA';
audit.calibration_status='SYNTHETIC_MEASUREMENTS';
audit.hardware_status='BLOCKED_MISSING_DATA';
audit.missing={'实测全极化复方向图','独立实测 RX/TX 校准数据','精确板卡与 RTL 配置','原文 assets 图像'};
end
