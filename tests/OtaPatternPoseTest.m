classdef OtaPatternPoseTest < matlab.unittest.TestCase
    methods (Test)

        function originalGrid(test)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = rtsim.pattern.load_farfield_pattern(struct('file', ...
                fullfile(root, 'uav_pattern', 'farfield_resolution1deg.txt')));
            test.verifySize(p.field_samples, [181 360 2]);
            [v, m] = rtsim.pattern.sample_farfield(p, 0, 0, NaN);
            test.verifyEqual(v(1), 10^(6.640 / 20) * exp(1j * deg2rad(317.838)), 'AbsTol', 1e-12);
            test.verifyFalse(m.has_full_jones);
            test.verifyLessThan(p.gain_consistency_max_dB, 0.011);
            test.verifyEqual(numel(p.source_sha256{1}), 64);
            test.verifyEqual(rtsim.pattern.sample_farfield(p, 31, 360, NaN), ...
                rtsim.pattern.sample_farfield(p, 31, 0, NaN));
        end

        function composePose(test)
            s = struct('position_m', [1 2 3], 'velocity_mps', [0 0 0], ...
                'roll_deg', 20, 'pitch_deg', 30, 'yaw_deg', 40, 'angular_rate_body_rps', [0 0 1]);
            m = struct('roll_offset_deg', 10, 'pitch_offset_deg', 25, 'phase_center_ant_m', [0 1 0]);
            p = rtsim.airborne.antenna_pose_step(s, m, [1 0 0], struct('roll_deg', 0));
            R = rtsim.geometry.rotation_zyx(20, 30, 40);
            A = R * rtsim.geometry.rotation_zyx(10, 25, 0);
            test.verifyEqual(p.R_antenna_to_enu, A, 'AbsTol', 1e-14);
            test.verifyEqual(p.phase_center_position_m, [1 2 3] + (R * [1; 0; 0] + A * [0; 1; 0]).', 'AbsTol', 1e-14);
            test.verifyEqual(norm(p.quaternion_wxyz), 1, 'AbsTol', 1e-14);
        end

        function excitationModeAndQualification(test)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = rtsim.pattern.load_farfield_pattern(struct('file', ...
                fullfile(root, 'uav_pattern', 'farfield_resolution1deg.txt'), ...
                'frequency_Hz', 2.8e9, 'excited_port', 'JOINT_HV', 'basis', 'LUDWIG3'));
            test.verifyError(@() rtsim.pattern.build_antenna_jones(p, struct(), [1; 0; 0], 2.8e9), ...
                'rtsim:pattern:IncompleteJones');
            p.mode = 'EXCITATION_MODE_ONLY';
            [tx, rx, m] = rtsim.pattern.build_antenna_jones(p, struct(), [1; 0; 0], 2.8e9);
            test.verifySize(tx, [2 1]);
            test.verifySize(rx, [1 2]);
            test.verifyFalse(m.validity.full_polarization_qualified);
            g = struct('az_deg', 0, 'el_deg', 0, 'freq_Hz', 2.8e9, 'range_m', 1000);
            v = rtsim.pattern.check_pattern_validity(p, g, struct('require_polarization', true));
            test.verifyFalse(v.qualified);
            test.verifyFalse(v.polarization_qualified);
            p.has_full_jones = true;
            v = rtsim.pattern.check_pattern_validity(p, g, struct('require_polarization', true));
            test.verifyFalse(v.qualified);
        end

        function phaseSeamAndIndependentExcitations(test)
            f1 = [tempname '.txt'];
            f2 = [tempname '.txt'];
            cleanup = onCleanup(@() deleteFiles({f1, f2}));
            A = [1 1; 0 1] / sqrt(2);
            J = [1 0.2j; 0.3 exp(0.4j)];
            writeFixture(f1, J * A(:, 1), false);
            writeFixture(f2, J * A(:, 2), false);
            cfg = struct('files', {{f1, f2}}, 'frequency_Hz', 1, 'excitation_matrix', A, ...
                'basis', 'LUDWIG3', 'metadata_verified', true);
            p = rtsim.pattern.load_farfield_pattern(cfg);
            [v, m] = rtsim.pattern.sample_farfield(p, 45, 315, 1);
            test.verifyEqual(v, J, 'AbsTol', 1e-10);
            test.verifyTrue(m.has_full_jones);
            writeFixture(f1, [1; 1], true);
            p = rtsim.pattern.load_farfield_pattern(struct('file', f1));
            v = rtsim.pattern.sample_farfield(p, 90, 315, NaN);
            test.verifyLessThan(real(v(1)), -0.99);
            test.verifyLessThan(abs(imag(v(1))), 1e-12);
            clear cleanup;
        end

        function invalidGridAndUnknownBasis(test)
            f = [tempname '.txt'];
            cleanup = onCleanup(@() deleteFiles({f}));
            writeFixture(f, [1; 1], false);
            fid = fopen(f, 'a');
            fprintf(fid, '0 0 3 0 0 0 0 0\n');
            fclose(fid);
            test.verifyError(@() rtsim.pattern.load_farfield_pattern(struct('file', f)), ...
                'rtsim:pattern:DuplicateGrid');
            writeFixture(f, [1; 1], false);
            lines = splitlines(string(fileread(f)));
            lines(4) = [];
            fid = fopen(f, 'w');
            fprintf(fid, '%s', join(lines, newline));
            fclose(fid);
            test.verifyError(@() rtsim.pattern.load_farfield_pattern(struct('file', f)), ...
                'rtsim:pattern:MissingGrid');
            writeFixture(f, [1; 1], false);
            p = rtsim.pattern.load_farfield_pattern(struct('file', f, 'frequency_Hz', 1, ...
                'mode', 'EXCITATION_MODE_ONLY'));
            test.verifyFalse(p.pole_check.evaluated);
            test.verifyError(@() rtsim.pattern.build_antenna_jones(p, struct(), [1; 0; 0], 1), ...
                'rtsim:pattern:UnknownBasis');
            [~, m] = rtsim.pattern.sample_farfield(p, 90, 0, 2);
            test.verifyFalse(m.valid);
            clear cleanup;
        end

        function observationIsolationAndRates(test)
            m = struct('measurement_time_s', 0, 'available_time_s', 0, 'available', true, ...
                'position_m', [1; 2; 3], 'velocity_mps', [0; 0; 0], 'roll_deg', 10, ...
                'pitch_deg', 20, 'yaw_deg', 30, 'angular_rate_body_rps', [0; 0; 1]);
            [p, ~, ~] = rtsim.airborne.nav_time_aligner(m, struct(), struct(), 1);
            R = rtsim.geometry.rotation_zyx(10, 20, 30) * rtsim.geometry.rotation_zyx(0, 0, rad2deg(1));
            test.verifyEqual(p.R_ENU_FROM_BODY, R, 'AbsTol', 1e-12);
            m = rmfield(m, 'angular_rate_body_rps');
            [p, ~, ~] = rtsim.airborne.nav_time_aligner(m, struct(), struct(), 1);
            test.verifyEqual([p.roll_deg p.pitch_deg p.yaw_deg], [10 20 30]);
            s = struct('position_m', [0; 0; 0], 'velocity_mps', [0; 0; 0], 'roll_deg', 0, ...
                'angular_rate_body_rps', [0; 0; 1]);
            a = rtsim.airborne.antenna_pose_step(s, struct(), [1; 0; 0], struct());
            test.verifyEqual(a.phase_center_velocity_mps, [0; 1; 0], 'AbsTol', 1e-14);
        end

        function reciprocalPhase(test)
            p = struct('kind', 'MEASURED_CSV', 'az_deg', 90, 'el_deg', 0, 'freq_Hz', 1, ...
                'az_range_deg', [90 90], 'el_range_deg', [0 0], 'freq_range_Hz', [1 1], ...
                'jones_samples', exp(1j * 0.7) * eye(2), 'has_phase', true);
            [tx, rx] = rtsim.pattern.build_antenna_jones(p, struct(), [1; 0; 0], 1);
            test.verifyEqual(rx, tx.', 'AbsTol', 1e-14);
            test.verifyEqual(rx * tx, exp(1j * 1.4) * eye(2), 'AbsTol', 1e-14);
        end

    end
end

function writeFixture(file, v, phaseSeam)
    fid = fopen(file, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'synthetic CST fixture\nheader\n');
    for phi = [0 90 180 270]
        for theta = [0 90 180]
            phase = rad2deg(angle(v));
            if phaseSeam
                if phi == 0
                    phase(:) = 179;
                else
                    phase(:) = -179;
                end
            end

            fprintf(fid, '%.12g %.12g %.12g %.12g %.12g %.12g %.12g 0\n', ...
                theta, phi, 10 * log10(sum(abs(v).^2)), 20 * log10(abs(v(1))), phase(1), ...
                20 * log10(abs(v(2))), phase(2));
        end
    end
end

function deleteFiles(files)
    for k = 1:numel(files)
        if isfile(files{k})
            delete(files{k});
        end
    end
end
