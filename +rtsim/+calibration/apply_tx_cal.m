function [out, st, diag] = apply_tx_cal(desiredPortIQ, st, calTx, context)
    % APPLY_TX_CAL 对所有TX源使用同一组估计预补偿系数。

    arguments
        desiredPortIQ (:, 2) double
        st (1, 1) struct
        calTx (1, 1) struct
        context (1, 1) struct
    end

    if isfield(calTx, 'wideband')
        enabled = ~isfield(context, 'enabled') || context.enabled;
        if ~isfield(st, 'wideband')
            st.wideband = [];
        end

        if enabled
            [desiredPortIQ, st.wideband] = rtsim.calibration.apply_mimo_fir( ...
                desiredPortIQ, st.wideband, calTx.wideband.coeff);
        else

            % 安全门后静音并清空历史，恢复使能时不得泄漏先前脉冲尾巴。

            desiredPortIQ(:) = 0;
            st.wideband = [];
        end
    end

    out = desiredPortIQ * calTx.coefficients.';
    diag.calibration_id = calTx.id;
    diag.peak = max(abs(out), [], 'all');
    diag.model_scope = "frequency-flat matrix correction";
    if isfield(calTx, 'wideband')
        diag.model_scope = "frequency-dependent causal MIMO FIR before static TX correction";
        diag.fixed_latency_samples = calTx.wideband.latency_samples;
    end
end
