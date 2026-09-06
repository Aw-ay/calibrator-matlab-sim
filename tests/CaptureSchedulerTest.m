classdef CaptureSchedulerTest < matlab.unittest.TestCase
    % CaptureSchedulerTest 独立事件、bank、边沿和重放调度行为测试。

    methods (TestClassSetup)

        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end

    end

    methods (Test)

        function eventEngineDoesNotDispatchFutureAndSortsStable(testCase)
            r(1) = struct('available_tick', uint64(7), 'priority', 2, 'type', 'DMA', 'payload', 1);
            r(2) = struct('available_tick', uint64(5), 'priority', 1, 'type', 'READY', 'payload', 2);
            r(3) = struct('available_tick', uint64(5), 'priority', 1, 'type', 'READY', 'payload', 3);
            [e1, st] = rtsim.sim.step_event_engine(r, struct(), struct('gsc0', uint64(0), 'count', 6, ...
                'step_num', 1, 'step_den', 1));
            [e2, ~] = rtsim.sim.step_event_engine(struct([]), st, struct('gsc0', uint64(6), 'count', 2, ...
                'step_num', 1, 'step_den', 1));
            testCase.verifyEqual([e1.payload], [2, 3]);
            testCase.verifyEqual([e2.payload], 1);
        end

        function busyBankIsNotOverwritten(testCase)
            iq = reshape(1:24, 4, 2, 3);
            event = struct('type', 'CAPTURE', 'start_index', 1, 'end_index', 4, 'pulse_id', 10);
            cfg = struct('bank_count', 1, 'initial_consumers', {{'REPLAY', 'DMA'}});
            [d1, st] = rtsim.capture.capture_pingpong_step(iq, event, struct(), cfg);
            [d2, st2, diag] = rtsim.capture.capture_pingpong_step(2 * iq, event, st, cfg);
            testCase.verifyEqual(d1.bank_generation, uint64(1));
            testCase.verifyEmpty(d2);
            testCase.verifyEqual(st2.banks(1).raw, iq);
            testCase.verifyEqual(diag.dropped_no_bank, 1);
        end

        function consumerArbiterGivesReplayHardPriority(testCase)
            bank = struct('generation', 1, 'busy', true, 'references', struct('REPLAY', 1, 'ANALYSIS', 0, 'DMA', 1));
            st = struct('banks', bank);
            req(1) = struct('consumer', 'DMA', 'bank_id', 1, 'bank_generation', 1, 'bytes', 8);
            req(2) = struct('consumer', 'REPLAY', 'bank_id', 1, 'bank_generation', 1, 'bytes', 8);
            [grants, ~, diag] = rtsim.capture.consumer_arbiter_step(req, st, struct('budget_bytes', 8));
            testCase.verifyEqual(grants(1).consumer, 'REPLAY');
            testCase.verifyEqual(grants(1).bytes, 8);
            testCase.verifyEqual(diag.remaining_budget_bytes, 0);
        end

        function edgeFusionAndLowQualityFallback(testCase)
            x = [zeros(4, 1); (0:7)' / 7; ones(4, 1)];
            iq = [x, x];
            good = rtsim.capture.edge_fuse_2_8(iq, [1, numel(x)], struct('level_definition', 'HALF_POWER', ...
                'noise_power', 0));
            bad = rtsim.capture.edge_fuse_2_8(ones(12, 2), [1, 12], struct('level_definition', 'HALF_AMPLITUDE', ...
                'noise_power', 0));
            testCase.verifyEqual(good.quality, 'GOOD');
            testCase.verifyGreaterThan(good.covariance_samples2, 0);
            testCase.verifyEqual(bad.quality, 'LOW');
            testCase.verifyFalse(bad.valid);
        end

        function referenceMapNeverDoubleCompensates(testCase)
            pdw = struct('toa_s', 1, 'peak_power_W', [1, 1]);
            meta = struct('reference_plane', 'ADC_RAW', 'applied_compensations', {{}});
            cal = struct('id', 'RX1', 'power_gain_correction', 4, 'output_reference_plane', 'RP1_RX');
            ledger = struct('corrections', struct('id', 'CABLE', 'delay_s', 0.1, 'applied_in_iq', false));
            first = rtsim.capture.pdw_reference_map(pdw, meta, cal, ledger);
            meta.reference_plane = first.reference_plane;
            meta.applied_compensations = first.applied_compensations;
            second = rtsim.capture.pdw_reference_map(first, meta, cal, ledger);
            testCase.verifyEqual(second.toa_s, 0.9, 'AbsTol', 1e-12);
            testCase.verifyEqual(second.peak_power_W, [4, 4], 'AbsTol', 1e-12);
        end

        function schedulerChecksGenerationReadinessAndSinglePort(testCase)
            d(1) = struct('pulse_id', 1, 'bank_id', 1, 'bank_generation', 2, 'ready_tick', 5, 'sample_count', 4);
            d(2) = struct('pulse_id', 2, 'bank_id', 2, 'bank_generation', 1, 'ready_tick', 5, 'sample_count', 3);
            c(1) = struct('pulse_id', 1, 'start_tick', 6);
            c(2) = struct('pulse_id', 2, 'start_tick', 6);
            st = struct('bank_generations', [2, 1]);
            [requests, ~, diag] = rtsim.replay.replay_scheduler_step(d, c, st, struct('gsc0', uint64(0), ...
                'count', 20, 'step_num', 1, 'step_den', 1));
            testCase.verifyEqual([requests.actual_start_tick], [6, 10]);
            testCase.verifyEqual(diag.queued_for_port, 1);
        end

    end
end
