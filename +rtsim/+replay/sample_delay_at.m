function y = sample_delay_at(wave, u, method, order)
    % 1基连续源索引；越界样点置零。仅供整捕获完成后的随机读，固定延迟为0。

    if nargin < 3
        method = 'LINEAR';
    end

    if nargin < 4
        order = 7;
    end

    validateattributes(u, {'numeric'}, {'real', 'finite', 'vector'});
    u = u(:);
    y = complex(zeros(numel(u), size(wave, 2)));
    for n = 1:numel(u)
        base = floor(u(n));
        [h, offsets] = rtsim.replay.delay_kernel(u(n) - base, method, order);
        idx = base + offsets;
        valid = idx >= 1 & idx <= size(wave, 1) & h.' ~= 0;
        y(n, :) = h(valid).' * wave(idx(valid), :);
    end
end
