function [out, diag] = fixedpoint_model(in, arithmeticSpec)
%FIXEDPOINT_MODEL 单个已声明量化级的浮点参考，不冒充整链 bit-true。
arguments
    in {mustBeNumeric}
    arithmeticSpec struct
end
if isfield(arithmeticSpec, 'bit_true') && arithmeticSpec.bit_true
    error('rtsim:ddc:UnsupportedBitTrue', ...
        '本实现不是逐级 bit-true；请提供每级乘加、截位和溢出规范。');
end
required = {'word_length','fraction_length','rounding','overflow'};
if ~all(isfield(arithmeticSpec, required))
    error('rtsim:ddc:IncompleteArithmeticSpec', '必须明确 word_length、fraction_length、rounding 和 overflow。');
end
wl = double(arithmeticSpec.word_length);
fl = double(arithmeticSpec.fraction_length);
assert(wl >= 2 && wl <= 53 && fl >= 0 && wl == fix(wl) && fl == fix(fl), ...
    'rtsim:ddc:InvalidArithmeticSpec', '位宽配置超出可证明的 double 整数精度范围。');
scaled = double(in) * 2^fl;
switch upper(string(arithmeticSpec.rounding))
    case "NEAREST", quantized = round(scaled);
    case "FLOOR", quantized = floor(scaled);
    case "FIX", quantized = fix(scaled);
    otherwise, error('rtsim:ddc:InvalidArithmeticSpec', '不支持的舍入方式。');
end
lo = -2^(wl-1); hi = 2^(wl-1)-1;
overflowed = real(quantized) < lo | real(quantized) > hi | imag(quantized) < lo | imag(quantized) > hi;
switch upper(string(arithmeticSpec.overflow))
    case "SATURATE"
        quantized = min(max(real(quantized), lo), hi) + 1i*min(max(imag(quantized), lo), hi);
    otherwise
        error('rtsim:ddc:UnsupportedOverflow', '基础模型只证明 SATURATE，不提供 wrap 的 bit-true 声明。');
end
out = quantized / 2^fl;
diag = struct('overflowed', overflowed, 'model_scope', "ONE_EXPLICIT_QUANTIZATION_STAGE");
end
