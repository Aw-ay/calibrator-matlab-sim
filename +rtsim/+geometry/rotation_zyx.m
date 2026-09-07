function R = rotation_zyx(roll_deg, pitch_deg, yaw_deg)
    % ROTATION_ZYX 主动列向量旋转：Rz(yaw)*Ry(pitch)*Rx(roll)。

    cr = cosd(roll_deg);
    sr = sind(roll_deg);
    cp = cosd(pitch_deg);
    sp = sind(pitch_deg);
    cy = cosd(yaw_deg);
    sy = sind(yaw_deg);
    R = [cy -sy 0; sy cy 0; 0 0 1] * [cp 0 sp; 0 1 0; -sp 0 cp] * [1 0 0; 0 cr -sr; 0 sr cr];
end
