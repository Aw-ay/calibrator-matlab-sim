function cuts = restore_cuts_absolute_gain(normalizedCuts, gainReference)
    % RESTORE_CUTS_ABSOLUTE_GAIN 在参考口径充分时恢复绝对实现增益。

    referenceType = upper(string(gainReference.reference_type));
    reference_dBi = gainReference.value_dBi;
    if referenceType == "DIRECTIVITY"
        if ~isfield(gainReference, 'efficiency_linear')
            error('rtsim:pattern:MissingEfficiency', '方向性不能在缺少效率时称为实现增益。');
        end

        efficiency = gainReference.efficiency_linear;
        validateattributes(efficiency, {'numeric'}, {'real', 'finite', 'positive', '<=', 1, 'scalar'});
        reference_dBi = reference_dBi + 10 * log10(efficiency);
    elseif ~ismember(referenceType, ["REALIZED_GAIN", "GAIN"])
        error('rtsim:pattern:ReferenceType', '未知绝对增益参考口径。');
    end

    cuts = normalizedCuts;
    if isfield(normalizedCuts, 'amplitude_linear')
        peak = max(abs(normalizedCuts.amplitude_linear), [], 'all');
        if peak <= 0
            error('rtsim:pattern:ZeroCut', '归一化切面峰值必须大于零。');
        end

        cuts.amplitude_linear = normalizedCuts.amplitude_linear / peak * 10^(reference_dBi / 20);
        cuts.realized_gain_dBi = 20 * log10(abs(cuts.amplitude_linear));
    elseif isfield(normalizedCuts, 'gain_dB_normalized')
        cuts.realized_gain_dBi = normalizedCuts.gain_dB_normalized - ...
            max(normalizedCuts.gain_dB_normalized, [], 'all') + reference_dBi;
        cuts.amplitude_linear = 10.^(cuts.realized_gain_dBi / 20);
    else
        error('rtsim:pattern:MissingAmplitude', '切面缺少归一化幅度或dB增益。');
    end

    cuts.absolute_reference = struct('type', 'REALIZED_GAIN', 'peak_dBi', reference_dBi, ...
        'source_reference_type', char(referenceType));
end
