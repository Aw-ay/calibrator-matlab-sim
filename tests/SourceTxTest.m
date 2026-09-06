classdef SourceTxTest < matlab.unittest.TestCase
    % 波形调度、同步、DAC、RF、监测和回环基线测试

    methods (TestClassSetup)

        function addProjectPath(~)
            addpath(fileparts(fileparts(mfilename('fullpath'))));
        end

    end

    methods (Test)

        function dacQuantizesComplexEnvelopeAndMutesInvalidInput(testCase)
            x = [.31 + .22i 0; -.7i .8];
            cfg = struct('bits', 4, 'full_scale', 1, 'nco_frequency_Hz', 0, ...
                'phase0_rad', 0, 'valid', true, 'safe_value', 0);
            clock = struct('frequency_error_Hz', 0, 'fs_Hz', 1e6);
            [y, st, d] = rtsim.tx.duc_dac_step(x, struct(), cfg, clock);
            step = 1 / 2^(4 - 1);
            testCase.verifyLessThanOrEqual(max(abs(real(y) / step - round(real(y) / step)), [], 'all'), 1e-12);
            testCase.verifyLessThanOrEqual(max(abs(imag(y) / step - round(imag(y) / step)), [], 'all'), 1e-12);
            testCase.verifyEqual(st.sample_index, size(x, 1));
            testCase.verifyTrue(d.quantized);
            testCase.verifyEqual(rtsim.tx.duc_dac_step([1 -1], struct(), cfg, clock), ...
                [1 - step -1]);
            bad = cfg;
            bad.bits = 1;
            testCase.verifyError(@()rtsim.tx.duc_dac_step(x, struct(), bad, clock), ...
                'rtsim:tx:InvalidDacConfig');
            bad = cfg;
            bad.full_scale = Inf;
            testCase.verifyError(@()rtsim.tx.duc_dac_step(x, struct(), bad, clock), ...
                'rtsim:tx:InvalidDacConfig');
            badClock = clock;
            badClock.fs_Hz = 0;
            testCase.verifyError(@()rtsim.tx.duc_dac_step(x, struct(), cfg, badClock), ...
                'rtsim:tx:InvalidDacConfig');
            cfg.valid = false;
            y = rtsim.tx.duc_dac_step(x, struct(), cfg, clock);
            testCase.verifyEqual(y, complex(zeros(size(x))));
        end

        function rfAppliesMatrixLimitAmPmAndMonitorCoupling(testCase)
            x = [2 0; .5 0];
            cfg = struct('response_matrix', [1 .1; 0 1], 'voltage_gain', 2, ...
                'saturation_amplitude', 1, 'ampm_rad_at_saturation', .2, ...
                'monitor_coupling', .1);
            [port, tap, ~, d] = rtsim.tx.tx_rf_step(x, struct(), cfg, struct('gain_scale', 1));
            testCase.verifyLessThanOrEqual(max(abs(port), [], 'all'), 1 + 1e-12);
            testCase.verifyEqual(tap, .1 * port, 'AbsTol', 1e-12);
            testCase.verifyTrue(d.clipped);
            testCase.verifyEqual(d.clipped_samples, 1);
            testCase.verifyNotEqual(angle(port(1, 1)), 0);
        end

        function monitorUsesIndependentSeededMeasurementChain(testCase)
            tap = ones(4, 2);
            cfg = struct('response_matrix', eye(2), 'bias', [.1 0], ...
                'noise_std', .01, 'seed', 12);
            clock = struct('phase_error_rad', .05);
            [a, ~, d] = rtsim.tx.tx_monitor_step(tap, struct(), cfg, clock);
            [b] = rtsim.tx.tx_monitor_step(tap, struct(), cfg, clock);
            cfg.seed = 13;
            c = rtsim.tx.tx_monitor_step(tap, struct(), cfg, clock);
            testCase.verifyEqual(a.iq, b.iq);
            testCase.verifyNotEqual(a.iq, c.iq);
            testCase.verifyEqual(d.source, "independent_monitor_chain");
            testCase.verifySize(a.power_W, [1 2]);
        end

        function monitorNoiseIsInvariantToBlockPartition(testCase)
            tap = complex(zeros(7, 2));
            cfg = struct('response_matrix', eye(2), 'bias', [0 0], ...
                'noise_std', .1, 'seed', 88);
            clock = struct('phase_error_rad', 0);
            [whole] = rtsim.tx.tx_monitor_step(tap, struct(), cfg, clock);
            [first, st] = rtsim.tx.tx_monitor_step(tap(1:3, :), struct(), cfg, clock);
            [second] = rtsim.tx.tx_monitor_step(tap(4:end, :), st, cfg, clock);
            testCase.verifyEqual([first.iq; second.iq], whole.iq);
        end

        function loopbackRejectsUnsafePowerAndCarriesDelayAcrossBlocks(testCase)
            cfg = struct('response_matrix', eye(2), 'delay_samples', 2, ...
                'max_input_power_W', 1, 'fixture_error_matrix', zeros(2));
            testCase.verifyError(@() rtsim.tx.loopback_channel_step( ...
                [2 0], struct(), cfg), 'rtsim:tx:UnsafeLoopbackPower');
            [a, st] = rtsim.tx.loopback_channel_step([1 0; 0 0], struct(), cfg);
            [b, ~] = rtsim.tx.loopback_channel_step(zeros(2), st, cfg);
            testCase.verifyEqual(a, zeros(2));
            testCase.verifyEqual(b(1, :), [1 0]);
        end

        function burstSchedulerEmitsOnlyFinitePreparedPulses(testCase)
            d = struct('id', 1, 'start_index', uint64(10), 'pulse_width_samples', 3, ...
                'pri_samples', 5, 'pulse_count', 2, 'source', "DDS", ...
                'available_index', uint64(5), 'prepare_samples', 2);
            grid = struct('index0', uint64(8), 'count', 12);
            [events, st] = rtsim.source.burst_scheduler_step(struct(), d, grid);
            testCase.verifyEqual([events.start_index], uint64([10 15]));
            testCase.verifyEqual([events.end_index], uint64([12 17]));
            testCase.verifyEqual(string({events.source}), ["DDS" "DDS"]);
            testCase.verifyEqual(st.emitted_count, 2);
            bad = d;
            bad.available_index = uint64(9);
            [events, ~, diag] = rtsim.source.burst_scheduler_step(struct(), bad, grid);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(diag.rejected_reason, "INSUFFICIENT_PREPARATION");
        end

        function sourceSyncSeparatesPpsFromFrequencyAndRfPhase(testCase)
            radar = struct('frequency_Hz', 10e6, 'phase_rad', 0);
            inst = struct('frequency_Hz', 10e6 + 5, 'phase_rad', .3);
            trigger = struct('pps_locked', true, 'quality', 1);
            cfg = struct('shared_frequency_reference', false, 'phase_strategy', "DECLARED_FREE_RUNNING");
            sync = rtsim.source.source_sync_model(radar, inst, trigger, cfg);
            testCase.verifyTrue(sync.pps_aligned);
            testCase.verifyFalse(sync.frequency_coherent);
            testCase.verifyFalse(sync.rf_phase_coherent);
            testCase.verifyEqual(sync.frequency_offset_Hz, 5);
            cfg.shared_frequency_reference = true;
            cfg.phase_strategy = "LOCKED";
            sync = rtsim.source.source_sync_model(radar, radar, trigger, cfg);
            testCase.verifyTrue(sync.frequency_coherent);
            testCase.verifyTrue(sync.rf_phase_coherent);
        end

    end
end
