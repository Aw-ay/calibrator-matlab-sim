function measurements = simulate_calibration_session(plant, standards, calTasks, seed)
%SIMULATE_CALIBRATION_SESSION 生成与验收随机实现隔离的校准测量。
% 行信号按 output = input * response.' 通过二维响应矩阵。
arguments
    plant (1,1) struct
    standards (1,1) struct
    calTasks (1,1) struct
    seed (1,1) double {mustBeInteger, mustBeNonnegative}
end
mustHaveFields(plant, {'rx_response','tx_response'});
mustHaveFields(standards, {'noise_std','bias_std'});
mustHaveFields(calTasks, {'rx_inputs','tx_inputs'});
if ~isequal(size(plant.rx_response), [2 2 3]) || ~isequal(size(plant.tx_response), [2 2])
    error('rtsim:calibration:InvalidResponseSize', ...
        'RX响应必须为2x2x3，TX响应必须为2x2。');
end
if size(calTasks.rx_inputs,2) ~= 2 || size(calTasks.tx_inputs,2) ~= 2
    error('rtsim:calibration:InvalidExcitationSize', '校准激励必须为N×2。');
end

stream = RandStream('mt19937ar', 'Seed', seed);
measurements.seed = seed;
measurements.rx = repmat(struct('input', [], 'output', []), 1, 3);
for rangeId = 1:3
    x = calTasks.rx_inputs;
    bias = complexNoise(stream, [2 2], standards.bias_std);
    noise = complexNoise(stream, size(x), standards.noise_std);
    measurements.rx(rangeId).input = x;
    measurements.rx(rangeId).output = ...
        x * (plant.rx_response(:,:,rangeId) + bias).' + noise;
end
x = calTasks.tx_inputs;
bias = complexNoise(stream, [2 2], standards.bias_std);
measurements.tx.input = x;
measurements.tx.output = x * (plant.tx_response + bias).' + ...
    complexNoise(stream, size(x), standards.noise_std);
measurements.model_scope = "frequency-flat 2x2 complex response";
end

function z = complexNoise(stream, sz, sigma)
validateattributes(sigma, {'numeric'}, {'scalar','real','nonnegative','finite'});
z = sigma / sqrt(2) .* (randn(stream, sz) + 1i*randn(stream, sz));
end

function mustHaveFields(value, names)
for k = 1:numel(names)
    if ~isfield(value, names{k})
        error('rtsim:calibration:MissingField', '缺少必需字段%s。', names{k});
    end
end
end
