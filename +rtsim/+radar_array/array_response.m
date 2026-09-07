function [jtx, jrx, meta] = array_response(cfg, direction_enu, fc_Hz, time_s)
    % 主链稳定接口：同一个雷达到目标的ENU look方向用于发射和接收。
    % Jtx: 馈口→空间，Jrx: 空间→波束。收发互易不用反向look或共轭Jones。

    if nargin < 4
        time_s = 0;
    end

    jtx = rtsim.radar_array.tx_beamformer(cfg, direction_enu, fc_Hz, time_s);
    e = rtsim.radar_array.rx_element_signals(cfg, eye(2), direction_enu, fc_Hz);
    jrx = rtsim.radar_array.rx_dbf(cfg, e, fc_Hz, time_s).';
    [~, ~, meta] = rtsim.radar_array.beam_steering(cfg, fc_Hz, time_s);
    meta.element_count = size(cfg.positions_m, 1);
    meta.qualification = cfg.aep_qualification;
    meta.normalization = '每激励极化sum(abs(w_tx).^2)=1；Rx白噪声权范数=1';
    meta.eirp_W_per_port = cfg.total_power_W * sum(abs(jtx).^2, 1);
    meta.g_over_t_dB_per_K = [NaN NaN];
    meta.noise_qualification = 'MISSING_NOISE_TEMPERATURE';
    if isfinite(cfg.noise_temperature_K) && cfg.noise_temperature_K > 0
        meta.g_over_t_dB_per_K = 10 * log10(sum(abs(jrx).^2, 2).' / cfg.noise_temperature_K);
        meta.noise_qualification = 'USER_SUPPLIED_SYSTEM_NOISE_TEMPERATURE';
    end

    two_way = jrx * jtx;
    meta.zdr_dB = 20 * log10(abs(two_way(1, 1)) / max(abs(two_way(2, 2)), realmin));
    meta.phidp_deg = angle(two_way(1, 1) * conj(two_way(2, 2))) * 180 / pi;
end
