classdef WidebandMetrologyTest < matlab.unittest.TestCase
    % 宽带算法参考模型验收；不代表板卡或RTL资格。

    methods (Test)

        function delayStreamingCausalAndChunkInvariant(t)
            rng(51);
            x = randn(301, 2) + 1i * randn(301, 2);
            for method = ["LINEAR", "LAGRANGE", "FARROW", "WINDOWED_SINC"]
                cfg = struct('method', method, 'order', 7);
                [all, ~, d] = rtsim.replay.wideband_delay_step(x, [], 2.37, cfg);
                [a, s] = rtsim.replay.wideband_delay_step(x(1:87, :), [], 2.37, cfg);
                [b, s] = rtsim.replay.wideband_delay_step(x(88:190, :), s, 2.37, cfg);
                [c, ~] = rtsim.replay.wideband_delay_step(x(191:end, :), s, 2.37, cfg);
                t.verifyEqual([a; b; c], all, 'AbsTol', 1e-13);
                xx = x;
                xx(88:end, :) = 100;
                changed = rtsim.replay.wideband_delay_step(xx, [], 2.37, cfg);
                t.verifyEqual(changed(1:87, :), a, 'AbsTol', 1e-13);
                t.verifyGreaterThanOrEqual(d.fixed_latency_samples, 0);
            end
        end

        function capturedDelayKnownComplexTone(t)
            n = (0:599)';
            w = 0.2;
            x = [exp(1i * w * n), 0.7 * exp(1i * (w * n + 0.4))];
            u = (30:550)' - 0.37;
            for method = ["LAGRANGE", "FARROW"]
                y = rtsim.replay.sample_delay_at(x, u, method, 7);
                ref = [exp(1i * w * (u - 1)), 0.7 * exp(1i * (w * (u - 1) + 0.4))];
                t.verifyLessThan(max(abs(y - ref), [], 'all'), 1e-7);
                t.verifyEqual(y(:, 2) ./ y(:, 1), repmat(0.7 * exp(0.4i), numel(u), 1), 'AbsTol', 1e-12);
            end
        end

        function firChunksAndCausality(t)
            rng(14);
            c = randn(9, 2, 2) / 10;
            x = randn(120, 2);
            y = rtsim.calibration.apply_mimo_fir(x, [], c);
            [a, s] = rtsim.calibration.apply_mimo_fir(x(1:51, :), [], c);
            b = rtsim.calibration.apply_mimo_fir(x(52:end, :), s, c);
            t.verifyEqual([a; b], y, 'AbsTol', 1e-13);
            xx = x;
            xx(52:end, :) = 99;
            yy = rtsim.calibration.apply_mimo_fir(xx, [], c);
            t.verifyEqual(yy(1:51, :), a, 'AbsTol', 1e-13);
        end

        function independentFrequencyCalibrationAndDomain(t)
            [m, cfg] = rtsim.calibration.synthetic_frequency_measurements();
            cal = rtsim.calibration.fit_frequency_calibration(m, cfg);
            t.verifyEqual(cal.qualification, 'SYNTHETIC');
            t.verifyLessThan(cal.holdout.relative_complex_error, 0.015);
            t.verifyGreaterThan(cal.latency_samples, 0);
            rtsim.calibration.validate_frequency_domain(cal, struct('range_index', 2, ...
                'temperature_c', 25, 'power_dbm', -30, 'frequency_hz', 0));
            t.verifyError(@()rtsim.calibration.validate_frequency_domain(cal, ...
                struct('range_index', 2, 'temperature_c', 99, 'power_dbm', -30, 'frequency_hz', 0)), ...
                'rtsim:calibration:OutOfDomain');
            m.frequency_hz(:) = 0;
            t.verifyError(@()rtsim.calibration.fit_frequency_calibration(m, cfg), ...
                'rtsim:calibration:InsufficientFrequencyData');
        end

        function correlatedErrorsCancelAndNonPsdRejected(t)
            data = rtsim.verification.synthetic_metrology_inputs();
            b = rtsim.verification.metrology_budget(data, 20000);
            t.verifyEqual(b.qualification, 'SYNTHETIC');
            t.verifyLessThan(max(abs(b.mc_standard ./ b.standard - 1)), 0.04);
            reordered = data;
            order = 26:-1:1;
            reordered.source_names = data.source_names(order);
            reordered.source_units = data.source_units(order);
            reordered.source_provenance = data.source_provenance(order);
            reordered.covariance = data.covariance(order, order);
            reorderedBudget = rtsim.verification.metrology_budget(reordered, 0);
            t.verifyEqual(reorderedBudget.standard, b.standard, 'AbsTol', 1e-13);
            data.covariance = zeros(size(data.covariance));

            % 共同功率标准不能变成虚假差分极化误差。

            data.covariance(1, 1) = 1;
            q = rtsim.verification.metrology_budget(data, 0);
            t.verifyEqual(q.standard(4), 0, 'AbsTol', 1e-14);
            t.verifyGreaterThan(q.standard(1), 0);
            data.covariance(1:2, 1:2) = [1 2; 2 1];
            t.verifyError(@()rtsim.verification.metrology_budget(data, 0), ...
                'rtsim:verification:InvalidCovariance');
        end

        function independentHoldoutAndGainLimit(t)
            [m, cfg] = rtsim.calibration.synthetic_frequency_measurements();
            t.verifyEmpty(intersect(m.frequency_hz, m.holdout.frequency_hz));
            cfg.max_inverse_gain = 0.8;
            cal = rtsim.calibration.fit_frequency_calibration(m, cfg);
            t.verifyTrue(cal.gain_limit_applied);
            t.verifyLessThanOrEqual(cal.implemented_peak_gain, 0.8 + 1e-12);
            m = rmfield(m, 'holdout');
            blocked = rtsim.calibration.fit_frequency_calibration(m, cfg);
            t.verifyEqual(blocked.qualification, 'BLOCKED_MISSING_HOLDOUT');
            m.excitation(2, :, :) = m.excitation(1, :, :);
            t.verifyError(@()rtsim.calibration.fit_frequency_calibration(m, cfg), ...
                'rtsim:calibration:ExcitationRank');
        end

        function integerImpulseDelayAndBandwidthComparison(t)
            x = zeros(40, 2);
            x(1, :) = [1 0.5i];
            for method = ["LINEAR", "LAGRANGE", "FARROW", "WINDOWED_SINC"]
                cfg = struct('method', method, 'order', 7);
                [y, ~, d] = rtsim.replay.wideband_delay_step(x, [], 3, cfg);
                ref = zeros(size(x));
                ref(4 + d.fixed_latency_samples, :) = [1 0.5i];
                t.verifyEqual(y, ref, 'AbsTol', 1e-14);
            end

            q = rtsim.replay.compare_wideband_delay();
            t.verifyEqual(height(q), 20);
            linear = q(strcmp(q.method, 'LINEAR') & q.bandwidth_mhz == 20, :);
            lagrange = q(strcmp(q.method, 'LAGRANGE') & q.bandwidth_mhz == 20, :);
            t.verifyLessThan(lagrange.max_amplitude_error_db, linear.max_amplitude_error_db / 100);
        end

    end
end
