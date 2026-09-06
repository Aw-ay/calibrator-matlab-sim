function [iq, st, diag] = awg_step(st, waveformTable, task, grid)
% 有限次数表回放，不允许未知比例的隐式重采样。
assert(task.fs_Hz==grid.fs_Hz,'rtsim:AWGRate','AWG 采样率不匹配。');
assert(size(waveformTable,2)==2,'rtsim:AWGShape','AWG 表必须为 N×2。');
if ~isfield(st,'address'), st.address=0; end
address=st.address+(0:grid.count-1)'; n=size(waveformTable,1);
valid=address<n*task.repeat_count;
iq=complex(zeros(grid.count,2)); iq(valid,:)=task.amplitude*waveformTable(mod(address(valid),n)+1,:);
st.address=st.address+grid.count; diag.exhausted=~all(valid);
end
