function scores = compare_to_truth(measurements, truth, acceptanceSpec)
    % 仅评分模块接触真值；结果不反馈给在线控制器。

    names = fieldnames(acceptanceSpec);
    scores = struct();
    for k = 1:numel(names)
        name = names{k};
        assert(isfield(measurements, name) && isfield(truth, name), 'rtsim:ScoreField', '测量与真值缺少共同指标。');
        errorValue = measurements.(name) - truth.(name);
        scores.(name) = struct('error', errorValue, 'bias', mean(errorValue(:), 'omitnan'), ...
            'rmse', sqrt(mean(abs(errorValue(:)).^2, 'omitnan')), ...
            'pass', all(isfinite(errorValue(:))) && all(abs(errorValue(:)) <= acceptanceSpec.(name)));
    end
end
