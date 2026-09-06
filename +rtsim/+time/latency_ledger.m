function ledger = latency_ledger(cfg, measuredLatencies, mode)
    % LATENCY_LEDGER 分项记录传播、滤波、流水线和排队时延，防止重复补偿。

    arguments
        cfg struct
        measuredLatencies struct
        mode {mustBeTextScalar}
    end

    if string(mode) ~= "ACCOUNTING_ONLY"
        error('rtsim:time:UnsupportedLatencyMode', '基础实现只做 ACCOUNTING_ONLY，不自动补偿波形。');
    end

    names = {'rf_propagation_s', 'filter_group_delay_s', 'hardware_pipeline_s', 'queue_wait_s'};
    assert(all(isfield(measuredLatencies, names)), 'rtsim:time:IncompleteLatencyLedger', '四类时延必须分别给出。');
    values = zeros(1, numel(names));
    for k = 1:numel(names)
        values(k) = measuredLatencies.(names{k});
    end

    assert(all(isfinite(values)) && all(values >= 0), 'rtsim:time:InvalidLatency', '时延必须为有限非负数。');
    ledger = measuredLatencies;
    ledger.total_s = sum(values);
    ledger.compensated_at = localField(cfg, 'compensated_at', struct());
    ledger.mode = "ACCOUNTING_ONLY";
end

function value = localField(s, name, defaultValue)
    if isfield(s, name)
        value = s.(name);
    else
        value = defaultValue;
    end
end
