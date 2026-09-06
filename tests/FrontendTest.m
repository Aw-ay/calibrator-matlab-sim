classdef FrontendTest < matlab.unittest.TestCase
    %FRONTENDTEST 数字前端基础模型的接口与边界测试

    methods (Test)
        function adcClipRoundUsesSignedFullScale(testCase)
            cfg = struct('bits', 4, 'full_scale', 1);
            x = [-1.2-0.5i; -1+0i; 0.2+1.2i; 1+0i];
            [iCode, qCode, flags] = rtsim.rx.adc_clip_round(x, cfg);
            testCase.verifyEqual(iCode, int32([-8; -8; 2; 7]));
            testCase.verifyEqual(qCode, int32([-4; 0; 7; 0]));
            testCase.verifyEqual(flags.clipped, [true; false; true; true]);
            testCase.verifyEqual(flags.lsb, 0.125);
        end

        function adcPipelineReturnsEnvelopeAndDiagnostics(testCase)
            x = complex(zeros(4, 2, 3));
            x(:, 1, 1) = [0; 0.25; 0.75; 1.5];
            cfg = struct('bits', 4, 'full_scale', 1, 'fidelity', "ENVELOPE");
            [y, st, diag] = rtsim.rx.adc_pipeline(x, struct(), cfg, []);
            testCase.verifySize(y, size(x));
            testCase.verifyClass(y, 'double');
            testCase.verifyEqual(diag.i_code(:, 1, 1), int32([0; 2; 6; 7]));
            testCase.verifyTrue(diag.clipped(4, 1, 1));
            testCase.verifyEqual(st.sample_count, uint64(4));
            testCase.verifyEqual(diag.model_scope, "COMPLEX_ENVELOPE_EQUIVALENT");
        end

        function commonNoiseIsInjectedOnlyBeforeRangeSplit(testCase)
            rng(7);
            cfgCommon = struct('gain', 2, 'noise_power_W', 0.1, ...
                'saturation_amplitude', Inf);
            [common, ~, diag] = rtsim.rx.rx_common_step(zeros(128, 2), struct(), cfgCommon, []);
            cfgRanges = struct('gains', [1 2 4], 'response', repmat(eye(2), 1, 1, 3), ...
                'noise_power_W', 0);
            ranges = rtsim.rx.rx_three_range_step(common, struct(), cfgRanges, []);
            testCase.verifyEqual(ranges(:, :, 2), 2 * ranges(:, :, 1), 'AbsTol', 1e-12);
            testCase.verifyEqual(ranges(:, :, 3), 4 * ranges(:, :, 1), 'AbsTol', 1e-12);
            testCase.verifyGreaterThan(diag.injected_noise_power_W, 0);
        end

        function rangeResponseMixesPolarizations(testCase)
            x = [1 2; 3 4];
            response = zeros(2, 2, 3);
            response(:, :, 1) = [1 1; 0 1];
            response(:, :, 2) = eye(2);
            response(:, :, 3) = eye(2);
            cfg = struct('gains', [1 1 1], 'response', response, 'noise_power_W', 0);
            y = rtsim.rx.rx_three_range_step(x, struct(), cfg, []);
            testCase.verifyEqual(y(:, :, 1), [3 2; 7 4]);
        end

        function ncoIsContinuousAcrossBlocks(testCase)
            grid = struct('fs_Hz', 8);
            cfg = struct('frequency_Hz', 1, 'phase0_rad', 0, 'sign', -1);
            [whole, ~] = rtsim.ddc.nco_mixer(ones(8, 1), struct(), cfg, grid);
            [a, st] = rtsim.ddc.nco_mixer(ones(3, 1), struct(), cfg, grid);
            [b, ~] = rtsim.ddc.nco_mixer(ones(5, 1), st, cfg, grid);
            testCase.verifyEqual([a; b], whole, 'AbsTol', 1e-13);
        end

        function decimatorIsBlockPartitionInvariant(testCase)
            x = complex((1:31).', -(1:31).');
            cfg = struct('coefficients', [0.25 0.5 0.25], 'decimation', 2);
            [whole, ~] = rtsim.ddc.halfband_decimator(x, struct(), cfg);
            [a, st] = rtsim.ddc.halfband_decimator(x(1:9), struct(), cfg);
            [b, ~] = rtsim.ddc.halfband_decimator(x(10:end), st, cfg);
            testCase.verifyEqual([a; b], whole, 'AbsTol', 1e-13);
        end

        function strictConfigurationModelsRejectUnsupportedClaims(testCase)
            testCase.verifyError(@() rtsim.ddc.fixedpoint_model(1, struct('bit_true', true)), ...
                'rtsim:ddc:UnsupportedBitTrue');
            testCase.verifyError(@() rtsim.ddc.frequency_plan(struct(), struct(), struct()), ...
                'rtsim:ddc:IncompleteFrequencyPlan');
            testCase.verifyError(@() rtsim.ddc.design_filter_chain(struct(), struct(), struct()), ...
                'rtsim:ddc:UnprovenFilter');
            testCase.verifyError(@() rtsim.ddc.rfdc_stream_adapter(1, struct(), struct()), ...
                'rtsim:ddc:UnsupportedRfdcLayout');
        end

        function signalBlockContractIsExplicit(testCase)
            grid = localGrid(uint64(10), 4);
            block = rtsim.contract.make_signal_block(zeros(4, 2), grid, "BASEBAND", struct('source', "test"));
            expected = struct('domain', "BASEBAND", 'units', "sqrt_W", ...
                'reference_plane', "ADC_RAW", 'size', [4 2]);
            rtsim.contract.validate_signal_block(block, expected);
            expected.units = "V";
            testCase.verifyError(@() rtsim.contract.validate_signal_block(block, expected), ...
                'rtsim:contract:UnitsMismatch');
        end

        function timeGridAdvancePreservesLargeUint64(testCase)
            g0 = uint64(2)^uint64(60) + uint64(123);
            grid = localGrid(g0, 4);
            grid.step_num = uint64(1);
            grid.step_den = uint64(4);
            grid.fs_Hz = 2e9;
            next = rtsim.time.advance_time_grid(grid, uint64(7));
            testCase.verifyEqual(next.gsc0, g0 + uint64(1));
            testCase.verifyEqual(next.fraction0_ticks, 0.75);
            testCase.verifyEqual(next.index0, uint64(7));
        end

        function gscStampNumbersLanesExactly(testCase)
            grid = localGrid(uint64(2)^uint64(60), 3);
            grid.step_num = uint64(1);
            grid.step_den = uint64(2);
            grid.fs_Hz = 1e9;
            obs = struct('valid', true, 'time_quality', "LOCKED");
            stamp = rtsim.time.gsc_stamp(grid, 2, obs);
            testCase.verifyEqual(stamp.gsc, grid.gsc0);
            testCase.verifyEqual(stamp.fraction_ticks, 0.5);
            testCase.verifyTrue(stamp.valid);
            testCase.verifyEqual(stamp.epoch_id, grid.epoch_id);
        end
    end
end

function grid = localGrid(gsc0, count)
grid = struct('gsc0', gsc0, 'fraction0_ticks', 0, ...
    'step_num', uint64(1), 'step_den', uint64(1), 'count', uint64(count), ...
    'fs_Hz', 500e6, 'f_gsc_Hz', 500e6, 'epoch_id', "E0", ...
    'clock_id', "C0", 'index0', uint64(0));
end
