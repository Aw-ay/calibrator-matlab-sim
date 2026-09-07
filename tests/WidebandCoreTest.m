classdef WidebandCoreTest < matlab.unittest.TestCase
    methods (Test)

        function rxCaptureFlushAndLiveRejection(t)
            cal = struct('id', 'test', 'coefficients', repmat(eye(2), 1, 1, 3));
            coeff = zeros(5, 2, 2);
            coeff(4, :, :) = eye(2);
            cal.wideband = struct('coeff', coeff, 'latency_samples', 3);
            x = reshape(1:40, 20, 2);
            y = rtsim.calibration.apply_rx_cal(x, struct(), cal, ...
                struct('range_id', 2, 'capture_complete', true));
            t.verifyEqual(y, x, 'AbsTol', 1e-14);
            t.verifyError(@()rtsim.calibration.apply_rx_cal(x, struct(), cal, struct('range_id', 2)), ...
                'rtsim:calibration:WidebandCaptureRequired');
        end

        function txSafetyClearsPendingTail(t)
            cal = struct('id', 'test', 'coefficients', eye(2));
            coeff = zeros(5, 2, 2);
            coeff(4, :, :) = eye(2);
            cal.wideband = struct('coeff', coeff, 'latency_samples', 3);
            [y, s] = rtsim.calibration.apply_tx_cal([1 1], struct(), cal, struct('enabled', true));
            t.verifyEqual(y, [0 0]);
            [y, s] = rtsim.calibration.apply_tx_cal(zeros(2, 2), s, cal, struct('enabled', false));
            t.verifyEqual(y, zeros(2, 2));
            y = rtsim.calibration.apply_tx_cal(zeros(8, 2), s, cal, struct('enabled', true));
            t.verifyEqual(y, zeros(8, 2));
        end

        function calibratedReplayPreservesAlignment(t)
            c = SystemSamplingTest.shortConfig();
            a = run_stage_a(c);
            coeff = zeros(5, 2, 2);
            coeff(4, :, :) = eye(2);
            wide = struct('coeff', coeff, 'latency_samples', 3, 'sample_rate_hz', c.pl.output_fs_Hz, ...
                'domain', struct('range_index', [1 2 3], 'temperature_c', [-100 100], ...
                'power_dbm', [-300 100], 'frequency_hz', [-20e6 20e6]), 'qualification', 'SYNTHETIC');
            c.calibration.wideband.enabled = true;
            c.calibration.wideband.rx = wide;
            c.calibration.wideband.tx = wide;
            c.calibration.wideband.operating_power_dbm = -30;
            c.calibration.wideband.tx_range_index = 2;
            c.calibration.wideband.rx_plant_coeff = reshape(eye(2), 1, 2, 2);
            c.calibration.wideband.tx_plant_coeff = reshape(eye(2), 1, 2, 2);
            b = run_stage_a(c);
            t.verifyEqual(b.records.replay_status, 'COMPLETED');
            t.verifyEqual(b.tx_iq, a.tx_iq, 'AbsTol', 1e-12);
            t.verifyEqual(b.records.t_tx_aligned_s, b.records.t_tx_target_s, 'AbsTol', 1e-15);
            t.verifyGreaterThanOrEqual(b.records.t_tx_actual_s, b.records.t_tx_aligned_s - 1 / c.pl.output_fs_Hz);
            c.instrument.mode = 'DDS';
            t.verifyError(@()run_stage_a(c), 'rtsim:WidebandMode');
        end

    end
end
