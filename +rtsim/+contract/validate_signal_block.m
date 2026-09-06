function validate_signal_block(block, expectedContract)
    % VALIDATE_SIGNAL_BLOCK 拒绝隐式单位、参考面、维度或时钟契约转换。

    arguments
        block struct
        expectedContract struct
    end

    required = {'iq', 'domain', 'reference_plane', 'units', 'layout', 'valid', 'sample_grid', 'provenance'};
    assert(all(isfield(block, required)), 'rtsim:contract:IncompleteBlock', 'SignalBlock 字段不完整。');
    rtsim.time.validate_time_grid(block.sample_grid);
    checks = {'domain', 'DomainMismatch'; 'units', 'UnitsMismatch'; 'reference_plane', 'ReferencePlaneMismatch'};
    for k = 1:size(checks, 1)
        field = checks{k, 1};
        if isfield(expectedContract, field) && string(block.(field)) ~= string(expectedContract.(field))
            error("rtsim:contract:" + checks{k, 2}, '%s 不符合预期契约。', field);
        end
    end

    if isfield(expectedContract, 'size') && ~isequal(size(block.iq), expectedContract.size)
        error('rtsim:contract:SizeMismatch', '样点维度不符合预期契约。');
    end

    assert(size(block.iq, 1) == double(block.sample_grid.count), ...
        'rtsim:contract:CountMismatch', '样点数与时间网格不一致。');
    assert(numel(block.valid) == size(block.iq, 1), ...
        'rtsim:contract:ValidityMismatch', 'valid 必须逐样点定义。');
end
