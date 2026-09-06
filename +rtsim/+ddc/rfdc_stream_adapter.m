function [out, st, diag] = rfdc_stream_adapter(nativeStream, st, layoutCfg)
%RFDC_STREAM_ADAPTER 仅转换完整声明的数组维度顺序。
arguments
    nativeStream
    st struct
    layoutCfg struct
end
if ~isfield(layoutCfg, 'permutation') || ~isfield(layoutCfg, 'output_labels') || ...
        ~isfield(layoutCfg, 'verified') || ~layoutCfg.verified
    error('rtsim:ddc:UnsupportedRfdcLayout', ...
        '必须提供经核对的 permutation 与 output_labels；不猜测器件 lane/IQ 布局。');
end
p = double(layoutCfg.permutation);
if ~isequal(sort(p), 1:ndims(nativeStream))
    error('rtsim:ddc:UnsupportedRfdcLayout', 'permutation 不是输入维度的完整排列。');
end
out = permute(nativeStream, p);
st.sample_count = localField(st, 'sample_count', uint64(0)) + uint64(size(out, 1));
diag = struct('output_labels', {layoutCfg.output_labels}, ...
    'model_scope', "DECLARED_ARRAY_PERMUTATION_ONLY");
end

function value = localField(s, name, defaultValue)
if isfield(s, name), value = s.(name); else, value = defaultValue; end
end
