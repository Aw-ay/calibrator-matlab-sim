function decision = check_tx_windows(txPlan, rxWindows, availability, resourceState)
% 区间相交判断支持多 PRI 延迟，不以延迟大于 PRI 直接拒绝。
decision.accepted=true; decision.reason='';
if txPlan.start_s<availability.ready_s
    decision.accepted=false; decision.reason='DATA_NOT_READY'; return
end
if ~resourceState.available
    decision.accepted=false; decision.reason='RESOURCE_BUSY'; return
end
if ~isempty(rxWindows) && any(txPlan.start_s<rxWindows(:,2) & txPlan.end_s>rxWindows(:,1))
    decision.accepted=false; decision.reason='RX_TX_CONFLICT';
end
end
