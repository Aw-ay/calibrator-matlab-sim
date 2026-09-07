function cfg = design_pl_filter(fs, decimation, bandwidth)
    % 基础 MATLAB 的 Blackman 窗低通；正式档通带±10M、阻带31.25M起。

    if decimation == 1
        h = 1;
    else
        pass = bandwidth / 2;
        stop = fs / decimation / 2;
        order = ceil(6 * fs / (stop - pass));
        order = ceil(order / (2 * decimation)) * (2 * decimation);
        n = (-order / 2:order / 2);
        fc = (pass + stop) / 2 / fs;
        h = 2 * fc * ones(size(n));
        ix = n ~= 0;
        h(ix) = sin(2 * pi * fc * n(ix)) ./ (pi * n(ix));
        w = 0.42 - 0.5 * cos(2 * pi * (0:order) / order) + 0.08 * cos(4 * pi * (0:order) / order);
        h = h .* w;
        h = h / sum(h);
    end

    cfg = struct('coefficients', h, 'decimation', decimation, 'passband_Hz', bandwidth / 2, ...
        'stopband_Hz', fs / decimation / 2, 'max_passband_ripple_dB', 0.1, 'min_stopband_attenuation_dB', 60);
end
