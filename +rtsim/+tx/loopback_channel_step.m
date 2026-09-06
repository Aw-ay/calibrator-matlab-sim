function [rxInput, st, diag] = loopback_channel_step(txOutput, st, fixtureCfg)
%LOOPBACK_CHANNEL_STEP 安全受限的二维夹具响应与跨块整数延迟。
arguments
    txOutput (:,2) double
    st (1,1) struct
    fixtureCfg (1,1) struct
end
need(fixtureCfg,{'response_matrix','delay_samples','max_input_power_W', ...
    'fixture_error_matrix'});
inputPower=sum(abs(txOutput).^2,2);
if any(inputPower>fixtureCfg.max_input_power_W)
    error('rtsim:tx:UnsafeLoopbackPower','回环输入功率超过夹具安全限制。');
end
d=fixtureCfg.delay_samples;
validateattributes(d,{'numeric'},{'scalar','integer','nonnegative'});
effective=fixtureCfg.response_matrix+fixtureCfg.fixture_error_matrix;
current=txOutput*effective.';
if ~isfield(st,'delay_buffer'); st.delay_buffer=complex(zeros(d,2)); end
if size(st.delay_buffer,1)~=d
    error('rtsim:tx:DelayStateMismatch','回环延迟配置在有状态处理中发生变化。');
end
combined=[st.delay_buffer;current]; n=size(txOutput,1);
rxInput=combined(1:n,:); st.delay_buffer=combined(n+1:end,:);
diag.peak_input_power_W=max(inputPower,[],'all');
diag.fixture_error_matrix=fixtureCfg.fixture_error_matrix;
diag.model_scope="flat 2x2 fixture with integer sample delay";
end
function need(s,n)
for k=1:numel(n); if ~isfield(s,n{k}); error('rtsim:tx:MissingField','缺少必需字段%s。',n{k}); end; end
end
