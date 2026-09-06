function [iCode, qCode, flags] = adc_clip_round(signal, cfgQuant)
%ADC_CLIP_ROUND 复包络等效量化；分别输出 I/Q 有符号码字。
arguments
    signal {mustBeNumeric}
    cfgQuant struct
end
assert(isfield(cfgQuant, 'bits') && isfield(cfgQuant, 'full_scale'), ...
    'rtsim:rx:InvalidQuantizer', '量化配置必须包含 bits 和 full_scale。');
bits = double(cfgQuant.bits);
fullScale = double(cfgQuant.full_scale);
assert(isscalar(bits) && bits >= 2 && bits <= 31 && bits == fix(bits), ...
    'rtsim:rx:InvalidQuantizer', 'bits 必须是 2 到 31 的整数。');
assert(isscalar(fullScale) && isfinite(fullScale) && fullScale > 0, ...
    'rtsim:rx:InvalidQuantizer', 'full_scale 必须是有限正数，表示单个 I/Q 分量的峰值。');

scale = 2^(bits - 1) / fullScale;
minCode = -2^(bits - 1);
maxCode = 2^(bits - 1) - 1;
iRaw = round(real(double(signal)) * scale);
qRaw = round(imag(double(signal)) * scale);
iClip = iRaw < minCode | iRaw > maxCode;
qClip = qRaw < minCode | qRaw > maxCode;
iCode = int32(min(max(iRaw, minCode), maxCode));
qCode = int32(min(max(qRaw, minCode), maxCode));
flags = struct('clipped', iClip | qClip, 'i_clipped', iClip, ...
    'q_clipped', qClip, 'lsb', fullScale / 2^(bits - 1), ...
    'model_scope', "COMPLEX_ENVELOPE_EQUIVALENT");
end
