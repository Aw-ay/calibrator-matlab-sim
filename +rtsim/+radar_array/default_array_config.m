function cfg = default_array_config(fc_Hz, array_size)
    % 默认合成阵列；每个激励极化的总馈入功率为1，绝非实测AEP。

    if nargin < 1
        fc_Hz = 3e9;
    end

    if nargin < 2
        array_size = [4 4];
    end

    cfg.positions_m = rtsim.radar_array.array_geometry(array_size, 299792458 / fc_Hz / 2);
    n = size(cfg.positions_m, 1);
    cfg.weights_tx = ones(n, 2) / sqrt(n);
    cfg.weights_rx = ones(n, 2) / sqrt(n);
    cfg.tx_error = ones(n, 2);
    cfg.rx_error = ones(n, 2);
    cfg.steer_az_deg = 0;
    cfg.steer_el_deg = 0;
    cfg.scan_schedule = zeros(0, 3);
    cfg.element_jones = eye(2);
    cfg.element_cosine_power = 0;
    cfg.aep_jones = repmat(eye(2), 1, 1, n);
    cfg.aep_direction_slope = zeros(n, 2);
    cfg.aep_qualification = 'SYNTHETIC_NOT_MEASURED';
    cfg.total_power_W = 1;
    cfg.noise_temperature_K = NaN;
end
