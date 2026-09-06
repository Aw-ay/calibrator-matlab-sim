function [aligned, st, diag] = model_mts(in, st, cfgMts, startupState)
    % MODEL_MTS MTS 行为边界：只接受明确禁用，不模拟真实 RFDC 同步。

    arguments
        in
        st struct
        cfgMts struct
        startupState = [] %#ok<INUSA>
    end

    if ~isfield(cfgMts, 'enabled')
        error('rtsim:time:UnsupportedMts', ...
            '未提供板卡 tile、目标时延和实测残差，不能声明真实 MTS 行为。');
    end

    if ~cfgMts.enabled
        aligned = in;
        diag = struct('enabled', false, 'model_scope', "MTS_DISABLED_PASS_THROUGH", ...
            'hardware_equivalent', false);
        return
    end

    if ~isfield(cfgMts, 'mode') || string(cfgMts.mode) ~= "BEHAVIORAL_RESIDUAL"
        error('rtsim:time:UnsupportedMts', ...
            '只支持显式 BEHAVIORAL_RESIDUAL；不能声明真实 RFDC MTS 操作。');
    end

    alignCfg = struct('integer_delay_samples', cfgMts.integer_delay_samples, ...
        'verified_layout', cfgMts.verified_layout);
    [aligned, st, alignDiag] = rtsim.time.channel_alignment_step(in, st, alignCfg);
    diag = alignDiag;
    diag.enabled = true;
    diag.model_scope = "BEHAVIORAL_MTS_INTEGER_RESIDUAL_ONLY";
end
