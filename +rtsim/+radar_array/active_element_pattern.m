function j = active_element_pattern(cfg, direction_enu)
    % 每阵元嵌入式Jones。斜率为显式合成方向依赖，不代替实测数据。

    u = direction_enu(:) / norm(direction_enu);
    base = rtsim.radar_array.element_pattern(cfg, u);
    n = size(cfg.positions_m, 1);
    j = complex(zeros(2, 2, n));
    for k = 1:n
        scale = exp(cfg.aep_direction_slope(k, :) * (u(2) + .5 * u(3)));
        j(:, :, k) = base * cfg.aep_jones(:, :, k) * diag(scale);
    end
end
