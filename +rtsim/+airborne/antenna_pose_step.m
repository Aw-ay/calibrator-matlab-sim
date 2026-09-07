function antennaState = antenna_pose_step(platformState, mounting, leverArm, vibration)
    % ANTENNA_POSE_STEP BODY杆臂与ANT相位中心分别旋转，安装姿态不通过欧拉角相加实现。

    rb = field_or(platformState, 'R_ENU_FROM_BODY', ...
        rtsim.geometry.rotation_zyx(field_or(platformState, 'roll_deg', 0), ...
        field_or(platformState, 'pitch_deg', 0), field_or(platformState, 'yaw_deg', 0)));
    rm = field_or(mounting, 'R_BODY_FROM_ANT', rtsim.geometry.rotation_zyx( ...
        field_or(mounting, 'roll_offset_deg', 0), field_or(mounting, 'pitch_offset_deg', 0), ...
        field_or(mounting, 'yaw_offset_deg', 0)));
    rv = rtsim.geometry.rotation_zyx(field_or(vibration, 'roll_deg', 0), ...
        field_or(vibration, 'pitch_deg', 0), field_or(vibration, 'yaw_deg', 0));
    ra = rb * rm * rv;
    validate_rotation(rb);
    validate_rotation(rm);
    validate_rotation(ra);
    pc = field_or(mounting, 'phase_center_ant_m', [0 0 0]);
    arm = leverArm(:) + rm * rv * pc(:);
    offset = rb * arm;
    antennaState.phase_center_position_m = platformState.position_m + reshape(offset, size(platformState.position_m));
    velocity = field_or(platformState, 'velocity_mps', zeros(size(platformState.position_m)));
    r = deg2rad(field_or(platformState, 'roll_deg', 0));
    p = deg2rad(field_or(platformState, 'pitch_deg', 0));
    rates = deg2rad([field_or(platformState, 'roll_rate_dps', 0); ...
        field_or(platformState, 'pitch_rate_dps', 0); field_or(platformState, 'yaw_rate_dps', 0)]);
    defaultOmega = [1 0 -sin(p); 0 cos(r) sin(r) * cos(p); 0 -sin(r) cos(r) * cos(p)] * rates;
    omega = field_or(platformState, 'angular_rate_body_rps', defaultOmega);
    extra = rb * cross(omega(:), arm);
    if isfield(vibration, 'angular_rate_ant_rps')
        extra = extra + ra * cross(vibration.angular_rate_ant_rps(:), pc(:));
    end

    antennaState.phase_center_velocity_mps = velocity + reshape(extra, size(velocity));
    antennaState.R_ENU_FROM_BODY = rb;
    antennaState.R_BODY_FROM_ANT = rm * rv;
    antennaState.R_ENU_FROM_ANT = ra;
    antennaState.R_antenna_to_enu = ra;
    antennaState.R_enu_to_antenna = ra.';
    antennaState.rotation_body_to_local = ra;
    antennaState.quaternion_wxyz = rtsim.geometry.rotation_to_quaternion(ra);
    antennaState.pitch_deg = asind(max(-1, min(1, -ra(3, 1))));
    antennaState.roll_deg = atan2d(ra(3, 2), ra(3, 3));
    antennaState.yaw_deg = atan2d(ra(2, 1), ra(1, 1));
    antennaState.model_scope = "active ZYX; BODY lever arm; ANT phase center";
end

function validate_rotation(R)
    if ~isequal(size(R), [3 3]) || any(~isfinite(R), 'all') || ...
            norm(R.' * R - eye(3), 'fro') > 1e-9 || abs(det(R) - 1) > 1e-9
        error('rtsim:airborne:InvalidRotation', '旋转矩阵须正交且行列式为+1。');
    end
end

function v = field_or(s, n, d)
    if isfield(s, n)
        v = s.(n);
    else
        v = d;
    end
end
