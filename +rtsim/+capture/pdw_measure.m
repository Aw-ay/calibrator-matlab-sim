function pdw = pdw_measure(selectedIQ, coarseContext, measureCfg)
    % 从实际捕获样点估计幅度和频率，不接受发射真值标签。

    p = sum(abs(selectedIQ).^2, 2);
    threshold = max(p) / 4;
    ids = find(p > threshold);
    fs = measureCfg.fs_Hz;
    pdw.pulse_id = coarseContext.pulse_id;
    pdw.range_id = coarseContext.range_id;
    pdw.toa_s = (coarseContext.start_index + ids(1) - 1) / fs;
    pdw.width_s = (ids(end) - ids(1) + 1) / fs;
    pdw.peak_power_W = max(abs(selectedIQ).^2, [], 1);
    pdw.mean_power_W = mean(abs(selectedIQ(ids, :)).^2, 1);
    pdw.center_frequency_Hz = NaN;
    pdw.chirp_rate_Hz_per_s = NaN;
    if numel(ids) > 8
        [~, pol] = max(pdw.mean_power_W);
        z = selectedIQ(ids, pol);
        phase = unwrap(angle(z));
        t = (0:numel(ids) - 1)' / fs;
        fit = polyfit(t, phase, 2);
        pdw.chirp_rate_Hz_per_s = fit(1) / pi;
        pdw.center_frequency_Hz = (2 * fit(1) * mean(t) + fit(2)) / (2 * pi);
    end

    pdw.reference_plane = 'RP1_RX';
    pdw.units = 'sqrt_W';
    pdw.edge_definition = 'half_amplitude';
    pdw.calibration_id = coarseContext.calibration_id;
    pdw.available_at_s = coarseContext.available_index / fs;
end
