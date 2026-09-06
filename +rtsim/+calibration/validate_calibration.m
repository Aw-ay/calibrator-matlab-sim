function report = validate_calibration(calSet, holdoutMeasurements, limits)
    % VALIDATE_CALIBRATION 仅用独立holdout数据评价校准残差。

    arguments
        calSet (1, 1) struct
        holdoutMeasurements (1, 1) struct
        limits (1, 1) struct
    end

    if ~isfield(limits, 'max_rmse')
        error('rtsim:calibration:MissingField', 'limits.max_rmse为必需字段。');
    end

    rxRmse = zeros(1, 3);
    for k = 1:3
        corrected = holdoutMeasurements.rx(k).output * ...
            calSet.rx.coefficients(:, :, k).';
        rxRmse(k) = norm(corrected - holdoutMeasurements.rx(k).input, 'fro') / ...
            sqrt(numel(corrected));
    end

    txCorrected = holdoutMeasurements.tx.output * calSet.tx.coefficients.';
    txRmse = norm(txCorrected - holdoutMeasurements.tx.input, 'fro') / ...
        sqrt(numel(txCorrected));
    report.rx_rmse = rxRmse;
    report.tx_rmse = txRmse;
    report.max_rmse = max([rxRmse txRmse]);
    report.pass = report.max_rmse <= limits.max_rmse;
    report.status = string(matlab.lang.OnOffSwitchState(report.pass));
    report.dataset_role = "independent_holdout";
end
