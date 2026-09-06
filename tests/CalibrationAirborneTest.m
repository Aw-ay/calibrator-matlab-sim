classdef CalibrationAirborneTest < matlab.unittest.TestCase
    % 校准与机载适配器的行为契约测试

    methods (TestClassSetup)

        function addProjectPath(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(root);
        end

    end

    methods (Test)

        function calibrationRecoversThreeRxRangesAndTx(testCase)
            plant.rx_response = cat(3, [2 0.1; 0.2 1.5], ...
                [1.2 0.05; -0.1 0.9], [0.7 0.02; 0.03 0.6]);
            plant.tx_response = [1.8 -0.1; 0.15 1.3];
            standards = struct('noise_std', 0, 'bias_std', 0);
            tasks.rx_inputs = [1 0; 0 1; 1 1; 1 -1];
            tasks.tx_inputs = [1 0; 0 1; 1 1i; 1i 1];

            m = rtsim.calibration.simulate_calibration_session( ...
                plant, standards, tasks, 41);
            rx = rtsim.calibration.estimate_rx_cal(m, struct(), ...
                struct('lambda', 0, 'max_gain', inf));
            tx = rtsim.calibration.estimate_tx_cal(m, struct(), ...
                struct('lambda', 0, 'max_gain', inf));

            testCase.verifySize(rx.coefficients, [2 2 3]);
            testCase.verifyEqual(rx.status, "OK");
            testCase.verifyEqual(tx.status, "OK");
            for k = 1:3
                testCase.verifyEqual(rx.coefficients(:, :, k) * ...
                    plant.rx_response(:, :, k), eye(2), 'AbsTol', 1e-11);
            end

            testCase.verifyEqual(tx.coefficients * plant.tx_response, ...
                eye(2), 'AbsTol', 1e-11);
        end

        function calibrationSimulationIsSeededAndRejectsRankOneDrive(testCase)
            plant.rx_response = repmat(eye(2), 1, 1, 3);
            plant.tx_response = eye(2);
            standards = struct('noise_std', 0.01, 'bias_std', 0.02);
            tasks.rx_inputs = [1 0; 0 1; 1 1];
            tasks.tx_inputs = tasks.rx_inputs;
            a = rtsim.calibration.simulate_calibration_session(plant, standards, tasks, 9);
            b = rtsim.calibration.simulate_calibration_session(plant, standards, tasks, 9);
            c = rtsim.calibration.simulate_calibration_session(plant, standards, tasks, 10);
            testCase.verifyEqual(a.rx(1).output, b.rx(1).output);
            testCase.verifyNotEqual(a.rx(1).output, c.rx(1).output);

            bad = a;
            bad.rx(1).input = ones(3, 2);
            testCase.verifyError(@() rtsim.calibration.estimate_rx_cal( ...
                bad, struct(), struct('lambda', 0, 'max_gain', inf)), ...
                'rtsim:calibration:RankDeficient');
        end

        function regularizedInverseHonorsGainLimit(testCase)
            response = [1 0; 0 1e-6];
            op = rtsim.calibration.solve_regularized_inverse(response, ...
                struct('lambda', 1e-8, 'max_gain', 20));
            testCase.verifyLessThanOrEqual(norm(op.matrix, 2), 20 + 1e-10);
            testCase.verifyEqual(op.lambda, 1e-8);
            testCase.verifyGreaterThanOrEqual(op.residual, 0);
        end

        function applyAndHoldoutValidationUseOnlyEstimatedSet(testCase)
            calRx.coefficients = cat(3, eye(2), 2 * eye(2), 3 * eye(2));
            calRx.id = "rx-test";
            calTx.coefficients = [2 0; 0 3];
            calTx.id = "tx-test";
            [rxOut, ~, rxDiag] = rtsim.calibration.apply_rx_cal( ...
                [1 2], struct(), calRx, struct('range_id', 2));
            [txOut, ~, txDiag] = rtsim.calibration.apply_tx_cal( ...
                [1 2], struct(), calTx, struct());
            testCase.verifyEqual(rxOut, [2 4]);
            testCase.verifyEqual(txOut, [2 6]);
            testCase.verifyEqual(rxDiag.calibration_id, "rx-test");
            testCase.verifyEqual(txDiag.calibration_id, "tx-test");

            holdout.rx(1).input = [1 0; 0 1];
            holdout.rx(1).output = [1 0; 0 1];
            holdout.rx(2) = holdout.rx(1);
            holdout.rx(3) = holdout.rx(1);
            holdout.tx = holdout.rx(1);
            report = rtsim.calibration.validate_calibration( ...
                struct('rx', struct('coefficients', repmat(eye(2), 1, 1, 3)), ...
                'tx', struct('coefficients', eye(2))), holdout, ...
                struct('max_rmse', 1e-12));
            testCase.verifyTrue(report.pass);
            testCase.verifyEqual(report.dataset_role, "independent_holdout");
        end

        function platformTruthUsesLocalGridTimeAndPrescribedTrajectory(testCase)
            trajectory.position_m = [10 20 30];
            trajectory.velocity_mps = [2 -1 0.5];
            trajectory.acceleration_mps2 = [0.5 0 0];
            trajectory.roll_deg = 4;
            trajectory.roll_rate_dps = 2;
            grid = struct('index0', 20, 'fs_Hz', 10);
            [truth, ~] = rtsim.airborne.platform_truth_step( ...
                struct(), trajectory, struct('roll_amplitude_deg', 0, ...
                'frequency_Hz', 1, 'phase_rad', 0), grid);
            testCase.verifyEqual(truth.time_s, 2);
            testCase.verifyEqual(truth.position_m, [15 18 31], 'AbsTol', 1e-12);
            testCase.verifyEqual(truth.velocity_mps, [3 -1 0.5], 'AbsTol', 1e-12);
            testCase.verifyEqual(truth.roll_deg, 8, 'AbsTol', 1e-12);
        end

        function navigationDelayAndAlignerAreCausal(testCase)
            truth = struct('time_s', 1, 'position_m', [10 0 0], ...
                'velocity_mps', [2 0 0], 'roll_deg', 3);
            cfg = struct('delay_s', .25, 'position_bias_m', [1 0 0], ...
                'velocity_bias_mps', [0 0 0], 'roll_bias_deg', 1, ...
                'noise_std_m', 0, 'available', true);
            [obs, ~] = rtsim.airborne.nav_sensor_step(truth, struct(), cfg);
            testCase.verifyEqual(obs.measurement_time_s, 1);
            testCase.verifyEqual(obs.available_time_s, 1.25);
            testCase.verifyEqual(obs.position_m, [11 0 0]);

            future = obs;
            future.measurement_time_s = 2;
            future.available_time_s = 3;
            future.position_m = [100 0 0];
            [pose, ~, diag] = rtsim.airborne.nav_time_aligner( ...
                [obs future], struct(), struct(), 1.5);
            testCase.verifyEqual(pose.position_m, [12 0 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(diag.messages_used, 1);
        end

        function navigationPreservesColumnVectorContract(testCase)
            truth = struct('time_s', 1, 'position_m', [10; 20; 30], ...
                'velocity_mps', [1; 2; 3], 'roll_deg', 0);
            cfg = struct('delay_s', 0, 'position_bias_m', [1; 1; 1], ...
                'velocity_bias_mps', [2; 2; 2], 'roll_bias_deg', 0, ...
                'noise_std_m', 0, 'available', true);
            obs = rtsim.airborne.nav_sensor_step(truth, struct(), cfg);
            testCase.verifySize(obs.position_m, [3 1]);
            testCase.verifySize(obs.velocity_mps, [3 1]);
            testCase.verifyEqual(obs.position_m, [11; 21; 31]);
        end

        function firstOrderAirModelsAndIndependentScatterAreExplicit(testCase)
            [temps, thermalState] = rtsim.airborne.air_thermal_step( ...
                struct(), struct('temperature_C', 20), struct('power_W', 10), ...
                struct('thermal_resistance_K_per_W', 2, ...
                'thermal_capacitance_J_per_K', 10, 'sensor_tau_s', 5), 1);
            testCase.verifyEqual(temps.junction_C, 21, 'AbsTol', 1e-12);
            testCase.verifyNotEqual(temps.sensor_C, temps.junction_C);
            testCase.verifyTrue(isfield(thermalState, 'junction_C'));

            [supplies, observations] = rtsim.airborne.air_power_step( ...
                struct(), struct('voltage_V', 24, 'capacity_Ah', 5), ...
                struct('current_A', 10), struct('internal_resistance_Ohm', .1, ...
                'nominal_voltage_V', 24, 'undervoltage_V', 22, ...
                'telemetry_tau_s', 1), .1);
            testCase.verifyEqual(supplies.bus_voltage_V, 23, 'AbsTol', 1e-12);
            testCase.verifyFalse(observations.undervoltage);

            radarTx = [1 0; 0 1];
            [echo, ~] = rtsim.airborne.platform_scatter_step(radarTx, ...
                struct('range_m', 100, 'phase_rad', 0), ...
                struct('amplitude_gain', .01, 'polarization_matrix', eye(2)), struct());
            testCase.verifyEqual(echo, .000001 * radarTx, 'AbsTol', 1e-14);
        end

        function antennaEmcAndAdapterKeepTruthSeparate(testCase)
            p = struct('position_m', [1 2 3], 'roll_deg', 0);
            a = rtsim.airborne.antenna_pose_step(p, ...
                struct('roll_offset_deg', 0), [1 0 0], struct('roll_deg', 0));
            testCase.verifyEqual(a.phase_center_position_m, [2 2 3]);

            grid = struct('index0', 5, 'fs_Hz', 10);
            [d, ~] = rtsim.airborne.air_emc_step(struct(), ...
                struct('rotation_Hz', 2, 'load_fraction', .5), ...
                struct('rf_amplitude_sqrt_W', .1, 'clock_phase_rad', .02, ...
                'supply_modulation_fraction', .01, 'digital_error_probability', 0), grid);
            testCase.verifySize(d.rf_additive, [1 2]);
            testCase.verifyEqual(d.source, "assumption_model");

            providers.truth = struct('position_m', [1 0 0]);
            providers.measurement = struct('position_m', [2 0 0]);
            [plantBoundary, measuredBoundary] = ...
                rtsim.airborne.air_adapter_step(struct(), providers, grid);
            testCase.verifyEqual(plantBoundary.position_m, [1 0 0]);
            testCase.verifyEqual(measuredBoundary.position_m, [2 0 0]);
        end

    end
end
