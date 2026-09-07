function j = element_pattern(cfg, direction_enu)
    % 共享单元Jones；可选前半球cos(theta)电压模型。

    u = direction_enu(:) / norm(direction_enu);
    validateattributes(u, {'numeric'}, {'real', 'finite', 'numel', 3});
    amplitude = 1;
    if cfg.element_cosine_power ~= 0
        amplitude = max(0, u(1))^cfg.element_cosine_power;
    end

    j = amplitude * cfg.element_jones;
end
