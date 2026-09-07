function y = rx_channel_error(cfg, element_signals)
    % 输入/输出为样点×2×阵元；每个接收通道独立放大与移相。

    y = element_signals;
    for k = 1:size(cfg.positions_m, 1)
        y(:, :, k) = element_signals(:, :, k) .* cfg.rx_error(k, :);
    end
end
