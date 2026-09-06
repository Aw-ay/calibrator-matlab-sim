function [saved, sent, st, diag] = storage_link_step(records, st, storageCfg, radioCfg)
%STORAGE_LINK_STEP 区分本地容量和本次无线总字节预算。
arguments
    records struct
    st (1,1) struct
    storageCfg (1,1) struct
    radioCfg (1,1) struct
end
if ~all(isfield(storageCfg,{'capacity_bytes','retain_iq'})) || ...
        ~isfield(radioCfg,'budget_bytes')
    error('rtsim:dataflow:MissingField','存储或无线字段不完整。');
end
if ~isfield(st,'used_bytes'); st.used_bytes=0; end
% PDW优先，保证IQ策略或容量压力不会吞掉全部事件记录。
isPdw=arrayfun(@(r) r.kind=="PDW",records);
ordered=[records(isPdw) records(~isPdw)]; saved=struct([]); dropped=[];
for r=ordered
    allowed=r.kind=="PDW" || logical(storageCfg.retain_iq);
    if allowed && st.used_bytes+r.size_bytes<=storageCfg.capacity_bytes
        saved=[saved r]; st.used_bytes=st.used_bytes+r.size_bytes; %#ok<AGROW>
    else
        dropped(end+1)=r.id; %#ok<AGROW>
    end
end
budget=max(0,radioCfg.budget_bytes); sent=struct([]); used=0;
for r=saved
    if used+r.size_bytes<=budget
        sent=[sent r]; used=used+r.size_bytes; %#ok<AGROW>
    end
end
diag.dropped_ids=dropped; diag.radio_bytes_sent=used;
diag.remaining_storage_bytes=storageCfg.capacity_bytes-st.used_bytes;
diag.model_scope="local-record capacity and aggregate radio-budget model";
end
