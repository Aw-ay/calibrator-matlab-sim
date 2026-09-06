classdef EndToEndTest < matlab.unittest.TestCase
    % 端到端测试使用独立的距离公式和故障场景。

    methods (TestClassSetup)

        function addProjectPath(test)
            root = fileparts(fileparts(mfilename('fullpath')));
            test.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end

    end

    methods (Test)

        function defaultRange(test)
            cfg = rtsim.config.default_config('ALGORITHM_SMOKE');
            cfg.output.save = false;
            a = run_stage_a(cfg);
            test.verifyEqual(numel(a.pdw), cfg.radar.pulse_count);
            test.verifyLessThan(abs(a.observables.range_m - cfg.target.range_m), 30);
            test.verifyEqual(a.diagnostics.rejected_replays, 0);
        end

        function stationaryRegression(test)
            cfg = rtsim.config.default_config('ALGORITHM_SMOKE');
            cfg.output.save = false;
            a = run_stage_a(cfg);
            b = run_stage_b(cfg);
            test.verifyEqual(a.radar_iq, b.radar_iq, 'AbsTol', 1e-14);
            test.verifyEqual(a.pdw, b.pdw);
        end

        function blockInvariant(test)
            cfg = rtsim.config.default_config('ALGORITHM_SMOKE');
            cfg.output.save = false;
            cfg.sim.block_size = 317;
            a = run_stage_a(cfg);
            cfg.sim.block_size = 1024;
            b = run_stage_a(cfg);
            test.verifyEqual(a.radar_iq, b.radar_iq, 'AbsTol', 1e-12);
            test.verifyEqual([a.pdw.toa_s], [b.pdw.toa_s], 'AbsTol', 1e-12);
        end

        function dmaDoesNotMoveReplay(test)
            cfg = rtsim.config.default_config('ALGORITHM_SMOKE');
            cfg.output.save = false;
            a = run_stage_a(cfg);
            cfg.dataflow.dma_bytes_per_s = 0;
            b = run_stage_a(cfg);
            test.verifyEqual(a.radar_iq, b.radar_iq, 'AbsTol', 1e-12);
            test.verifyGreaterThan(b.diagnostics.dma_pending_bytes, 0);
        end

        function mute(test)
            cfg = rtsim.config.default_config('ALGORITHM_SMOKE');
            cfg.output.save = false;
            cfg.instrument.mode = 'MUTE';
            a = run_stage_a(cfg);
            test.verifyEqual(a.tx_iq, zeros(size(a.tx_iq)), 'AbsTol', 0);
        end

        function illegalLive(test)
            cfg = rtsim.config.default_config('ALGORITHM_SMOKE');
            cfg.instrument.mode = 'LIVE';
            test.verifyError(@() rtsim.config.validate_config(cfg, []), 'rtsim:UnsafeLive');
        end

        function impossibleRange(test)
            cfg = rtsim.config.default_config('ALGORITHM_SMOKE');
            cfg.output.save = false;
            cfg.target.range_m = 1000;
            a = run_stage_a(cfg);
            test.verifyEqual(a.diagnostics.rejected_replays, cfg.radar.pulse_count);
            test.verifyEqual(a.tx_iq, zeros(size(a.tx_iq)), 'AbsTol', 0);
        end

        function endOfPulseRange(test)
            x = complex(ones(20, 2, 3) * 0.1);
            x(end, 1, 1) = 1;
            selection = rtsim.capture.range_select_eop(x, struct('limit', 0.9));
            test.verifyEqual(selection.range_id, 2);
        end

    end
end
