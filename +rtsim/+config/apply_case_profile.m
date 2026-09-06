function cfg = apply_case_profile(cfg, profileName)
% 场景只覆盖明确列出的参数，机载场景继续复用同一仪器链。
cfg.profile=char(profileName);
switch upper(char(profileName))
    case {'ALGORITHM_SMOKE','A0','B0','AIRBORNE_REGRESSION'}
    case {'A1','CABLE'}
        cfg.channel.kind='CABLE'; cfg.target.gain=1;
    case {'B1','FLIGHT'}
        cfg.platform.velocity_mps=[10;0;0]; cfg.platform.roll_deg=8;
        cfg.navigation.delay_s=0.5e-3; cfg.navigation.position_bias_m=[0.01;0;0];
        cfg.environment.ambient_C=45; cfg.environment.body_rcs_m2=0.1;
    case 'BOARD_EQUIVALENT'
        error('rtsim:MissingBoardData','缺少精确板卡、RFDC、时钟与 RTL 配置，不能生成等效板卡档。');
    otherwise
        error('rtsim:Profile','未知场景：%s',profileName);
end
end
