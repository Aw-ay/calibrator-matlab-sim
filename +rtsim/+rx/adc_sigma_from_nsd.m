function budget = adc_sigma_from_nsd(nsdSpec, reference, includedSources)
    % ADC_SIGMA_FROM_NSD 将单边 dBFS/Hz 噪声密度换算成带内方差。

    arguments
        nsdSpec struct
        reference struct
        includedSources struct
    end

    required = {'nsd_dBFS_per_Hz', 'bandwidth_Hz'};
    assert(all(isfield(nsdSpec, required)) && isfield(reference, 'full_scale_rms'), ...
        'rtsim:rx:InvalidNsdSpec', '必须明确单边 nsd_dBFS_per_Hz、积分带宽和 full_scale_rms。');
    assert(nsdSpec.bandwidth_Hz > 0 && reference.full_scale_rms > 0, ...
        'rtsim:rx:InvalidNsdSpec', '带宽和 RMS 满量程必须为正。');
    totalVariance = reference.full_scale_rms^2 * 10^(nsdSpec.nsd_dBFS_per_Hz / 10) * nsdSpec.bandwidth_Hz;
    included = double(localField(includedSources, 'variance', 0));
    residual = totalVariance - included;
    if residual < -64 * eps(max(totalVariance, included))
        error('rtsim:rx:IncompatibleNoiseBudget', '已包含噪声方差超过总 NSD 带内预算。');
    end

    residual = max(residual, 0);
    budget = struct('total_variance', totalVariance, 'included_variance', included, ...
        'residual_variance', residual, 'residual_sigma', sqrt(residual), ...
        'convention', "ONE_SIDED_DBFS_PER_HZ_REFERENCED_TO_RMS_FULL_SCALE");
end

function value = localField(s, name, defaultValue)
    if isfield(s, name)
        value = s.(name);
    else
        value = defaultValue;
    end
end
