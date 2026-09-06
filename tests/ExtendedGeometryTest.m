classdef ExtendedGeometryTest < matlab.unittest.TestCase
    %ExtendedGeometryTest 迟滞几何与方向图离线处理测试。

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (Test)
        function testRetardedGeometryUsesSeparateEvents(testCase)
            c = 299792458;
            trajectories = struct( ...
                'radar', @(t) struct('position_m',[0;0;0], 'velocity_mps',[0;0;0]), ...
                'device', @(t) struct('position_m',[1000 + 100*t;0;0], 'velocity_mps',[100;0;0]));
            txEvent = struct('time_s',0);
            task = struct('turnaround_s',2e-6);
            geometry = rtsim.geometry.solve_retarded_geometry(txEvent, task, trajectories, struct());
            expectedT1 = 1000/(c-100);
            expectedT3 = geometry.t2_s + (1000 + 100*geometry.t2_s)/c;
            testCase.verifyEqual(geometry.t1_s, expectedT1, AbsTol=1e-14);
            testCase.verifyEqual(geometry.t2_s, geometry.t1_s+task.turnaround_s, AbsTol=1e-15);
            testCase.verifyEqual(geometry.t3_s, expectedT3, AbsTol=1e-14);
            testCase.verifyGreaterThan(geometry.device_rx_position_m(1), geometry.device_tx_position_m(1)-1);
            testCase.verifyTrue(geometry.converged);
        end

        function testRenderDoesNotModifyRawPattern(testCase)
            raw = struct('amplitude_linear',[0;1;0], 'tag','raw');
            original = raw;
            displayPattern = rtsim.pattern.render_pattern_sys(raw, struct('kernel',[0.5;0.5]), struct('kernel',1));
            testCase.verifyEqual(raw, original);
            testCase.verifyEqual(displayPattern.Pattern_raw, original);
            testCase.verifyNotEqual(displayPattern.amplitude_linear, original.amplitude_linear);
        end

        function testAbsoluteGainRequiresKnownReference(testCase)
            cuts = struct('amplitude_linear',[1;0.5]);
            badReference = struct('reference_type','DIRECTIVITY','value_dBi',10);
            testCase.verifyError(@() rtsim.pattern.restore_cuts_absolute_gain(cuts,badReference), ...
                'rtsim:pattern:MissingEfficiency');
        end

        function testAmplitudeOnlyReconstructionIsExplicit(testCase)
            cuts = struct('az_deg',[-90;0;90], 'amplitude_linear',[0.2;1;0.2]);
            assumptions = struct('az_grid_deg',[-90,0,90], 'el_grid_deg',[-30,0,30]);
            model = rtsim.pattern.reconstruct_3d_pattern_from_cuts_v2(cuts, assumptions);
            testCase.verifyEqual(model.status, 'APPROX_AMPLITUDE_ONLY');
            testCase.verifyFalse(model.has_phase);
            testCase.verifySize(model.amplitude_linear, [3,3]);
        end

        function testDigitizerRejectsMissingImage(testCase)
            metadata = struct('hue_deg',0,'hue_tolerance_deg',10,'x_limits',[0,1], ...
                'y_limits',[0,1],'plot_box_px',[1,1,10,10]);
            testCase.verifyError(@() rtsim.pattern.digitize_pattern_png("missing-pattern.png",metadata), ...
                'rtsim:pattern:MissingImage');
        end
    end
end
