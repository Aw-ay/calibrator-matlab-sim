function y = rx_element_signals(cfg, field_samples, direction_enu, fc_Hz)
    % 来波look方向为雷达指向源；相位+kr.u。互易Jones为转置而非共轭。

    u = direction_enu(:) / norm(direction_enu);
    j = rtsim.radar_array.active_element_pattern(cfg, u);
    p = exp(2i * pi * fc_Hz / 299792458 * (cfg.positions_m * u));
    n = size(cfg.positions_m, 1);
    y = complex(zeros(size(field_samples, 1), 2, n));
    for k = 1:n
        y(:, :, k) = p(k) * field_samples * j(:, :, k);
    end

    y = rtsim.radar_array.rx_channel_error(cfg, y);
end
