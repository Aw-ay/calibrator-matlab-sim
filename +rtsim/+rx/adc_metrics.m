function metrics = adc_metrics(samples, testDefinition, grid)
    % ADC_METRICS 给出不依赖频谱假设的基础时域 ADC 指标。

    arguments
        samples {mustBeNumeric}
        testDefinition struct
        grid struct
    end

    rtsim.time.validate_time_grid(grid);
    assert(size(samples, 1) == double(grid.count), 'rtsim:rx:MetricCountMismatch', '样点数与时间网格不一致。');
    assert(isfield(testDefinition, 'full_scale') && testDefinition.full_scale > 0, ...
        'rtsim:rx:InvalidMetricDefinition', '必须明确 full_scale。');
    clipped = localField(testDefinition, 'clipped', abs(samples) >= testDefinition.full_scale);
    assert(numel(clipped) == numel(samples) || numel(clipped) == size(samples, 1), ...
        'rtsim:rx:InvalidMetricDefinition', 'clipped 标记维度不兼容。');
    metrics = struct('mean_power', mean(abs(samples(:)).^2), ...
        'rms_amplitude', sqrt(mean(abs(samples(:)).^2)), ...
        'peak_amplitude', max(abs(samples(:))), 'clipped_fraction', mean(clipped(:)), ...
        'scope', "TIME_DOMAIN_BASIC", 'spectral_metrics_status', "NOT_COMPUTED_WITHOUT_TONE_AND_WINDOW_DEFINITION");
end

function value = localField(s, name, defaultValue)
    if isfield(s, name)
        value = s.(name);
    else
        value = defaultValue;
    end
end
