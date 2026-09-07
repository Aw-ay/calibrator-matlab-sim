function y = rx_dbf(cfg, element_signals, fc_Hz, time_s)
    % 保持单位白噪声权范数；不再除以N或乘阵列增益。

    if nargin < 4
        time_s = 0;
    end

    [~, w] = rtsim.radar_array.beam_steering(cfg, fc_Hz, time_s);
    y = complex(zeros(size(element_signals, 1), 2));
    for k = 1:size(w, 1)
        y = y + element_signals(:, :, k) .* conj(w(k, :));
    end
end
