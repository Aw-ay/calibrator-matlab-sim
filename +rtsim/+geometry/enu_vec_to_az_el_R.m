function [az_deg, el_deg, range_m, valid] = enu_vec_to_az_el_R(v_enu)
    % ENU_VEC_TO_AZ_EL_R ENU矢量转北起顺时针方位、水平面仰角和距离。

    validateattributes(v_enu, {'numeric'}, {'real', 'finite', 'nrows', 3});
    east = v_enu(1, :);
    north = v_enu(2, :);
    up = v_enu(3, :);
    range_m = sqrt(sum(v_enu.^2, 1));
    horizontal = hypot(east, north);
    valid = range_m > 0;
    az_deg = mod(atan2d(east, north), 360);
    el_deg = atan2d(up, horizontal);
    az_deg(~valid) = NaN;
    el_deg(~valid) = NaN;
end
