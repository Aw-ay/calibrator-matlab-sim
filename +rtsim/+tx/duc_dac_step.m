function [analog, st, diag] = duc_dac_step(baseband, st, cfgDac, clockTruth)
    % DUC_DAC_STEP 复包络NCO与均匀DAC量化行为基线。

    arguments
        baseband (:, 2) double
        st (1, 1) struct
        cfgDac (1, 1) struct
        clockTruth (1, 1) struct
    end

    need(cfgDac, {'bits', 'full_scale', 'nco_frequency_Hz', 'phase0_rad', 'valid', 'safe_value'});
    need(clockTruth, {'frequency_error_Hz', 'fs_Hz'});
    bits = double(cfgDac.bits);
    fullScale = double(cfgDac.full_scale);
    validConfig = isscalar(bits) && isfinite(bits) && bits == fix(bits) && bits >= 2 && bits <= 31 && ...
        isscalar(fullScale) && isfinite(fullScale) && fullScale > 0 && ...
        isscalar(clockTruth.fs_Hz) && isfinite(clockTruth.fs_Hz) && clockTruth.fs_Hz > 0 && ...
        isscalar(cfgDac.nco_frequency_Hz) && isfinite(cfgDac.nco_frequency_Hz) && ...
        isscalar(clockTruth.frequency_error_Hz) && isfinite(clockTruth.frequency_error_Hz) && ...
        isscalar(cfgDac.phase0_rad) && isfinite(cfgDac.phase0_rad) && ...
        isscalar(cfgDac.safe_value) && isfinite(cfgDac.safe_value) && isscalar(cfgDac.valid);
    if ~validConfig
        error('rtsim:tx:InvalidDacConfig', ...
            'bits须为2到31整数，full_scale与fs_Hz须为有限正数，其余标量须有限。');
    end

    if ~isfield(st, 'sample_index')
        st.sample_index = 0;
    end

    n = size(baseband, 1);
    if ~logical(cfgDac.valid)
        analog = complex(ones(size(baseband)) * cfgDac.safe_value);
        diag.quantized = false;
        diag.muted = true;
        diag.quantization_step = fullScale / 2^(bits - 1);
        diag.clipped_samples = 0;
    else
        indices = st.sample_index + (0:n - 1)';
        phase = cfgDac.phase0_rad + 2 * pi * (cfgDac.nco_frequency_Hz + ...
            clockTruth.frequency_error_Hz) .* indices / clockTruth.fs_Hz;
        mixed = baseband .* exp(1i * phase);
        [iCode, qCode, flags] = rtsim.rx.adc_clip_round(mixed, ...
            struct('bits', bits, 'full_scale', fullScale));
        analog = complex(double(iCode), double(qCode)) * flags.lsb;
        diag.quantized = true;
        diag.muted = false;
        diag.quantization_step = flags.lsb;
        diag.clipped_samples = nnz(flags.clipped);
    end

    st.sample_index = st.sample_index + n;
    diag.model_scope = "signed two's-complement complex-envelope quantizer";
end

function need(s, n)
    for k = 1:numel(n)
        if ~isfield(s, n{k})
            error('rtsim:tx:MissingField', '缺少必需字段%s。', n{k});
        end
    end
end
