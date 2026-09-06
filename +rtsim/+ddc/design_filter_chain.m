function filters = design_filter_chain(ratePlan, bandwidthSpec, arithmeticSpec)
    % DESIGN_FILTER_CHAIN 验证用户给定系数；基础版不凭名义指标自动设计滤波器。

    arguments
        ratePlan struct
        bandwidthSpec struct
        arithmeticSpec struct
    end

    requiredRate = {'input_fs_Hz', 'output_fs_Hz'};
    requiredBw = {'coefficients', 'passband_Hz', 'stopband_Hz', 'max_passband_ripple_dB', ...
        'min_stopband_attenuation_dB'};
    if ~all(isfield(ratePlan, requiredRate)) || ~all(isfield(bandwidthSpec, requiredBw))
        error('rtsim:ddc:UnprovenFilter', '必须给出采样率、系数和可检验的通阻带指标。');
    end

    b = double(bandwidthSpec.coefficients(:).');
    assert(~isempty(b) && all(isfinite(b)), 'rtsim:ddc:UnprovenFilter', '滤波器系数无效。');
    nfft = max(16384, 2^nextpow2(32 * numel(b)));
    H = fft(b, nfft);
    f = (0:nfft / 2) * ratePlan.input_fs_Hz / nfft;
    mag = abs(H(1:nfft / 2 + 1));
    magDb = 20 * log10(max(mag, realmin));
    pass = f <= bandwidthSpec.passband_Hz;
    stop = f >= bandwidthSpec.stopband_Hz;
    ripple = max(magDb(pass)) - min(magDb(pass));
    attenuation = -max(magDb(stop));
    if isempty(find(pass, 1)) || isempty(find(stop, 1)) || ...
            ripple > bandwidthSpec.max_passband_ripple_dB || attenuation < bandwidthSpec.min_stopband_attenuation_dB
        error('rtsim:ddc:UnprovenFilter', '给定系数未达到声明的通带纹波或阻带衰减。');
    end

    filters = struct('coefficients', b, 'group_delay_input_samples', (numel(b) - 1) / 2, ...
        'measured_passband_ripple_dB', ripple, 'measured_stopband_attenuation_dB', attenuation, ...
        'arithmetic_spec', arithmeticSpec, 'model_scope', "COEFFICIENT_RESPONSE_VERIFIED_FLOATING_POINT");
end
