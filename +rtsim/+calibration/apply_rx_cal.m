function [out, st, diag] = apply_rx_cal(selectedRaw, st, calRx, context)
    % APPLY_RX_CAL 按量程使用估计系数恢复RP1处H/V功率波。

    arguments
        selectedRaw (:, 2) double
        st (1, 1) struct
        calRx (1, 1) struct
        context (1, 1) struct
    end

    if ~isfield(context, 'range_id') || ~ismember(context.range_id, 1:3)
        error('rtsim:calibration:InvalidRange', 'context.range_id必须为1、2或3。');
    end

    rangeId = context.range_id;
    out = selectedRaw * calRx.coefficients(:, :, rangeId).';
    diag.calibration_id = calRx.id;
    diag.range_id = rangeId;
    diag.model_scope = "frequency-flat matrix correction";
    if isfield(calRx, 'wideband')
        if ~isfield(context, 'capture_complete') || ~context.capture_complete
            error('rtsim:calibration:WidebandCaptureRequired', '宽带RX仅支持整捕获完成后的因果滤波及延迟裁剪。');
        end

        w = calRx.wideband;
        latency = w.latency_samples;
        padded = [out; zeros(latency, 2)];
        corrected = rtsim.calibration.apply_mimo_fir(padded, [], w.coeff);
        out = corrected(latency + (1:size(out, 1)), :);
        diag.model_scope = "frequency-dependent causal MIMO FIR after completed capture";
        diag.removed_fixed_latency_samples = latency;
    end
end
