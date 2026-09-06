function [qual, st] = range_qualifier_step(rangeIQ, detectorEvents, st, cfgQual)
    % 在线累积每档两个极化的峰值，不使用真实 RF 压缩标志。

    if ~isfield(st, 'peak')
        st.peak = zeros(1, 3);
        st.samples = 0;
    end

    peak = reshape(max(max(max(abs(real(rangeIQ)), abs(imag(rangeIQ))), [], 1), [], 2), 1, 3);
    st.peak = max(st.peak, peak);
    st.samples = st.samples + size(rangeIQ, 1);
    qual = struct('peak', st.peak, 'samples', st.samples, 'valid', st.peak < cfgQual.limit);
    if ~isempty(detectorEvents)
        st.peak = zeros(1, 3);
        st.samples = 0;
    end
end
