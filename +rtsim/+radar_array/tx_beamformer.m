function jtx = tx_beamformer(cfg, direction_enu, fc_Hz, time_s)
    % 2端口馈入到空间HV的逐元复叠加，无额外array gain。

    if nargin < 4
        time_s = 0;
    end

    u = direction_enu(:) / norm(direction_enu);
    w = rtsim.radar_array.beam_steering(cfg, fc_Hz, time_s);
    w = rtsim.radar_array.tx_channel_error(cfg, w);
    j = rtsim.radar_array.active_element_pattern(cfg, u);
    p = exp(2i * pi * fc_Hz / 299792458 * (cfg.positions_m * u));
    jtx = complex(zeros(2));
    for k = 1:size(w, 1)
        jtx = jtx + p(k) * j(:, :, k) * diag(w(k, :));
    end
end
