function [estimate,st,diag] = noise_estimator_ewma(power,st,cfgNoise)
% 门控 EWMA 输出更新前估计，阈值不读取未来数据。
assert(cfgNoise.alpha>0 && cfgNoise.alpha<=1,'rtsim:EWMA','平滑因子范围应为 (0,1]。');
if ~isfield(st,'mean'), st.mean=cfgNoise.initial; end
estimate=zeros(size(power)); excluded=0;
for k=1:numel(power)
    estimate(k)=st.mean;
    if power(k)<=cfgNoise.gate_factor*max(st.mean,realmin)
        st.mean=(1-cfgNoise.alpha)*st.mean+cfgNoise.alpha*power(k);
    else
        excluded=excluded+1;
    end
end
diag.excluded=excluded; diag.scope='固定初值的门控估计；连续相干污染下可能有偏';
end
