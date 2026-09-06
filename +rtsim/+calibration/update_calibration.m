function [newSet, diag] = update_calibration(oldSet, txRxMonitor, telemetry, policy)
%UPDATE_CALIBRATION 在慢环中生成候选集，并仅在提交边界原子替换。
arguments
    oldSet (1,1) struct
    txRxMonitor (1,1) struct
    telemetry (1,1) struct
    policy (1,1) struct
end
required={'alpha','max_step','commit'};
if ~all(isfield(policy,required)) || ~isfield(txRxMonitor,'coefficient_delta') || ...
        ~isfield(telemetry,'valid') || ~isfield(oldSet,'coefficients') || ...
        ~isfield(oldSet,'version')
    error('rtsim:calibration:MissingField','慢校准更新字段不完整。');
end
newSet=oldSet;
diag.committed=false; diag.pending=false;
if ~telemetry.valid
    diag.reason="INVALID_TELEMETRY"; return
end
step=policy.alpha*txRxMonitor.coefficient_delta;
mag=abs(step); over=mag>policy.max_step;
step(over)=step(over).*policy.max_step./mag(over);
candidate=oldSet;
candidate.coefficients=oldSet.coefficients+step;
candidate.version=oldSet.version+uint32(1);
if logical(policy.commit)
    newSet=candidate; diag.committed=true; diag.reason="COMMITTED_AT_BOUNDARY";
else
    diag.pending=true; diag.pending_set=candidate; diag.reason="WAITING_FOR_BOUNDARY";
end
diag.max_applied_step=max(abs(step),[],'all');
end
