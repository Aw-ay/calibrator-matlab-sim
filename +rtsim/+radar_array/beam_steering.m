function [wtx, wrx, meta] = beam_steering(cfg, fc_Hz, time_s)
    % Tx采用负相位；Rx存储正相位权，DBF内部取共轭。

    if nargin < 3
        time_s = 0;
    end

    a = rtsim.radar_array.scan_schedule(cfg, time_s);
    u = [cosd(a(2)) * cosd(a(1)); cosd(a(2)) * sind(a(1)); sind(a(2))];
    p = 2 * pi * fc_Hz / 299792458 * (cfg.positions_m * u);
    tx = sqrt(sum(abs(cfg.weights_tx).^2, 1));
    rx = sqrt(sum(abs(cfg.weights_rx).^2, 1));
    if any(tx == 0) || any(rx == 0)
        error('rtsim:array:ZeroWeights', '每个极化必须有非零权重。');
    end

    wtx = cfg.weights_tx ./ tx .* exp(-1i * p);
    wrx = cfg.weights_rx ./ rx .* exp(1i * p);
    meta.angles_deg = a;
    meta.tx_feed_power_per_port = sum(abs(wtx).^2, 1);
    meta.rx_noise_weight_power = sum(abs(wrx).^2, 1);
end
