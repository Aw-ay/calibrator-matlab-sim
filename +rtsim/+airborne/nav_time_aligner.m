function [poseEstimate, st, diag] = nav_time_aligner(navObservations, ppsCapture, st, requestTimes)
    % NAV_TIME_ALIGNER 只使用请求时刻前已到达的消息并作线性外推。

    arguments
        navObservations struct
        ppsCapture struct %#ok<INUSA>
        st (1, 1) struct
        requestTimes (:, 1) double
    end

    if ~isfield(st, 'cache')
        st.cache = struct([]);
    end

    incoming = navObservations(:).';
    allMessages = [st.cache incoming];
    poseEstimate = repmat(struct('time_s', [], 'position_m', [], 'velocity_mps', [], ...
        'roll_deg', [], 'pitch_deg', [], 'yaw_deg', [], 'angular_rate_body_rps', [], ...
        'R_ENU_FROM_BODY', [], 'quaternion_wxyz', [], 'source_measurement_time_s', []), size(requestTimes));
    usedCounts = zeros(size(requestTimes));
    for q = 1:numel(requestTimes)
        requestTime = requestTimes(q);
        eligible = arrayfun(@(x) x.available && ...
            x.available_time_s <= requestTime, allMessages);
        candidates = allMessages(eligible);
        if isempty(candidates)
            error('rtsim:airborne:NoCausalObservation', ...
                '请求时刻前没有已到达的导航消息。');
        end

        [~, idx] = max([candidates.measurement_time_s]);
        msg = candidates(idx);
        dt = requestTime - msg.measurement_time_s;
        poseEstimate(q).time_s = requestTime;
        poseEstimate(q).position_m = msg.position_m + msg.velocity_mps * dt;
        poseEstimate(q).velocity_mps = msg.velocity_mps;
        axes = {'roll', 'pitch', 'yaw'};
        angles = zeros(1, 3);
        for k = 1:3
            axis = axes{k};
            angles(k) = value_or(msg, [axis '_deg'], 0);
        end

        R = rtsim.geometry.rotation_zyx(angles(1), angles(2), angles(3));
        if isfield(msg, 'angular_rate_body_rps')
            w = msg.angular_rate_body_rps(:);
            W = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
            R = R * expm(W * dt);
            angles = [atan2d(R(3, 2), R(3, 3)), asind(max(-1, min(1, -R(3, 1)))), atan2d(R(2, 1), R(1, 1))];
        else
            rates = zeros(3, 1);
            for k = 1:3
                rates(k) = value_or(msg, [axes{k} '_rate_dps'], 0);
                angles(k) = angles(k) + rates(k) * dt;
            end

            r = deg2rad(angles(1));
            p = deg2rad(angles(2));
            w = [1 0 -sin(p); 0 cos(r) sin(r) * cos(p); 0 -sin(r) cos(r) * cos(p)] * deg2rad(rates);
            R = rtsim.geometry.rotation_zyx(angles(1), angles(2), angles(3));
        end

        for k = 1:3
            poseEstimate(q).([axes{k} '_deg']) = angles(k);
        end

        poseEstimate(q).angular_rate_body_rps = w;
        poseEstimate(q).R_ENU_FROM_BODY = R;
        poseEstimate(q).quaternion_wxyz = rtsim.geometry.rotation_to_quaternion(R);
        poseEstimate(q).source_measurement_time_s = msg.measurement_time_s;
        usedCounts(q) = numel(candidates);
    end

    st.cache = allMessages;
    diag.messages_used = usedCounts;
    diag.method = "causal constant-velocity extrapolation";
end

function v = value_or(s, n, d)
    if isfield(s, n)
        v = s.(n);
    else
        v = d;
    end
end
