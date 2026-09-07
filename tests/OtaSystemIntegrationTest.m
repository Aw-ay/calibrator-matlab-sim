classdef OtaSystemIntegrationTest < matlab.unittest.TestCase
    % 主链独立验收：利用解析Jones、功率比及导航扰动，不复刻内部实现。

    methods (TestClassSetup)

        function projectPath(t)
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
        end

    end

    methods (Test)

        function singleElementStageCompatibility(t)
            c = smokeConfig();
            a = run_stage_a(c);
            b = run_stage_b(c);
            t.verifyEqual(a.radar_iq, b.radar_iq, 'AbsTol', 1e-14);
            t.verifyEqual(a.pdw, b.pdw);
            t.verifyEqual(a.array.element_count, 1);
            t.verifyGreaterThan(norm(a.radar_iq, 'fro'), 1e-10);
            t.verifyEqual(numel(a.pdw), 1);
            t.verifyLessThan(abs(a.observables.range_m - c.target.range_m), 30);
        end

        function arrayGainAndNullReachMainChain(t)
            c = smokeConfig();
            base = run_stage_a(c);
            c.radar.array = rtsim.radar_array.default_array_config(c.radar.fc_Hz, [4 4]);
            beam = run_stage_a(c);
            t.verifyEqual(beam.port_rx, 4 * base.port_rx, 'AbsTol', 1e-15);
            ratio = norm(beam.radar_iq, 'fro') / norm(base.radar_iq, 'fro');
            t.verifyEqual(ratio, 16, 'RelTol', 2e-4);
            c.radar.array.steer_az_deg = 30;
            away = run_stage_a(c);
            t.verifyLessThan(norm(away.port_rx, 'fro') / norm(beam.port_rx, 'fro'), 1e-12);
            t.verifyLessThan(norm(away.radar_iq, 'fro'), 1e-15);
        end

        function complexJonesReferencePlanesReachReplay(t)
            c = smokeConfig();
            c.target.reference_plane = 'RP1';
            base = run_stage_a(c);
            j = [.9 * exp(.35i) .12i; .08 - .03i .8 * exp(-.22i)];
            file = [tempname '.csv'];
            cleanup = onCleanup(@() delete(file));
            writeJonesFixture(file, j, c.radar.fc_Hz);
            c.antenna.pattern = struct('kind', 'MEASURED_CSV', 'file', file, ...
                'quality_label', 'SYNTHETIC_INTEGRATION_FIXTURE');
            c.antenna.calibration_pattern = c.antenna.pattern;
            rp1 = run_stage_a(c);
            expected = base.radar_iq(:, 1) * sqrt(2) * (j * j.' * c.radar.polarization).';
            t.verifyLessThan(norm(rp1.radar_iq - expected, 'fro') / norm(expected, 'fro'), 2e-4);
            t.verifyGreaterThan(norm(rp1.radar_iq - base.radar_iq, 'fro') / norm(base.radar_iq, 'fro'), .1);
            c.target.reference_plane = 'RP2_OTA';
            rp2 = run_stage_a(c);
            t.verifyLessThan(norm(rp2.radar_iq - base.radar_iq, 'fro') / norm(base.radar_iq, 'fro'), 2e-4);
            t.verifyEqual(rp2.ota.quality_label, 'SYNTHETIC_INTEGRATION_FIXTURE');
            clear cleanup;
        end

        function observedNavigationCannotChangeIncidentField(t)
            c = smokeConfig();
            c.platform.roll_deg = 13;
            c.platform.pitch_deg = 7;
            c.platform.yaw_deg = 11;
            c.antenna.lever_arm_body_m = [1; .2; -.1];
            c.antenna.mounting.phase_center_ant_m = [.1; .2; .3];
            base = run_stage_a(c);
            c.navigation.position_bias_m = [.01; 0; 0];
            c.navigation.roll_bias_deg = 20;
            biased = run_stage_a(c);
            t.verifyEqual(biased.port_rx, base.port_rx, 'AbsTol', 0);
            t.verifyEqual(biased.ota.pose_log(:, 2:4), base.ota.pose_log(:, 2:4), 'AbsTol', 0);
            t.verifyGreaterThan(norm(biased.ota.pose_log(:, 5:7) - base.ota.pose_log(:, 5:7), 'fro'), .01);
            t.verifyGreaterThan(norm(biased.radar_iq - base.radar_iq, 'fro') / norm(base.radar_iq, 'fro'), .1);
        end

        function poseAndReferenceOperatorStaySeparated(t)
            c = smokeConfig();
            c.antenna.lever_arm_body_m = [1; 0; 0];
            c.antenna.mounting.phase_center_ant_m = [0; 0; 2];
            truth = struct('position_m', [2000; 0; 0], 'velocity_mps', [0; 0; 0], ...
                'roll_deg', 0, 'pitch_deg', 0, 'yaw_deg', 90);
            observed = truth;
            observed.yaw_deg = 0;
            p = rtsim.pattern.load_pattern_config(c.antenna.pattern);
            link = rtsim.sim.ota_link_state(c, p, p, truth, observed, 0);
            t.verifyEqual(link.position_m, [2000; 1; 2], 'AbsTol', 1e-12);
            t.verifyEqual(link.estimate.position_m, [2001; 0; 2], 'AbsTol', 1e-12);
            c.target.polar_matrix = [1 .1i; -.2i .7];
            c.target.reference_plane = 'RP1';
            direct = rtsim.sim.ota_link_state(c, p, p, truth, observed, 0);
            t.verifyEqual(direct.polar_operator, c.target.polar_matrix, 'AbsTol', 0);
            c.target.reference_plane = 'RP2_OTA';
            observed.roll_deg = 25;
            compensated = rtsim.sim.ota_link_state(c, p, p, truth, observed, 0);
            nominal = rtsim.sim.ota_link_state(c, p, p, observed, observed, 0);
            recovered = nominal.tx_uav * compensated.polar_operator * nominal.rx_uav;
            t.verifyEqual(recovered, c.target.polar_matrix, 'AbsTol', 1e-12);
            t.verifyEqual(compensated.tx_uav, direct.tx_uav, 'AbsTol', 0);
            t.verifyGreaterThan(norm(compensated.polar_operator - direct.polar_operator, 'fro'), .1);
        end

    end
end

function c = smokeConfig()
    c = rtsim.config.default_config('ALGORITHM_SMOKE');
    c.output.save = false;
    c.sim.duration_s = 200e-6;
    c.radar.pulse_count = 1;
    c.calibration.noise_std = 0;
    c.calibration.bias_std = 0;
    c.instrument.ranges.response = repmat(eye(2), 1, 1, 3);
    c.instrument.ranges.gains = [1e3 1e2 10];
    c.instrument.tx_response = eye(2);
    c.instrument.adc.enabled = false;
    c.instrument.dac.bits = 31;
end

function writeJonesFixture(file, j, fc)
    % 四角常数复Jones夹具仅用于链路代数验收，无实测资格。

    [az, el] = ndgrid([-180 180], [-90 90]);
    n = numel(az);
    T = table(az(:), el(:), repmat(fc, n, 1), 'VariableNames', {'az_deg', 'el_deg', 'freq_Hz'});
    for row = 1:2
        for col = 1:2
            T.(sprintf('J%d%d_re', row, col)) = repmat(real(j(row, col)), n, 1);
            T.(sprintf('J%d%d_im', row, col)) = repmat(imag(j(row, col)), n, 1);
        end
    end

    writetable(T, file);
end
