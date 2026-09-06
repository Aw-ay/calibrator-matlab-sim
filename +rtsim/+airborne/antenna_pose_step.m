function antennaState = antenna_pose_step(platformState, mounting, leverArm, vibration)
%ANTENNA_POSE_STEP 将安装角、杆臂和振动加入平台姿态。
arguments
    platformState (1,1) struct
    mounting (1,1) struct
    leverArm (1,3) double
    vibration (1,1) struct
end
if ~isfield(platformState,'position_m') || ~isfield(platformState,'roll_deg') || ...
        ~isfield(mounting,'roll_offset_deg') || ~isfield(vibration,'roll_deg')
    error('rtsim:airborne:MissingField','姿态、安装或振动字段不完整。');
end
roll = platformState.roll_deg + mounting.roll_offset_deg + vibration.roll_deg;
c = cosd(roll); s = sind(roll);
rotation = [1 0 0; 0 c -s; 0 s c];
antennaState.phase_center_position_m = platformState.position_m + ...
    (rotation*leverArm.').';
antennaState.roll_deg = roll;
antennaState.rotation_body_to_local = rotation;
antennaState.model_scope = "roll-only mounting and lever-arm geometry";
end
