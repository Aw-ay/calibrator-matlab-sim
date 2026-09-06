function [out, st, diag] = channel_alignment_step(in, st, cfgAlign)
    % CHANNEL_ALIGNMENT_STEP 对已核对布局的各列施加非负整数样点延迟。

    arguments
        in {mustBeNumeric}
        st struct
        cfgAlign struct
    end

    if ~isfield(cfgAlign, 'verified_layout') || ~cfgAlign.verified_layout || ...
            ~isfield(cfgAlign, 'integer_delay_samples')
        error('rtsim:time:UnsupportedAlignment', '必须明确并核对通道布局和逐通道整数延迟。');
    end

    inputSize = size(in);
    x = reshape(in, inputSize(1), []);
    delays = double(cfgAlign.integer_delay_samples(:).');
    assert(numel(delays) == size(x, 2) && all(delays >= 0) && all(delays == fix(delays)), ...
        'rtsim:time:InvalidAlignment', '延迟必须是与通道数一致的非负整数。');
    history = localField(st, 'history', cell(1, size(x, 2)));
    y = zeros(size(x), 'like', x);
    for k = 1:size(x, 2)
        d = delays(k);
        if d == 0
            y(:, k) = x(:, k);
            history{k} = zeros(0, 1, 'like', x);
        else
            h = history{k};
            if isempty(h)
                h = zeros(d, 1, 'like', x);
            end

            assert(numel(h) == d, 'rtsim:time:AlignmentStateMismatch', '延迟状态与配置不一致。');
            joined = [h(:); x(:, k)];
            y(:, k) = joined(1:size(x, 1));
            history{k} = joined(end - d + 1:end);
        end
    end

    out = reshape(y, inputSize);
    st.history = history;
    st.sample_count = localField(st, 'sample_count', uint64(0)) + uint64(inputSize(1));
    diag = struct('integer_delay_samples', delays, 'sample_slip', false, ...
        'hardware_equivalent', false, 'model_scope', "DECLARED_INTEGER_DELAY_ONLY");
end

function value = localField(s, name, defaultValue)
    if isfield(s, name)
        value = s.(name);
    else
        value = defaultValue;
    end
end
