function comparison = compare_wideband_delay()
    % 62.5MS/s复基带，B表示[-B/2,B/2]占用宽度；H/V分数延迟不同以暴露差分误差。

    fs = 62.5e6;
    bandwidths = [1 2 5 10 20] * 1e6;
    methods = ["LINEAR", "LAGRANGE", "FARROW", "WINDOWED_SINC"];
    rows = cell(numel(bandwidths) * numel(methods), 8);
    count = 0;
    for method = methods
        for B = bandwidths
            f = linspace(-B / 2, B / 2, 1001)';
            residual = complex(zeros(numel(f), 2));
            for p = 1:2
                delays = [0.37 0.61];
                d = delays(p);
                [~, ~, diag] = rtsim.replay.delay_kernel(0, method, 7);
                total = d + diag.streaming_fixed_latency_samples;
                u = -total;
                [h, offsets] = rtsim.replay.delay_kernel(u - floor(u), method, 7);
                response = exp(2i * pi * f * (floor(u) + offsets) / fs) * h;
                residual(:, p) = response .* exp(2i * pi * f * total / fs);
            end

            phase = unwrap(angle(residual));
            gd = -diff(phase) / (2 * pi * (f(2) - f(1))) * 1e9;
            count = count + 1;
            rows(count, :) = {char(method), B / 1e6, max(abs(20 * log10(abs(residual))), [], 'all'), ...
                max(abs(phase), [], 'all') * 180 / pi, max(abs(gd), [], 'all'), ...
                max(abs(20 * log10(abs(residual(:, 1) ./ residual(:, 2))))), ...
                max(abs(angle(residual(:, 1) ./ residual(:, 2)))) * 180 / pi, ...
                diag.streaming_fixed_latency_samples};
        end
    end

    comparison = cell2table(rows, 'VariableNames', {'method', 'bandwidth_mhz', 'max_amplitude_error_db', ...
        'max_phase_error_deg', 'max_group_delay_error_ns', 'max_zdr_error_db', ...
        'max_phidp_error_deg', 'fixed_latency_samples'});
end
