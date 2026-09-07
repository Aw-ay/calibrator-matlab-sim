classdef SystemSamplingTest < matlab.unittest.TestCase
    % 正式RFSoC系统等效采样与物理时序的独立回归。

    methods (Test)

        function rateRelations(test)
            c = rtsim.config.default_config();
            test.verifyEqual(c.adc.fs_real_Hz / 8, c.rfdc.output_fs_Hz);
            test.verifyEqual(c.rfdc.output_fs_Hz / 8, c.pl.output_fs_Hz);
            bad = c;
            bad.rfdc.interface_clock_Hz = 20e6;
            test.verifyError(@() rtsim.config.validate_config(bad), 'rtsim:RateMismatch');
            bad = c;
            bad.adc.fs_real_Hz = 3e9;
            test.verifyError(@() rtsim.config.validate_config(bad), 'rtsim:RateMismatch');
            bad = c;
            bad.rf.fc_Hz = 2e9;
            test.verifyError(@() rtsim.config.validate_config(bad), 'rtsim:RFCarrier');
            bad = c;
            bad.capture.bank_capacity_samples = 2048;
            test.verifyError(@() rtsim.config.validate_config(bad), 'rtsim:Capacity');
            bad = c;
            bad.radar.pulse_width_s = bad.radar.pri_s;
            test.verifyError(@() rtsim.config.validate_config(bad), 'rtsim:PulseTiming');
        end

        function laneAndTimeOrder(test)
            x = reshape(1:48 * 2 * 3, 48, 2, 3);
            p = rtsim.ddc.pack_spc(x, 8);
            test.verifySize(p, [6, 8, 2, 3]);
            test.verifyEqual(squeeze(p(3, :, 2, 3)), x(17:24, 2, 3).');
            test.verifyEqual(rtsim.ddc.unpack_spc(p), x);
            c = rtsim.config.default_config();
            [y, ~] = rtsim.ddc.halfband_decimator(x, struct(), struct('coefficients', 1, 'decimation', 8));
            test.verifyEqual(y, x(1:8:end, :, :));
            test.verifyEqual((0:5)' / c.pl.output_fs_Hz, (0:8:40)' / c.rfdc.output_fs_Hz);
        end

        function firArbitraryBlocks(test)
            c = rtsim.config.default_config();
            x = reshape(sin((1:6006) * .017), 1001, 2, 3);
            [whole, ~] = rtsim.ddc.halfband_decimator(x, struct(), c.pl.filter);
            state = struct();
            parts = complex(zeros(0, 2, 3));
            first = 1;
            for count = [1, 7, 19, 2, 300, 672]
                [y, state] = rtsim.ddc.halfband_decimator(x(first:first + count - 1, :, :), state, c.pl.filter);
                parts = cat(1, parts, y);
                first = first + count;
            end

            test.verifyEqual(parts, whole, 'AbsTol', 1e-14);
        end

        function firPassband(test)
            c = rtsim.config.default_config();
            f = linspace(-10e6, 10e6, 2001);
            h = abs(exp(-2i * pi * f(:) / c.rfdc.output_fs_Hz * (0:numel(c.pl.filter.coefficients) - 1)) * ...
                c.pl.filter.coefficients.');
            test.verifyLessThan(max(abs(20 * log10(h))), 0.1);
        end

        function firStopband(test)
            c = rtsim.config.default_config();
            f = linspace(31.25e6, 250e6, 10001);
            h = abs(exp(-2i * pi * f(:) / c.rfdc.output_fs_Hz * (0:numel(c.pl.filter.coefficients) - 1)) * ...
                c.pl.filter.coefficients.');
            test.verifyLessThan(max(h), 10^(-60 / 20));
        end

        function mainChainBlockInvariant(test)
            c = SystemSamplingTest.shortConfig();
            c.sim.block_size = 73;
            a = run_stage_a(c);
            c.sim.block_size = 1024;
            b = run_stage_a(c);
            test.verifyEqual(a.radar_iq, b.radar_iq, 'AbsTol', 1e-18);
            test.verifyEqual(a.records, b.records);
            test.verifyEqual(a.frontend.input_samples, a.frontend.output_samples * 8);
        end

        function allPulseWidthsFitBank(test)
            for width = [10, 30, 50, 80, 100, 120] * 1e-6
                c = SystemSamplingTest.shortConfig();
                c.radar.pulse_width_s = width;
                c.instrument.mode = 'MUTE';
                c.sim.duration_s = 170e-6;
                a = run_stage_a(c);
                test.verifyEqual(numel(a.records), 1);
                test.verifyEqual(a.diagnostics.dropped_captures, 0);
                test.verifyLessThanOrEqual(a.records.count, 8192);
                expected = round((width + 4e-6) * c.pl.output_fs_Hz);
                test.verifyLessThanOrEqual(abs(a.records.count - expected), c.capture.fir_tail_samples + 3);
            end
        end

        function physicalDetectionTimes(test)
            a = rtsim.config.default_config('ALGORITHM_SMOKE');
            b = rtsim.config.default_config();
            for field = {'pretrigger', 'posttrigger', 'end_hold'}
                name = field{1};
                test.verifyEqual(a.capture.([name '_s']), b.capture.([name '_s']));
                test.verifyLessThanOrEqual(abs(a.capture.([name '_samples']) / a.pl.output_fs_Hz - ...
                    b.capture.([name '_samples']) / b.pl.output_fs_Hz), 1 / b.pl.output_fs_Hz);
            end

            b.capture.end_hold_s = 3e-6;
            b = rtsim.config.derive_config(b);
            test.verifyEqual(b.capture.end_hold_samples, round(3e-6 * b.pl.output_fs_Hz));
        end

        function zeroDmaDoesNotMoveReplay(test)
            c = SystemSamplingTest.shortConfig();
            a = run_stage_a(c);
            c.dataflow.dma_bytes_per_s = 0;
            b = run_stage_a(c);
            test.verifyEqual(a.radar_iq, b.radar_iq);
            test.verifyEqual([a.records.t_tx_actual_s], [b.records.t_tx_actual_s]);
            test.verifyGreaterThan(b.diagnostics.dma_pending_bytes, 0);
        end

        function physicalEchoDistances(test)
            for range = [20, 50, 100, 200] * 1000
                c = SystemSamplingTest.shortConfig();
                c.target.range_m = range;
                c.radar.receive_gate_m = [500, 220000];
                c.sim.duration_s = c.radar.start_s + 2 * range / c.constants.c_mps + 30e-6;
                a = run_stage_a(c);
                test.verifyEqual(a.diagnostics.rejected_replays, 0);
                expected = c.radar.start_s + 2 * range / c.constants.c_mps;
                measured = c.radar.start_s + 2 * a.observables.range_m / c.constants.c_mps;
                test.verifyLessThan(abs(measured - expected), 2 / c.pl.output_fs_Hz);
                r = a.records;
                test.verifyGreaterThanOrEqual(r.t_cmd_s, r.t_data_ready_s);
                test.verifyEqual(r.t_tx_actual_s, r.t_cmd_s + c.instrument.fixed_latency_s, 'AbsTol', 1e-15);
                test.verifyEqual(r.t_tx_actual_s, r.t_tx_target_s, 'AbsTol', 1e-15);
            end
        end

        function stationarySharedCore(test)
            c = SystemSamplingTest.shortConfig();
            a = run_stage_a(c);
            b = run_stage_b(c);
            test.verifyEqual(a.radar_iq, b.radar_iq);
            test.verifyEqual(a.pdw, b.pdw);
        end

        function knownJonesMapping(test)
            c = SystemSamplingTest.shortConfig();
            c.instrument.adc.enabled = false;
            c.calibration.noise_std = 0;
            c.calibration.bias_std = 0;
            c.instrument.tx_response = [1.2 * exp(.2i), .03; .01i, .8 * exp(-.3i)];
            for k = 1:3
                c.instrument.ranges.response(:, :, k) = [1.3 * exp(.4i), .02; .01i, .7 * exp(-.2i)];
            end

            c.target.polar_matrix = [1, .2i; .3, .7 * exp(.4i)];
            for basis = eye(2)
                c.radar.polarization = basis;
                a = run_stage_a(c);
                ideal = c;
                ideal.instrument.tx_response = eye(2);
                ideal.instrument.ranges.response = repmat(eye(2), 1, 1, 3);
                b = run_stage_a(ideal);
                test.verifyLessThan(norm(a.tx_iq - b.tx_iq, 'fro') / norm(b.tx_iq, 'fro'), 2e-3);
            end
        end

        function adcSpecialtyMatchesIdeal(test)
            for carrier = [2.7e9, 2.8e9, 3e9]
                for tone = [-10e6, 3e6, 10e6]
                    a = rtsim.ddc.rfdc_adc_specialty('fc_Hz', carrier, 'tone_Hz', tone);
                    test.verifyEqual(a.nyquist_zone, 2);
                    test.verifyEqual(a.aliased_carrier_Hz, carrier - 4e9);
                    test.verifyLessThan(a.relative_rms_error, 1e-3);
                end
            end

            b = rtsim.ddc.rfdc_adc_specialty('jitter_rms_s', 1e-12, 'bits', 8);
            test.verifyGreaterThan(b.relative_rms_error, a.relative_rms_error);
        end

        function replayActualTimeRequiresExecution(test)
            c = SystemSamplingTest.shortConfig();
            a = run_stage_a(c);
            test.verifyEqual(a.records.replay_status, 'COMPLETED');
            test.verifyEqual(a.records.t_tx_actual_s, a.records.t_tx_target_s, 'AbsTol', 1e-15);
            test.verifyGreaterThan(max(abs(a.tx_iq(:))), 0);
        end

        function replayPllFaultHasNoActualTime(test)
            c = SystemSamplingTest.shortConfig();
            c.safety.pll_locked = false;
            a = run_stage_a(c);
            test.verifyTrue(a.records.replay_accepted);
            test.verifyEqual(a.records.replay_status, 'BLOCKED');
            test.verifyTrue(isnan(a.records.t_tx_actual_s));
            test.verifyTrue(isfinite(a.records.t_tx_target_s));
            test.verifyEqual(a.tx_iq, zeros(size(a.tx_iq)));
        end

        function replayDisabledDacHasNoActualTime(test)
            c = SystemSamplingTest.shortConfig();
            c.instrument.dac.valid = false;
            a = run_stage_a(c);
            test.verifyTrue(a.records.replay_accepted);
            test.verifyEqual(a.records.replay_status, 'BLOCKED');
            test.verifyTrue(isnan(a.records.t_tx_actual_s));
            test.verifyEqual(a.tx_iq, zeros(size(a.tx_iq)));
        end

        function replayOutsideWindowHasNoActualTime(test)
            c = SystemSamplingTest.shortConfig();
            c.sim.duration_s = 100e-6;
            a = run_stage_a(c);
            test.verifyEqual(a.records.replay_status, 'OUTSIDE_WINDOW');
            test.verifyTrue(isnan(a.records.t_tx_actual_s));
            test.verifyGreaterThan(a.records.t_tx_target_s, c.sim.duration_s);
            test.verifyEqual(a.tx_iq, zeros(size(a.tx_iq)));
        end

        function replayDynamicGateInterruption(test)
            c = SystemSamplingTest.shortConfig();
            a = rtsim.sim.simulate_case(c, 'A', @SystemSamplingTest.interruptedObservation);
            test.verifyEqual(a.records.replay_status, 'INTERRUPTED');
            test.verifyEqual(a.records.t_tx_actual_s, a.records.t_tx_target_s, 'AbsTol', 1e-15);
            test.verifyGreaterThan(max(abs(a.tx_iq(:))), 0);
            test.verifyEqual(a.tx_iq(ceil(170e-6 * c.pl.output_fs_Hz):end, :), ...
                zeros(size(a.tx_iq, 1) - ceil(170e-6 * c.pl.output_fs_Hz) + 1, 2));
        end

        function radarProfiles(test)
            c = rtsim.config.apply_radar_profile(rtsim.config.default_config(), 'LONG_RANGE');
            test.verifyEqual(c.radar.pulse_width_s, 120e-6);
            test.verifyEqual(c.radar.metrics.prf_Hz, 500);
            test.verifyGreaterThan(c.sim.duration_s, c.radar.pri_s * (c.radar.pulse_count - 1));
            test.verifyEqual(c.radar.metrics.sample_period_s, 16e-9);
        end

    end

    methods (Static)

        function obs = interruptedObservation(t)
            obs = struct('measurement_time_s', t, 'available_time_s', t, 'position_m', [2000; 0; 0], ...
                'velocity_mps', zeros(3, 1), 'roll_deg', 0, 'quality', 1, 'available', t < 150e-6);
        end

        function c = shortConfig()
            c = rtsim.config.default_config();
            c.output.save = false;
            c.radar.pulse_count = 1;
            c.sim.duration_s = 200e-6;
        end

    end
end
