function [out, st] = nco_mixer(in, st, cfgNco, grid)
    % NCO_MIXER 跨块连续的复数 NCO 混频器。

    arguments
        in {mustBeNumeric}
        st struct
        cfgNco struct
        grid struct
    end

    required = {'frequency_Hz', 'phase0_rad', 'sign'};
    assert(all(isfield(cfgNco, required)) && isfield(grid, 'fs_Hz'), ...
        'rtsim:ddc:InvalidNcoConfig', 'NCO 配置或采样率字段不完整。');
    assert(any(cfgNco.sign == [-1 1]), 'rtsim:ddc:InvalidNcoConfig', 'sign 只能为 -1 或 +1。');
    phase = localField(st, 'phase_rad', double(cfgNco.phase0_rad));
    increment = double(cfgNco.sign) * 2 * pi * double(cfgNco.frequency_Hz) / double(grid.fs_Hz);
    n = (0:size(in, 1) - 1).';
    osc = exp(1i * (phase + increment .* n));
    shape = ones(1, ndims(in));
    shape(1) = numel(osc);
    out = double(in) .* reshape(osc, shape);
    st.phase_rad = mod(phase + increment * size(in, 1) + pi, 2 * pi) - pi;
    st.sample_count = localField(st, 'sample_count', uint64(0)) + uint64(size(in, 1));
end

function value = localField(s, name, defaultValue)
    if isfield(s, name)
        value = s.(name);
    else
        value = defaultValue;
    end
end
