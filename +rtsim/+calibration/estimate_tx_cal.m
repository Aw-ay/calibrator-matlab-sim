function calTx = estimate_tx_cal(measurements, referenceDefinition, fitCfg)
    % ESTIMATE_TX_CAL 由独立TX参考测量估计TX二维复响应及逆系数。

    arguments
        measurements (1, 1) struct
        referenceDefinition (1, 1) struct %#ok<INUSA>
        fitCfg (1, 1) struct
    end

    if ~isfield(measurements, 'tx')
        error('rtsim:calibration:InvalidMeasurements', '缺少独立TX参考测量。');
    end

    x = measurements.tx.input;
    y = measurements.tx.output;
    if size(x, 2) ~= 2 || rank(x) < 2
        error('rtsim:calibration:RankDeficient', ...
            'TX的H/V校准激励必须相互独立且满列秩。');
    end

    response = (x \ y).';
    op = rtsim.calibration.solve_regularized_inverse(response, fitCfg);
    calTx.coefficients = op.matrix;
    calTx.response_estimate = response;
    calTx.condition_number = cond(x);
    calTx.residual = norm(y - x * response.', 'fro') / sqrt(numel(y));
    calTx.id = "tx-cal-" + string(measurements.seed);
    calTx.status = "OK";
    calTx.model_scope = "frequency-flat 2x2 calibration";
end
