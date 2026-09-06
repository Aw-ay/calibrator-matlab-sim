classdef GeometryChannelTest < matlab.unittest.TestCase
    %GeometryChannelTest 几何、方向图和传播基线测试。

    methods (TestClassSetup)
        function addProjectPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (Test)
        function testWgs84Equator(testCase)
            [ecef, R] = rtsim.geometry.geodetic2ecef_wgs84(0, 0, 0);
            testCase.verifyEqual(ecef, [6378137; 0; 0], AbsTol=1e-6);
            testCase.verifyEqual(R * [0; 1; 0], [1; 0; 0], AbsTol=1e-12);
            testCase.verifyEqual(R * [1; 0; 0], [0; 0; 1], AbsTol=1e-12);
        end

        function testEcefToEnuBatch(testCase)
            [station, R] = rtsim.geometry.geodetic2ecef_wgs84(0, 0, 0);
            points = station + [0, 0; 1, 0; 0, 2];
            enu = rtsim.geometry.ecef_to_enu(points, station, R);
            testCase.verifyEqual(enu, [1, 0; 0, 2; 0, 0], AbsTol=1e-12);
        end

        function testAzElConventionAndZeroVector(testCase)
            [az, el, range, valid] = rtsim.geometry.enu_vec_to_az_el_R([1, 0; 0, 1; 0, 1]);
            testCase.verifyEqual(az, [90, 0], AbsTol=1e-12);
            testCase.verifyEqual(el, [0, 45], AbsTol=1e-12);
            testCase.verifyEqual(range, [1, sqrt(2)], AbsTol=1e-12);
            testCase.verifyTrue(all(valid));
            [az0, el0, range0, valid0] = rtsim.geometry.enu_vec_to_az_el_R([0; 0; 0]);
            testCase.verifyTrue(isnan(az0) && isnan(el0));
            testCase.verifyEqual(range0, 0, AbsTol=0);
            testCase.verifyFalse(valid0);
        end

        function testPoseFramePreservesRoll(testCase)
            q = [cosd(45), sind(45), 0, 0];
            frame = rtsim.geometry.beam_frame_from_pose(q, eye(3), [0; 0; 1]);
            testCase.verifyEqual(frame.R_antenna_to_enu(:, 2), [0; 0; 1], AbsTol=1e-12);
            testCase.verifyEqual(det(frame.R_antenna_to_enu), 1, AbsTol=1e-12);
        end

        function testDirectionConventionAdapter(testCase)
            source = struct('frame', 'ENU');
            target = struct('convention', 'MATLAB_AZ_EL');
            angles = rtsim.geometry.coordinate_convention_adapter([1; 0; 0], source, target);
            testCase.verifyEqual(angles.az_deg, 0, AbsTol=1e-12);
            testCase.verifyEqual(angles.el_deg, 0, AbsTol=1e-12);
        end

        function testDirectPathFriisAndJones(testCase)
            tx = struct('position_m', [0; 0; 0], 'tx_jones', diag([2, 1]));
            rx = struct('position_m', [300; 0; 0], 'rx_jones', eye(2));
            cfg = struct('fc_Hz', 3e9);
            path = rtsim.channel.direct_path(tx, rx, cfg);
            lambda = 299792458 / cfg.fc_Hz;
            expected = lambda / (4*pi*300) * exp(-1j*2*pi*300/lambda) * diag([2, 1]);
            testCase.verifyEqual(path.delay_s, 300/299792458, AbsTol=1e-15);
            testCase.verifyEqual(path.matrix, expected, AbsTol=1e-14);
        end

        function testMirrorAndBistaticPaths(testCase)
            tx = struct('position_m', [0; 0; 10]);
            rx = struct('position_m', [30; 0; 10]);
            surface = struct('height_m', 0, 'coefficient', -0.5);
            reflected = rtsim.channel.mirror_path(tx, rx, surface, 1e9);
            scatterer = struct('position_m', [15; 0; 0], 'scattering_matrix', eye(2), 'effective_area_m2', 1);
            scattered = rtsim.channel.bistatic_scatter_path(tx, rx, scatterer, struct('fc_Hz', 1e9));
            testCase.verifyEqual(reflected.distance_m, sqrt(30^2 + 20^2), AbsTol=1e-12);
            testCase.verifySize(reflected.matrix, [2, 2]);
            testCase.verifyGreaterThan(scattered.delay_s, reflected.delay_s - 1e-15);
            testCase.verifySize(scattered.matrix, [2, 2]);
        end

        function testCausalFractionalDelayAcrossBlocks(testCase)
            grid = struct('fs_Hz', 10);
            path = struct('delay_s', 0.15, 'matrix', eye(2));
            [y1, st] = rtsim.channel.combine_complex_paths([1, 0; 0, 0], path, struct(), grid);
            [y2, ~] = rtsim.channel.combine_complex_paths(zeros(2, 2), path, st, grid);
            testCase.verifyEqual(y1(:, 1), [0; 0.5], AbsTol=1e-12);
            testCase.verifyEqual(y2(:, 1), [0.5; 0], AbsTol=1e-12);
            testCase.verifyEqual([y1(:, 2); y2(:, 2)], zeros(4, 1), AbsTol=1e-12);
        end

        function testChannelStepCableAndOta(testCase)
            x = [1, 2; 0, 0];
            cable = struct('fc_Hz', 1e9, 'fs_Hz', 10, 'kind', 'CABLE', ...
                'cable_gain', 2, 'cable_delay_s', 0);
            [yc, ~, dc] = rtsim.channel.channel_step(x, struct(), cable, struct());
            geom = struct('tx_position_m', [0; 0; 0], 'rx_position_m', [1; 0; 0]);
            ota = struct('fc_Hz', 1e9, 'fs_Hz', 10, 'kind', 'OTA', ...
                'reflection', struct('enabled', false, 'coefficient', 0, 'height_m', 0));
            [yo, ~, do] = rtsim.channel.channel_step(x, struct(), ota, geom);
            testCase.verifyEqual(yc, 2*x, AbsTol=1e-12);
            testCase.verifyEqual(dc.path_count, 1);
            testCase.verifySize(yo, size(x));
            testCase.verifyEqual(do.path_count, 1);
        end

        function testIdealJonesAndMeasuredCsv(testCase)
            ideal = rtsim.pattern.load_pattern_config(struct('kind', 'IDEAL'));
            [Ji, vi] = rtsim.pattern.pattern_interpolator(ideal, struct('az_deg', 12, 'el_deg', 4, 'freq_Hz', 1e9));
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            file = fullfile(folder, 'pattern.csv');
            T = table([0; 90], [0; 0], [1e9; 1e9], [1; 0], [0; 1], ...
                [0; 0], [0; 0], [0; 0], [0; 0], [1; 1], [0; 0], ...
                'VariableNames', {'az_deg','el_deg','freq_Hz','J11_re','J11_im','J12_re','J12_im','J21_re','J21_im','J22_re','J22_im'});
            writetable(T, file);
            measured = rtsim.pattern.load_pattern_config(struct('kind', 'MEASURED_CSV', 'file', file));
            [Jm, vm] = rtsim.pattern.pattern_interpolator(measured, struct('az_deg', 45, 'el_deg', 0, 'freq_Hz', 1e9));
            testCase.verifyEqual(Ji, eye(2), AbsTol=1e-12);
            testCase.verifyTrue(vi.valid);
            testCase.verifyEqual(Jm(1, 1), (1+1j)/2, AbsTol=1e-12);
            testCase.verifyTrue(vm.valid);
        end

        function testPatternQualificationRejectsMissingPhase(testCase)
            patterns = struct('kind', 'MEASURED', 'has_phase', false, 'az_range_deg', [-90, 90], ...
                'el_range_deg', [-20, 20], 'freq_range_Hz', [1e9, 2e9], 'far_field_min_m', 10, ...
                'jones_samples', repmat(eye(2), 1, 1, 2));
            geometry = struct('range_m', 100, 'az_deg', 0, 'el_deg', 0, 'freq_Hz', 1.5e9);
            requirements = struct('require_phase', true, 'require_polarization', true, 'max_condition_number', 100);
            validity = rtsim.pattern.check_pattern_validity(patterns, geometry, requirements);
            testCase.verifyFalse(validity.qualified);
            testCase.verifyTrue(any(validity.reasons == "MISSING_PHASE"));
        end
    end
end
