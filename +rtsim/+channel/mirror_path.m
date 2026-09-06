function path = mirror_path(txPose, rxPose, surface, freq_Hz)
    % MIRROR_PATH 以水平平面镜像法构造静态反射路径。

    c = 299792458;
    h = field_or(surface, 'height_m', 0);
    gamma = field_or(surface, 'coefficient', -1);
    tx = txPose.position_m(:);
    rx = rxPose.position_m(:);
    imageTx = tx;
    imageTx(3) = 2 * h - tx(3);
    d = rx - imageTx;
    R = norm(d);
    if R <= 0
        error('rtsim:channel:ZeroRange', '镜像路径长度必须大于零。');
    end

    Jtx = field_or(txPose, 'tx_jones', eye(2));
    Jrx = field_or(rxPose, 'rx_jones', eye(2));
    lambda = c / freq_Hz;
    matrix = Jrx * (gamma * lambda / (4 * pi * R) * exp(-1j * 2 * pi * R / lambda)) * Jtx;
    path = struct('delay_s', R / c, 'matrix', matrix, 'distance_m', R, ...
        'direction_image_to_rx', d / R, 'reflection_coefficient', gamma, 'kind', 'MIRROR', 'valid', true);
end

function value = field_or(s, name, default)
    if isfield(s, name)
        value = s.(name);
    else
        value = default;
    end
end
