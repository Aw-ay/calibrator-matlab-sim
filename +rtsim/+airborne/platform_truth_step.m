function [truth, st] = platform_truth_step(st, trajectory, vibrationCfg, grid)
    % PLATFORM_TRUTH_STEP 按规定轨迹生成局部时刻的平台真值。

    arguments
        st (1, 1) struct
        trajectory (1, 1) struct
        vibrationCfg (1, 1) struct
        grid (1, 1) struct
    end

    requireFields(trajectory, {'position_m', 'velocity_mps', 'acceleration_mps2', ...
        'roll_deg', 'roll_rate_dps'});
    requireFields(vibrationCfg, {'roll_amplitude_deg', 'frequency_Hz', 'phase_rad'});
    requireFields(grid, {'index0', 'fs_Hz'});
    t = double(grid.index0) / grid.fs_Hz;
    truth.time_s = t;
    truth.position_m = trajectory.position_m + trajectory.velocity_mps * t + ...
        0.5 * trajectory.acceleration_mps2 * t^2;
    truth.velocity_mps = trajectory.velocity_mps + trajectory.acceleration_mps2 * t;
    truth.roll_deg = trajectory.roll_deg + trajectory.roll_rate_dps * t + ...
        vibrationCfg.roll_amplitude_deg * sin(2 * pi * vibrationCfg.frequency_Hz * t + ...
        vibrationCfg.phase_rad);
    axes = {'roll', 'pitch', 'yaw'};
    rates = zeros(3, 1);
    for k = 1:3
        axis = axes{k};
        angle = value_or(trajectory, [axis '_deg'], 0);
        rate = value_or(trajectory, [axis '_rate_dps'], 0);
        amplitude = value_or(vibrationCfg, [axis '_amplitude_deg'], 0);
        omega = 2 * pi * vibrationCfg.frequency_Hz;
        phase = omega * t + vibrationCfg.phase_rad;
        truth.([axis '_deg']) = angle + rate * t + amplitude * sin(phase);
        truth.([axis '_rate_dps']) = rate + amplitude * omega * cos(phase);
        rates(k) = deg2rad(truth.([axis '_rate_dps']));
    end

    r = deg2rad(truth.roll_deg);
    p = deg2rad(truth.pitch_deg);
    truth.angular_rate_body_rps = [1 0 -sin(p); 0 cos(r) sin(r) * cos(p); ...
        0 -sin(r) cos(r) * cos(p)] * rates;
    truth.R_ENU_FROM_BODY = rtsim.geometry.rotation_zyx(truth.roll_deg, truth.pitch_deg, truth.yaw_deg);
    truth.quaternion_wxyz = rtsim.geometry.rotation_to_quaternion(truth.R_ENU_FROM_BODY);
    truth.model_scope = "prescribed ZYX trajectory with optional three-axis vibration";
    st.last_time_s = t;
end

function requireFields(s, names)
    for k = 1:numel(names)
        if ~isfield(s, names{k})
            error('rtsim:airborne:MissingField', '缺少必需字段%s。', names{k});
        end
    end
end

function v = value_or(s, n, d)
    if isfield(s, n)
        v = s.(n);
    else
        v = d;
    end
end
