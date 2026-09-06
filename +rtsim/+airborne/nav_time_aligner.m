function [poseEstimate, st, diag] = nav_time_aligner(navObservations, ppsCapture, st, requestTimes)
%NAV_TIME_ALIGNER 只使用请求时刻前已到达的消息并作线性外推。
arguments
    navObservations struct
    ppsCapture struct %#ok<INUSA>
    st (1,1) struct
    requestTimes (:,1) double
end
if ~isfield(st,'cache'); st.cache = struct([]); end
incoming = navObservations(:).';
allMessages = [st.cache incoming];
poseEstimate = repmat(struct('time_s',[],'position_m',[],'velocity_mps',[], ...
    'roll_deg',[],'source_measurement_time_s',[]), size(requestTimes));
usedCounts = zeros(size(requestTimes));
for q=1:numel(requestTimes)
    requestTime = requestTimes(q);
    eligible = arrayfun(@(x) x.available && ...
        x.available_time_s <= requestTime, allMessages);
    candidates = allMessages(eligible);
    if isempty(candidates)
        error('rtsim:airborne:NoCausalObservation', ...
            '请求时刻前没有已到达的导航消息。');
    end
    [~,idx] = max([candidates.measurement_time_s]);
    msg = candidates(idx);
    dt = requestTime-msg.measurement_time_s;
    poseEstimate(q).time_s = requestTime;
    poseEstimate(q).position_m = msg.position_m + msg.velocity_mps*dt;
    poseEstimate(q).velocity_mps = msg.velocity_mps;
    poseEstimate(q).roll_deg = msg.roll_deg;
    poseEstimate(q).source_measurement_time_s = msg.measurement_time_s;
    usedCounts(q) = numel(candidates);
end
st.cache = allMessages;
diag.messages_used = usedCounts;
diag.method = "causal constant-velocity extrapolation";
end
