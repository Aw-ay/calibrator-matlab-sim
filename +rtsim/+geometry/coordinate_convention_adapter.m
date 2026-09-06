function angles = coordinate_convention_adapter(unitDirections, sourceMeta, targetMeta)
    % COORDINATE_CONVENTION_ADAPTER 经三维单位矢量转换常见方向约定。

    validateattributes(unitDirections, {'numeric'}, {'real', 'finite', 'nrows', 3});
    u = unitDirections ./ vecnorm(unitDirections);
    if any(~isfinite(u), 'all')
        error('rtsim:geometry:ZeroDirection', '方向向量不能含零向量。');
    end

    sourceFrame = upper(string(getfield_default(sourceMeta, 'frame', 'ENU')));
    if sourceFrame == "NED"
        u = [u(2, :); u(1, :); -u(3, :)];
    elseif sourceFrame ~= "ENU"
        error('rtsim:geometry:Convention', '仅支持ENU或NED源坐标架。');
    end

    target = upper(string(getfield_default(targetMeta, 'convention', 'MATLAB_AZ_EL')));
    east = u(1, :);
    north = u(2, :);
    up = u(3, :);
    switch target
        case "MATLAB_AZ_EL"
            angles = struct('az_deg', atan2d(north, east), 'el_deg', atan2d(up, hypot(east, north)));
        case {"ENU_AZ_EL", "NSI_AZ_EL"}
            angles = struct('az_deg', mod(atan2d(east, north), 360), 'el_deg', atan2d(up, hypot(east, north)));
        case {"THETA_PHI", "MATH_THETA_PHI"}
            angles = struct('theta_deg', acosd(up), 'phi_deg', mod(atan2d(north, east), 360));
        otherwise
            error('rtsim:geometry:Convention', '不支持目标方向约定%s。', target);
    end

    angles.unit_directions_enu = u;
end

function value = getfield_default(s, name, default)
    if isfield(s, name)
        value = s.(name);
    else
        value = default;
    end
end
