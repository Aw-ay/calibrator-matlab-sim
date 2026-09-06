function gainPlan = solve_target_gain(task,linkEstimate,~,limits)
% 接收功率预算转换为幅度倍率，功率比必须开平方。
den=linkEstimate.input_power_W*linkEstimate.return_power_gain;
assert(den>0 && isfinite(den) && task.received_power_W>=0,'rtsim:GainBudget','链路功率预算不可用。');
required=sqrt(task.received_power_W/den);
gainPlan=struct('amplitude_gain',min(required,limits.max_amplitude_gain),'requested_gain',required, ...
    'limited',required>limits.max_amplitude_gain,'units','amplitude_ratio');
end
