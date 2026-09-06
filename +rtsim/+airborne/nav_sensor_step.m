function [navObservations, st] = nav_sensor_step(truth, st, sensorCfg)
%NAV_SENSOR_STEP 生成有偏置、噪声和到达延迟的导航观测。
arguments
    truth (1,1) struct
    st (1,1) struct
    sensorCfg (1,1) struct
end
required = {'delay_s','position_bias_m','velocity_bias_mps', ...
    'roll_bias_deg','noise_std_m','available'};
for k=1:numel(required)
    if ~isfield(sensorCfg,required{k})
        error('rtsim:airborne:MissingField','缺少必需字段%s。',required{k});
    end
end
if ~isfield(st,'sample_index'); st.sample_index = 0; end
if ~isfield(st,'seed'); st.seed = 1; end
stream = RandStream('mt19937ar','Seed',double(st.seed)+double(st.sample_index));
positionNoise = sensorCfg.noise_std_m .* randn(stream,size(truth.position_m));
positionBias = preserveShape(sensorCfg.position_bias_m, truth.position_m, ...
    'position_bias_m');
velocityBias = preserveShape(sensorCfg.velocity_bias_mps, truth.velocity_mps, ...
    'velocity_bias_mps');
navObservations.measurement_time_s = truth.time_s;
navObservations.available_time_s = truth.time_s + sensorCfg.delay_s;
navObservations.position_m = truth.position_m + positionBias + positionNoise;
navObservations.velocity_mps = truth.velocity_mps + velocityBias;
navObservations.roll_deg = truth.roll_deg + sensorCfg.roll_bias_deg;
navObservations.quality = double(logical(sensorCfg.available));
navObservations.available = logical(sensorCfg.available);
navObservations.model_scope = "biased delayed navigation observation";
st.sample_index = st.sample_index + 1;
end

function value = preserveShape(value, reference, fieldName)
if numel(value) ~= numel(reference)
    error('rtsim:airborne:InvalidVectorSize','%s必须与真值向量元素数一致。',fieldName);
end
value = reshape(value,size(reference));
end
