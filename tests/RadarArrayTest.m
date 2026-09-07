classdef RadarArrayTest < matlab.unittest.TestCase
    % 物理解析值、独立逐元接收和留出测量约束阵列实现。

    methods (Test)

        function singleElementIdentity(t)
            c = rtsim.radar_array.default_array_config(3e9, [1 1]);
            [a, b] = rtsim.radar_array.array_response(c, [1; 2; 3], 3e9, 0);
            t.verifyEqual(a, eye(2), 'AbsTol', 1e-14);
            t.verifyEqual(b, eye(2), 'AbsTol', 1e-14);
        end

        function normalizationAndBoresight(t)
            c = rtsim.radar_array.default_array_config(3e9);
            [a, b, m] = rtsim.radar_array.array_response(c, [1; 0; 0], 3e9, 0);
            t.verifyEqual(a, 4 * eye(2), 'AbsTol', 1e-13);
            t.verifyEqual(b, 4 * eye(2), 'AbsTol', 1e-13);
            t.verifyEqual(m.tx_feed_power_per_port, [1 1], 'AbsTol', 1e-13);
            t.verifyEqual(m.rx_noise_weight_power, [1 1], 'AbsTol', 1e-13);
            t.verifyEqual(abs(a(1, 1) * b(1, 1))^2, 256, 'AbsTol', 1e-10);
            t.verifyTrue(isnan(m.g_over_t_dB_per_K(1)));
        end

        function steeringAndPhaseSign(t)
            c = rtsim.radar_array.default_array_config(3e9, [2 1]);
            c.steer_az_deg = 30;
            a = rtsim.radar_array.array_response(c, [cosd(30); sind(30); 0], 3e9, 0);
            b = rtsim.radar_array.array_response(c, [cosd(30); -sind(30); 0], 3e9, 0);
            t.verifyEqual(a, sqrt(2) * eye(2), 'AbsTol', 1e-13);
            t.verifyLessThan(norm(b), 1e-13);
            c.positions_m = [0 0 0; 0 299792458 / 3e9 / 2 0];
            c.steer_az_deg = 0;
            a = rtsim.radar_array.array_response(c, [cosd(30); sind(30); 0], 3e9, 0);
            t.verifyEqual(a(1, 1), (1 + 1i) / sqrt(2), 'AbsTol', 1e-13);
        end

        function receiveElementDbfEquivalence(t)
            c = rtsim.radar_array.default_array_config(3e9, [3 2]);
            c.steer_az_deg = 17;
            c.rx_error = reshape(exp(1i * (1:12) / 5), 6, 2);
            c.element_jones = [1 .03i; .02 .8];
            x = [1 + 2i 3 - 1i; -.2i 1];
            u = [1; .2; -.1];
            e = rtsim.radar_array.rx_element_signals(c, x, u, 3e9);
            y = rtsim.radar_array.rx_dbf(c, e, 3e9, 0);
            [~, j] = rtsim.radar_array.array_response(c, u, 3e9, 0);
            t.verifyEqual(y, x * j.', 'AbsTol', 1e-12);
            c.tx_error = 4 * c.tx_error;
            [~, k] = rtsim.radar_array.array_response(c, u, 3e9, 0);
            t.verifyEqual(k, j, 'AbsTol', 1e-12);
        end

        function independentCalibrationHoldout(t)
            n = 8;
            m = 24;
            a = exp(2i * pi * (0:m - 1)' * (0:n - 1) / m);
            g = [(1 + .02 * (1:n)') .* exp(.03i * (1:n)'), ...
                (1 - .01 * (1:n)') .* exp(-.04i * (1:n)')];
            fit = rtsim.radar_array.array_calibration_solver(a, a * g, 0);
            h = exp(2i * pi * ((.5:m - .5)' / m) * (0:n - 1));
            t.verifyLessThan(norm(h * fit.channel_response - h * g, 'fro'), 1e-11);
            t.verifyLessThan(fit.relative_residual, 1e-12);
            t.verifyEqual(fit.channel_response, g, 'AbsTol', 1e-12);
            t.verifyError(@() rtsim.radar_array.array_calibration_solver(a(:, 1:2) * 0, a * g, 0), ...
                'rtsim:array:Unidentifiable');
        end

        function aepPolarizationAndReciprocity(t)
            c = rtsim.radar_array.default_array_config(3e9, [1 1]);
            c.aep_direction_slope = [.3 + .2i -.2 + .1i];
            c.aep_jones = [1 .1i; .2 1];
            [a, b] = rtsim.radar_array.array_response(c, [1; 1; 0], 3e9, 0);
            a0 = rtsim.radar_array.array_response(c, [1; 0; 0], 3e9, 0);
            t.verifyGreaterThan(norm(a - a0), .1);
            t.verifyEqual(b, a.', 'AbsTol', 1e-13);
        end

        function beamwidthAndSidelobes(t)
            c = rtsim.radar_array.default_array_config(3e9, [8 1]);
            az = -90:.1:90;
            p = zeros(size(az));
            for q = 1:numel(az)
                j = rtsim.radar_array.array_response(c, [cosd(az(q)); sind(az(q)); 0], 3e9, 0);
                p(q) = abs(j(1, 1))^2;
            end

            s = rtsim.radar_array.beam_cut_metrics(az, p);
            t.verifyLessThan(abs(s.pointing_deg), .11);
            t.verifyGreaterThan(s.hpbw_deg, 12);
            t.verifyLessThan(s.hpbw_deg, 14);
            t.verifyGreaterThan(s.sll_dB, -14);
            t.verifyLessThan(s.sll_dB, -12);
            c = rtsim.radar_array.default_array_config(3e9, [4 1]);
            for q = 1:numel(az)
                j = rtsim.radar_array.array_response(c, [cosd(az(q)); sind(az(q)); 0], 3e9, 0);
                p(q) = abs(j(1, 1))^2;
            end

            smaller = rtsim.radar_array.beam_cut_metrics(az, p);
            t.verifyGreaterThan(smaller.hpbw_deg, 1.9 * s.hpbw_deg);
            t.verifyLessThan(smaller.sll_dB, -10);
        end

        function independentReceivePhaseOracle(t)
            c = rtsim.radar_array.default_array_config(3e9, [2 1]);
            c.positions_m = [0 0 0; 0 299792458 / 3e9 / 2 0];
            c.rx_error = [1 1; 2i 3];
            e = rtsim.radar_array.rx_element_signals(c, [1 2], [cosd(30); sind(30); 0], 3e9);
            t.verifyEqual(e(:, :, 1), [1 2], 'AbsTol', 1e-13);
            t.verifyEqual(e(:, :, 2), [-2 6i], 'AbsTol', 1e-13);
            y = rtsim.radar_array.rx_dbf(c, e, 3e9, 0);
            t.verifyEqual(y, [-1 2 + 6i] / sqrt(2), 'AbsTol', 1e-13);
        end

        function scheduleBoundaries(t)
            c = rtsim.radar_array.default_array_config(3e9);
            c.scan_schedule = [0 10 0; 1 -20 5; 2 30 7];
            t.verifyEqual(rtsim.radar_array.scan_schedule(c, .999), [10 0]);
            t.verifyEqual(rtsim.radar_array.scan_schedule(c, 1), [-20 5]);
            t.verifyEqual(rtsim.radar_array.scan_schedule(c, 10), [30 7]);
        end

    end
end
