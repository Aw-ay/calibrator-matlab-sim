function [out, st, diag] = apply_tx_cal(desiredPortIQ, st, calTx, context)
    % APPLY_TX_CAL 对所有TX源使用同一组估计预补偿系数。

    arguments
        desiredPortIQ (:, 2) double
        st (1, 1) struct
        calTx (1, 1) struct
        context (1, 1) struct %#ok<INUSA>
    end

    out = desiredPortIQ * calTx.coefficients.';
    diag.calibration_id = calTx.id;
    diag.peak = max(abs(out), [], 'all');
    diag.model_scope = "frequency-flat matrix correction";
end
