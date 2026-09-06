function [out, st, diag] = fractional_delay_step(in, st, fractionalDelay, ~)
    % 因果线性分数延迟；参数单位为样点，不冒充高阶 Farrow 宽带精度。

    path = struct('delay_s', fractionalDelay, 'matrix', eye(2));
    [out, st] = rtsim.channel.combine_complex_paths(in, path, st, struct('fs_Hz', 1));
    diag = struct('delay_samples', fractionalDelay, 'fixed_extra_samples', 0, 'method', 'CAUSAL_LINEAR');
end
