function calibration = radar_calibration_solver(observables, referenceTargets, ~)
    % 由独立满秩参考激励识别二维雷达响应，不读取被测雷达真值。

    assert(size(referenceTargets, 2) == 2 && rank(referenceTargets) == 2, 'rtsim:Rank', '雷达参考激励必须满列秩。');
    response = (referenceTargets \ observables).';
    calibration.response = response;
    calibration.correction = pinv(response);
    calibration.residual = norm(observables - referenceTargets * response.', 'fro');
    calibration.scope = '频率平坦二维响应拟合，需独立留出样本验收';
end
