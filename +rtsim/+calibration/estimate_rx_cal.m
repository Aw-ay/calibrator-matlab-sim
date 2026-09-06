function calRx = estimate_rx_cal(measurements, referenceDefinition, fitCfg)
    % ESTIMATE_RX_CAL 由三档独立H/V激励估计RX二维复响应及逆系数。

    arguments
        measurements (1, 1) struct
        referenceDefinition (1, 1) struct %#ok<INUSA>
        fitCfg (1, 1) struct
    end

    if ~isfield(measurements, 'rx') || numel(measurements.rx) ~= 3
        error('rtsim:calibration:InvalidMeasurements', '必须提供三档RX测量。');
    end

    calRx.coefficients = zeros(2, 2, 3);
    calRx.response_estimate = zeros(2, 2, 3);
    calRx.condition_number = zeros(1, 3);
    calRx.residual = zeros(1, 3);
    for k = 1:3
        x = measurements.rx(k).input;
        y = measurements.rx(k).output;
        checkDrive(x);
        response = (x \ y).';
        op = rtsim.calibration.solve_regularized_inverse(response, fitCfg);
        calRx.response_estimate(:, :, k) = response;
        calRx.coefficients(:, :, k) = op.matrix;
        calRx.condition_number(k) = cond(x);
        calRx.residual(k) = norm(y - x * response.', 'fro') / sqrt(numel(y));
    end

    calRx.id = "rx-cal-" + string(measurements.seed);
    calRx.status = "OK";
    calRx.model_scope = "frequency-flat per-range 2x2 calibration";
end

function checkDrive(x)
    if size(x, 2) ~= 2 || rank(x) < 2
        error('rtsim:calibration:RankDeficient', ...
            'H/V校准激励必须相互独立且满列秩。');
    end
end
