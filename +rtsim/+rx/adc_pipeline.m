function [codes, st, diag] = adc_pipeline(analogSignal, st, cfgAdc, clockTruth)
    % ADC_PIPELINE 复包络 ADC 基线模型，输出反量化幅度而非真实 RF 实 ADC 流。

    arguments
        analogSignal {mustBeNumeric}
        st struct
        cfgAdc struct
        clockTruth = [] %#ok<INUSA>
    end

    fidelity = string(localField(cfgAdc, 'fidelity', "ENVELOPE"));
    if fidelity ~= "ENVELOPE"
        error('rtsim:rx:UnsupportedAdcFidelity', ...
            '基础模型只支持 ENVELOPE；不宣称真实 RF 实采样、交织或 bit-true ADC。');
    end

    [iCode, qCode, flags] = rtsim.rx.adc_clip_round(analogSignal, cfgAdc);
    codes = double(iCode) * flags.lsb + 1i * double(qCode) * flags.lsb;
    st.sample_count = localField(st, 'sample_count', uint64(0)) + uint64(size(analogSignal, 1));
    diag = struct('i_code', iCode, 'q_code', qCode, 'clipped', flags.clipped, ...
        'lsb', flags.lsb, 'model_scope', "COMPLEX_ENVELOPE_EQUIVALENT", ...
        'input_description', "N×2×3 complex envelope; not RF real ADC samples");
end

function value = localField(s, name, defaultValue)
    if isfield(s, name)
        value = s.(name);
    else
        value = defaultValue;
    end
end
