function [out, st] = adc_apply_interleave_spurs(in, st, mismatch, mode)
%ADC_APPLY_INTERLEAVE_SPURS 应用显式周期增益、偏置和相位失配的包络等效模型。
arguments
    in {mustBeNumeric}
    st struct
    mismatch struct
    mode {mustBeTextScalar}
end
if string(mode) ~= "ENVELOPE_EQUIVALENT"
    error('rtsim:rx:UnsupportedInterleaveMode', '未实现物理子 ADC 非均匀采样，只支持包络等效失配。');
end
required = {'gain','offset','phase_rad'};
assert(all(isfield(mismatch, required)), 'rtsim:rx:InvalidInterleaveSpec', '交织失配字段不完整。');
m = numel(mismatch.gain);
assert(m > 0 && numel(mismatch.offset)==m && numel(mismatch.phase_rad)==m, ...
    'rtsim:rx:InvalidInterleaveSpec', '各交织相位参数长度必须一致。');
start = double(localField(st, 'phase_index', uint64(0)));
idx = mod(start + (0:size(in,1)-1), m) + 1;
gain = mismatch.gain(idx).' .* exp(1i*mismatch.phase_rad(idx).');
offset = mismatch.offset(idx).';
out = double(in) .* reshape(gain, [size(in,1) ones(1,ndims(in)-1)]) + ...
    reshape(offset, [size(in,1) ones(1,ndims(in)-1)]);
st.phase_index = uint64(mod(start + size(in,1), m));
end

function value = localField(s, name, defaultValue)
if isfield(s, name), value = s.(name); else, value = defaultValue; end
end
