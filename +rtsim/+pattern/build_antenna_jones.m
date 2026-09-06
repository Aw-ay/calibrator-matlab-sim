function [Jtx, Jrx, meta] = build_antenna_jones(patterns, pose, direction, freq_Hz)
    % BUILD_ANTENNA_JONES 构造RP1端口与传播H/V基之间的Jones算子。
    % Jones样值按sqrt(gain)归一化，天线增益只在本算子中计一次。

    if isfield(pose, 'R_antenna_to_enu')
        local = pose.R_antenna_to_enu.' * direction(:);
    else
        local = direction(:);
    end

    [az, el, ~, validDirection] = rtsim.geometry.enu_vec_to_az_el_R(local);
    [J, validity] = rtsim.pattern.pattern_interpolator(patterns, ...
        struct('az_deg', az, 'el_deg', el, 'freq_Hz', freq_Hz));
    if ~validDirection || ~validity.valid
        Jtx = nan(2);
        Jrx = nan(2);
    else
        Jtx = J;

        % 本基线采用互易天线、同一局部H/V端口定义，接收映射为共轭转置。
        Jrx = J';
    end

    meta = struct('az_deg', az, 'el_deg', el, 'validity', validity, ...
        'normalization', 'SQRT_GAIN_POWER_WAVE', 'receive_relation', 'RECIPROCAL_CONJUGATE_TRANSPOSE');
end
