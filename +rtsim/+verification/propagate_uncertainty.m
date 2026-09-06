function budget = propagate_uncertainty(model, distributions, covariance, cfgMC)
    % 对带协方差的高斯输入做 Monte Carlo，不将相关误差当成独立平方和。

    mu = distributions.mean(:);
    covariance = (covariance + covariance') / 2;
    assert(isequal(size(covariance), [numel(mu), numel(mu)]), 'rtsim:Covariance', '协方差维度不符。');
    [V, D] = eig(covariance);
    eigenvalues = diag(D);
    assert(all(eigenvalues >= -1e-12), 'rtsim:Covariance', '协方差必须半正定。');
    stream = RandStream('mt19937ar', 'Seed', cfgMC.seed);
    x = mu + V * diag(sqrt(max(eigenvalues, 0))) * randn(stream, numel(mu), cfgMC.count);
    first = model(x(:, 1));
    values = zeros(numel(first), cfgMC.count);
    values(:, 1) = first(:);
    for k = 2:cfgMC.count
        v = model(x(:, k));
        values(:, k) = v(:);
    end

    budget.mean = mean(values, 2);
    budget.covariance = cov(values.');
    budget.standard_uncertainty = std(values, 0, 2);
    ordered = sort(values, 2);
    n = cfgMC.count;
    budget.interval95 = [ordered(:, max(1, round(.025 * n))), ordered(:, min(n, round(.975 * n)))];
    budget.input_covariance = covariance;
    budget.samples = n;
    budget.seed = cfgMC.seed;
    budget.scope = '指定高斯分布假设下的统计传播，不自动提供真实覆盖率';
end
