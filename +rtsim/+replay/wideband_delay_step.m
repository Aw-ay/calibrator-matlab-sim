function [out, st, diag] = wideband_delay_step(in, st, delay_samples, cfg)
    % 有界历史、逐样点因果延迟；块边界不改变结果。每条流不允许中途换核/延迟。

    validateattributes(delay_samples, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    if ~isfield(cfg, 'method')
        cfg.method = 'LAGRANGE';
    end

    if ~isfield(cfg, 'order')
        cfg.order = 7;
    end

    [~, ~, kd] = rtsim.replay.delay_kernel(0, cfg.method, cfg.order);
    fixed = kd.streaming_fixed_latency_samples;

    % 线性u<=n；高阶固定延迟覆盖核的所有正偏移，不访问未来样点。

    total = delay_samples + fixed;
    keep = ceil(total) + cfg.order + 2;
    signature = [char(upper(string(cfg.method))) ':' num2str(cfg.order) ':' num2str(delay_samples, 17)];
    if isempty(st)
        st = struct('history', zeros(0, size(in, 2)), 'signature', signature, 'samples', 0);
    elseif ~strcmp(st.signature, signature) || size(st.history, 2) ~= size(in, 2)
        error('rtsim:replay:DelayStateMismatch', '同一流必须保持核、延迟和通道数不变。');
    end

    data = [st.history; in];
    start = size(st.history, 1);
    out = rtsim.replay.sample_delay_at(data, start + (1:size(in, 1))' - total, cfg.method, cfg.order);
    st.history = data(max(1, end - keep + 1):end, :);
    st.samples = st.samples + size(in, 1);
    diag = struct('fixed_latency_samples', fixed, 'integer_delay_samples', floor(delay_samples), ...
        'fractional_delay_samples', delay_samples - floor(delay_samples), 'total_delay_samples', total, ...
        'method', char(upper(string(cfg.method))), 'qualification', 'FLOATING_REFERENCE');
end
