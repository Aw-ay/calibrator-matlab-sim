function [Jtx, Jrx, meta] = build_antenna_jones(patterns, pose, direction, freq_Hz)
    % BUILD_ANTENNA_JONES RP1端口/激励模式 -> 统一ENU横向实基中的RP2复场。
    % 互易在同一实电场基、同一相量参考下为transpose；Hermitian会错误抹除天线复相位。
    % direction始终指天线向外；接收波沿反方向到达，公共实基定义对方向反号不变。

    direction = direction(:);
    if numel(direction) ~= 3 || any(~isfinite(direction)) || norm(direction) == 0
        error('rtsim:pattern:Direction', '方向须为有限非零三维向量。');
    end

    direction = direction / norm(direction);
    R = eye(3);
    if isfield(pose, 'R_antenna_to_enu')
        R = pose.R_antenna_to_enu;
    end

    local = R.' * direction;
    [az, el] = rtsim.geometry.enu_vec_to_az_el_R(local);
    if strcmpi(patterns.kind, 'CST_FARFIELD')

        % CST球坐标phi从ANT +X朝+Y，与ENU北起方位角不是同一个角。

        az = atan2d(local(2), local(1));
    end

    [J, validity] = rtsim.pattern.pattern_interpolator(patterns, ...
        struct('az_deg', az, 'el_deg', el, 'freq_Hz', freq_Hz));
    basis = 'PROJECTED_YZ';
    if isfield(patterns, 'basis')
        basis = patterns.basis;
    end

    if strcmpi(patterns.kind, 'CST_FARFIELD') && ~patterns.has_full_jones && ...
            ~strcmpi(patterns.mode, 'EXCITATION_MODE_ONLY')
        error('rtsim:pattern:IncompleteJones', '单文件只含激励模式场；须显式选择EXCITATION_MODE_ONLY。');
    end

    Benu = rtsim.pattern.field_basis(direction, 'PROJECTED_YZ');
    Bant = rtsim.pattern.field_basis(local, basis);
    basisRotation = Benu.' * R * Bant;
    Jtx = basisRotation * J;
    if ~validity.valid
        Jtx(:) = NaN;
    end

    Jrx = Jtx.';
    meta = struct('az_deg', az, 'el_deg', el, 'validity', validity, ...
        'normalization', 'SQRT_REALIZED_GAIN_POWER_WAVE', ...
        'receive_relation', 'RECIPROCAL_TRANSPOSE_COMMON_REAL_FIELD_BASIS', ...
        'local_basis', basis, 'propagation_basis', 'ENU_PROJECTED_YZ', ...
        'basis_rotation', basisRotation, 'direction_convention', 'OUTWARD_FROM_ANTENNA');
    meta.theta_deg = 90 - el;
    meta.phi_deg = atan2d(local(2), local(1));
end
