function [out, st] = combine_complex_paths(in, paths, st, grid)
    % COMBINE_COMPLEX_PATHS 对各路径实施因果线性分数延迟和复Jones叠加。
    % 线性插值仅准确表示低于Nyquist且带宽受限的包络；靠近Nyquist时会有幅相误差。

    validateattributes(in, {'numeric'}, {'finite', 'ncols', 2});
    validateattributes(grid.fs_Hz, {'numeric'}, {'real', 'finite', 'positive', 'scalar'});
    if isempty(paths)
        out = zeros(size(in), 'like', complex(in));
        st.history = zeros(0, 2, 'like', complex(in));
        return
    end

    delaySamples = [paths.delay_s] * grid.fs_Hz;
    if any(delaySamples < 0) || any(~isfinite(delaySamples))
        error('rtsim:channel:InvalidDelay', '路径延迟必须为有限非负数。');
    end

    needed = max(ceil(delaySamples) + 1);
    history = field_or(st, 'history', zeros(0, 2, 'like', complex(in)));
    if size(history, 1) < needed
        history = [zeros(needed - size(history, 1), 2, 'like', complex(in)); history];
    elseif size(history, 1) > needed
        history = history(end - needed + 1:end, :);
    end

    extended = [history; in];
    H = size(history, 1);
    N = size(in, 1);
    out = zeros(N, 2, 'like', complex(in));
    for k = 1:numel(paths)
        d = delaySamples(k);
        m = floor(d);
        frac = d - m;
        index = (H + (1:N) - m).';
        delayed = (1 - frac) * extended(index, :) + frac * extended(index - 1, :);
        out = out + delayed * paths(k).matrix.';
    end

    st.history = extended(max(1, end - needed + 1):end, :);
    st.delay_samples = delaySamples;
    st.interpolation = 'CAUSAL_LINEAR';
    st.bandwidth_note = '线性分数延迟在接近Nyquist时存在幅度下垂和相位误差。';
end

function value = field_or(s, name, default)
    if isfield(s, name)
        value = s.(name);
    else
        value = default;
    end
end
