function [weights, offsets, diag] = delay_kernel(mu, method, order)
    % 已捕获波形插值核：x(floor(u)+offsets)*weights，mu=u-floor(u)。
    % FARROW直接按Lagrange多项式求值，是浮点结构参考，不宣称RTL位精确。

    if nargin < 3
        order = 7;
    end

    method = upper(string(method));
    validateattributes(mu, {'numeric'}, {'scalar', 'real', 'finite', '>=', 0, '<', 1});
    validateattributes(order, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', 31});
    if method == "LINEAR"
        offsets = 0:1;
        weights = [1 - mu; mu];
        latency = 0;
    elseif any(method == ["LAGRANGE", "FARROW", "WINDOWED_SINC"])
        offsets = -floor(order / 2):ceil(order / 2);
        if method == "WINDOWED_SINC"
            z = mu - offsets;
            weights = ones(size(z));
            nz = abs(z) > 1e-14;
            weights(nz) = sin(pi * z(nz)) ./ (pi * z(nz));
            window = 0.5 + 0.5 * cos(2 * pi * z / (order + 1));
            weights = weights .* window;
            weights = weights(:) / sum(weights);
        else
            weights = ones(order + 1, 1);
            for k = 1:order + 1
                other = [1:k - 1, k + 1:order + 1];
                weights(k) = prod((mu - offsets(other)) ./ (offsets(k) - offsets(other)));
            end
        end

        latency = ceil(order / 2);
    else
        error('rtsim:replay:DelayMethod', '不支持的分数延迟方法。');
    end

    diag = struct('method', char(method), 'order', numel(weights) - 1, ...
        'streaming_fixed_latency_samples', latency, 'qualification', 'FLOATING_REFERENCE');
end
