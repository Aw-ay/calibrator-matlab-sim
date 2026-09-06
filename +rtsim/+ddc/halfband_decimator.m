function [out, st, diag] = halfband_decimator(in, st, filterCfg)
%HALFBAND_DECIMATOR 有状态 FIR 后抽取；任意块切分保持一致。
arguments
    in {mustBeNumeric}
    st struct
    filterCfg struct
end
assert(isfield(filterCfg, 'coefficients') && isfield(filterCfg, 'decimation'), ...
    'rtsim:ddc:InvalidDecimatorConfig', '必须配置 coefficients 和 decimation。');
b = double(filterCfg.coefficients(:).');
d = double(filterCfg.decimation);
assert(~isempty(b) && all(isfinite(b)) && isscalar(d) && d >= 1 && d == fix(d), ...
    'rtsim:ddc:InvalidDecimatorConfig', '系数必须有限，decimation 必须为正整数。');
inputSize = size(in);
x = reshape(double(in), inputSize(1), []);
zi = localField(st, 'zi', complex(zeros(max(numel(b)-1, 0), size(x, 2))));
assert(isequal(size(zi), [max(numel(b)-1, 0), size(x, 2)]), ...
    'rtsim:ddc:StateShapeMismatch', 'FIR 状态与当前通道布局不一致。');
[filtered, zf] = filter(b, 1, x, zi, 1);
startCount = localField(st, 'sample_count', uint64(0));
keep = mod(double(mod(startCount, uint64(d))) + (0:inputSize(1)-1), d) == 0;
outSize = inputSize; outSize(1) = sum(keep);
out = reshape(filtered(keep, :), outSize);
st.zi = zf;
st.sample_count = startCount + uint64(inputSize(1));
st.decimation_phase = mod(st.sample_count, uint64(d));
diag = struct('group_delay_input_samples', (numel(b)-1)/2, ...
    'decimation', d, 'scale', sum(b), 'model_scope', "FLOATING_POINT_FIR_REFERENCE");
end

function value = localField(s, name, defaultValue)
if isfield(s, name), value = s.(name); else, value = defaultValue; end
end
