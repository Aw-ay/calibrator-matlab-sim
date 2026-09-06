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
    truth.model_scope = "prescribed trajectory with sinusoidal roll vibration";
    st.last_time_s = t;
end

function requireFields(s, names)
    for k = 1:numel(names)
        if ~isfield(s, names{k})
            error('rtsim:airborne:MissingField', '缺少必需字段%s。', names{k});
        end
    end
end
