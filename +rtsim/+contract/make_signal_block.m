function block = make_signal_block(samples, grid, domain, provenance)
    % MAKE_SIGNAL_BLOCK 构造带显式单位、参考面和时间网格的信号块。

    arguments
        samples {mustBeNumeric}
        grid struct
        domain {mustBeTextScalar}
        provenance struct
    end

    rtsim.time.validate_time_grid(grid);
    assert(size(samples, 1) == double(grid.count), 'rtsim:contract:CountMismatch', ...
        '样点首维必须等于 grid.count。');
    block = struct('iq', samples, 'domain', string(domain), 'reference_plane', "ADC_RAW", ...
        'units', "sqrt_W", 'layout', struct('pol_order', ["H" "V"]), ...
        'valid', true(size(samples, 1), 1), 'sample_grid', grid, ...
        'available_at', [], 'calibration_id', "UNSPECIFIED", 'provenance', provenance);
end
