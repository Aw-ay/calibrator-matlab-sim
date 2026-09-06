classdef ExtendedFrontendTest < matlab.unittest.TestCase
    % EXTENDEDFRONTENDTEST 前端独立非理想模型及跨块确定性测试

    methods (Test)

        function commonAndRangeNoiseArePartitionInvariant(testCase)
            commonCfg = struct('gain', 1, 'noise_power_W', 0.2, 'saturation_amplitude', Inf);
            rangeCfg = struct('gains', [1 2 4], 'response', repmat(eye(2), 1, 1, 3), ...
                'noise_power_W', [0.1 0.2 0.3]);
            wholeCommon = rtsim.rx.rx_common_step(zeros(13, 2), struct('seed', 19), commonCfg, []);
            [a, st] = rtsim.rx.rx_common_step(zeros(5, 2), struct('seed', 19), commonCfg, []);
            b = rtsim.rx.rx_common_step(zeros(8, 2), st, commonCfg, []);
            testCase.verifyEqual([a; b], wholeCommon);
            wholeRange = rtsim.rx.rx_three_range_step(zeros(13, 2), struct('seed', 23), rangeCfg, []);
            [a, st] = rtsim.rx.rx_three_range_step(zeros(5, 2), struct('seed', 23), rangeCfg, []);
            b = rtsim.rx.rx_three_range_step(zeros(8, 2), st, rangeCfg, []);
            testCase.verifyEqual(cat(1, a, b), wholeRange);
        end

        function correlatedNoiseHasRequestedCovarianceAndPartitions(testCase)
            grid = localGrid(20000);
            spec = struct('noise_power_W', [1 4]);
            corr = [1 0.5; 0.5 1];
            [whole, ~, ledger] = rtsim.rx.noise_model(struct('seed', 31), spec, grid, corr);
            grid.count = uint64(7000);
            [a, st] = rtsim.rx.noise_model(struct('seed', 31), spec, grid, corr);
            grid.count = uint64(13000);
            [b, ~] = rtsim.rx.noise_model(st, spec, grid, corr);
            testCase.verifyEqual([a; b], whole);
            empirical = (whole' * whole) / size(whole, 1);
            testCase.verifyEqual(real(diag(empirical)).', [1 4], 'RelTol', 0.04);
            testCase.verifyEqual(ledger.reference_plane, "INPUT");
        end

        function nsdBudgetSubtractsIncludedSources(testCase)
            spec = struct('nsd_dBFS_per_Hz', -100, 'bandwidth_Hz', 1e6);
            ref = struct('full_scale_rms', 1);
            budget = rtsim.rx.adc_sigma_from_nsd(spec, ref, struct('variance', 2e-5));
            testCase.verifyEqual(budget.total_variance, 1e-4, 'RelTol', 1e-12);
            testCase.verifyEqual(budget.residual_variance, 8e-5, 'RelTol', 1e-12);
            spec.nsd_dBFS_per_Hz = -120;
            testCase.verifyError(@() rtsim.rx.adc_sigma_from_nsd(spec, ref, struct('variance', 2e-5)), ...
                'rtsim:rx:IncompatibleNoiseBudget');
        end

        function jitterEquivalentIsPartitionInvariant(testCase)
            cfg = struct('mode', "ENVELOPE_EQUIVALENT", 'rms_jitter_s', 2e-12);
            plan = struct('adc_input_frequency_Hz', 2.8e9);
            whole = rtsim.rx.adc_jitter_inject(ones(17, 1), struct('seed', 41), cfg, plan);
            [a, st] = rtsim.rx.adc_jitter_inject(ones(6, 1), struct('seed', 41), cfg, plan);
            [b, ~] = rtsim.rx.adc_jitter_inject(ones(11, 1), st, cfg, plan);
            testCase.verifyEqual([a; b], whole);
        end

        function dnlAndInterleaveModelsUseExplicitConventions(testCase)
            transfer = rtsim.rx.adc_make_inl_from_dnl([0 0.5 -0.5 0], ...
                struct('bits', 2, 'lsb', 0.25, 'lower_endpoint', -0.5));
            testCase.verifyEqual(transfer.code_widths, [0.25 0.375 0.125 0.25]);
            testCase.verifyTrue(all(diff(transfer.thresholds) >= 0));
            cfg = struct('gain', [1 2], 'offset', [0 1], 'phase_rad', [0 0]);
            [a, st] = rtsim.rx.adc_apply_interleave_spurs(ones(3, 1), struct(), cfg, "ENVELOPE_EQUIVALENT");
            b = rtsim.rx.adc_apply_interleave_spurs(ones(2, 1), st, cfg, "ENVELOPE_EQUIVALENT");
            testCase.verifyEqual([a; b], [1; 3; 1; 3; 1]);
        end

        function adcMetricsReportsDefinedTimeDomainQuantities(testCase)
            grid = localGrid(4);
            definition = struct('full_scale', 1, 'clipped', [false; false; true; false]);
            metrics = rtsim.rx.adc_metrics([1; -1; 1i; -1i], definition, grid);
            testCase.verifyEqual(metrics.mean_power, 1);
            testCase.verifyEqual(metrics.clipped_fraction, 0.25);
            testCase.verifyEqual(metrics.scope, "TIME_DOMAIN_BASIC");
        end

        function clockAndLatencyModelsExposeAssumptions(testCase)
            grid = localGrid(4);
            cfg = struct('frequency_offset_ppm', 2, 'time_offset_s', 1e-9, ...
                'random_walk_std_s_per_sqrt_s', 0);
            [clocks, st] = rtsim.time.clock_model_step(grid, struct(), cfg, []);
            testCase.verifyEqual(clocks.time_error_s(1), 1e-9, 'AbsTol', 1e-18);
            testCase.verifyGreaterThan(clocks.time_error_s(end), clocks.time_error_s(1));
            testCase.verifyEqual(st.sample_count, uint64(4));
            measured = struct('rf_propagation_s', 1e-6, 'filter_group_delay_s', 2e-6, ...
                'hardware_pipeline_s', 3e-6, 'queue_wait_s', 4e-6);
            ledger = rtsim.time.latency_ledger(struct(), measured, "ACCOUNTING_ONLY");
            testCase.verifyEqual(ledger.total_s, 10e-6, 'AbsTol', 1e-18);
        end

        function alignmentAndMtsApplyOnlyDeclaredIntegerDelay(testCase)
            x = [(1:5).' (11:15).'];
            cfg = struct('integer_delay_samples', [0 1], 'verified_layout', true);
            [y, ~, diag] = rtsim.time.channel_alignment_step(x, struct(), cfg);
            testCase.verifyEqual(y, [x(:, 1) [0; x(1:4, 2)]]);
            testCase.verifyFalse(diag.hardware_equivalent);
            mtsCfg = struct('enabled', true, 'mode', "BEHAVIORAL_RESIDUAL", ...
                'integer_delay_samples', [1 0], 'verified_layout', true);
            y = rtsim.time.model_mts(x, struct(), mtsCfg, struct());
            testCase.verifyEqual(y, [[0; x(1:4, 1)] x(:, 2)]);
        end

        function hugeTimeAdvanceDetectsOverflow(testCase)
            grid = localGrid(1);
            grid.gsc0 = intmax('uint64') - uint64(2);
            next = rtsim.time.advance_time_grid(grid, uint64(2));
            testCase.verifyEqual(next.gsc0, intmax('uint64'));
            testCase.verifyError(@() rtsim.time.advance_time_grid(grid, uint64(3)), ...
                'rtsim:time:CounterOverflow');
        end

    end
end

function grid = localGrid(count)
    grid = struct('gsc0', uint64(100), 'fraction0_ticks', 0, ...
        'step_num', uint64(1), 'step_den', uint64(1), 'count', uint64(count), ...
        'fs_Hz', 500e6, 'f_gsc_Hz', 500e6, 'epoch_id', "E0", ...
        'clock_id', "C0", 'index0', uint64(0));
end
