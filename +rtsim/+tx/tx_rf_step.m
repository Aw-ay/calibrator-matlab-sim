function [portOut, monitorTap, st, diag] = tx_rf_step(dacSignal, st, cfgRf, plantCond)
    % TX_RF_STEP 二维频率平坦RF响应、硬限幅与无记忆AM/PM基线。

    arguments
        dacSignal (:, 2) double
        st (1, 1) struct
        cfgRf (1, 1) struct
        plantCond (1, 1) struct
    end

    need(cfgRf, {'response_matrix', 'voltage_gain', 'saturation_amplitude', ...
        'ampm_rad_at_saturation', 'monitor_coupling'});
    need(plantCond, {'gain_scale'});
    linear = dacSignal * cfgRf.response_matrix.' * cfgRf.voltage_gain * plantCond.gain_scale;
    amplitude = abs(linear);
    normalized = amplitude / cfgRf.saturation_amplitude;
    limited = min(amplitude, cfgRf.saturation_amplitude);
    phaseShift = cfgRf.ampm_rad_at_saturation * min(normalized, 1);
    portOut = limited .* exp(1i * (angle(linear) + phaseShift));
    portOut(amplitude == 0) = 0;
    monitorTap = cfgRf.monitor_coupling * portOut;
    diag.clipped = any(amplitude > cfgRf.saturation_amplitude, 'all');
    diag.clipped_samples = nnz(amplitude > cfgRf.saturation_amplitude);
    diag.peak_linear = max(amplitude, [], 'all');
    diag.model_scope = "memoryless flat 2x2 RF gain, clipping and AM-PM";
    st.last_peak = max(abs(portOut), [], 'all');
end

function need(s, n)
    for k = 1:numel(n)
        if ~isfield(s, n{k})
            error('rtsim:tx:MissingField', '缺少必需字段%s。', n{k});
        end
    end
end
