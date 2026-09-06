function path = direct_path(txPose, rxPose, cfgChannel)
    % DIRECT_PATH 构造静态单程直达路径；matrix已含自由空间损耗和载频相位。

    c = 299792458;
    validateattributes(txPose.position_m, {'numeric'}, {'real', 'finite', 'numel', 3});
    validateattributes(rxPose.position_m, {'numeric'}, {'real', 'finite', 'numel', 3});
    validateattributes(cfgChannel.fc_Hz, {'numeric'}, {'real', 'finite', 'positive', 'scalar'});
    d = rxPose.position_m(:) - txPose.position_m(:);
    R = norm(d);
    if R <= 0
        error('rtsim:channel:ZeroRange', '收发相位中心不能重合。');
    end

    Jtx = field_or(txPose, 'tx_jones', eye(2));
    Jrx = field_or(rxPose, 'rx_jones', eye(2));
    validateattributes(Jtx, {'numeric'}, {'finite', 'size', [2, 2]});
    validateattributes(Jrx, {'numeric'}, {'finite', 'size', [2, 2]});
    lambda = c / cfgChannel.fc_Hz;
    scalar = lambda / (4 * pi * R) * exp(-1j * 2 * pi * R / lambda);
    path = struct('delay_s', R / c, 'matrix', Jrx * scalar * Jtx, 'distance_m', R, ...
        'direction_tx_to_rx', d / R, 'kind', 'DIRECT', 'valid', true);
end

function value = field_or(s, name, default)
    if isfield(s, name)
        value = s.(name);
    else
        value = default;
    end
end
