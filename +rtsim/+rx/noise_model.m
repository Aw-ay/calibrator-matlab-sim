function [noise, st, ledger] = noise_model(st, specification, grid, correlation)
%NOISE_MODEL 生成复高斯带内噪声；功率按每个复样点 mean(abs(x)^2) 定义。
arguments
    st struct
    specification struct
    grid struct
    correlation double
end
rtsim.time.validate_time_grid(grid);
assert(isfield(specification, 'noise_power_W'), 'rtsim:rx:InvalidNoiseSpec', ...
    '基础模型要求显式 noise_power_W。');
p = double(specification.noise_power_W(:).');
c = numel(p);
assert(all(isfinite(p)) && all(p >= 0) && isequal(size(correlation), [c c]), ...
    'rtsim:rx:InvalidNoiseSpec', '功率和相关矩阵维度无效。');
assert(norm(correlation-correlation', 'fro') <= 1e-12 && ...
    all(abs(diag(correlation)-1) <= 1e-12), 'rtsim:rx:InvalidNoiseCorrelation', ...
    'correlation 必须为 Hermitian 且对角为 1。');
covariance = diag(sqrt(p)) * correlation * diag(sqrt(p));
[L, flag] = chol(covariance, 'lower');
assert(flag == 0 || all(p == 0), 'rtsim:rx:InvalidNoiseCorrelation', '噪声协方差必须正定。');
n = double(grid.count);
if all(p == 0)
    noise = complex(zeros(n, c));
else
    stream = localStream(st, 1003);
    draws = randn(stream, 2*c, n).';
    white = (draws(:,1:2:end) + 1i*draws(:,2:2:end)) / sqrt(2);
    noise = white * L';
    st.rng_state = stream.State;
end
st.sample_count = localField(st, 'sample_count', uint64(0)) + grid.count;
ledger = struct('reference_plane', string(localField(specification, 'reference_plane', "INPUT")), ...
    'requested_covariance_W', covariance, 'bandlimit', "DISCRETE_WHITE_OVER_NYQUIST", ...
    'included_sources', string(localField(specification, 'included_sources', "UNSPECIFIED")));
end

function value = localField(s, name, defaultValue)
if isfield(s, name), value = s.(name); else, value = defaultValue; end
end

function stream = localStream(st, defaultSeed)
stream = RandStream('mt19937ar', 'Seed', double(localField(st, 'seed', defaultSeed)));
if isfield(st, 'rng_state'), stream.State = st.rng_state; end
end
