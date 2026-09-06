function [descriptors, st, diag] = capture_pingpong_step(rangeIQ, events, st, cfgCapture)
%CAPTURE_PINGPONG_STEP 冻结完整RAW捕获并以bank代号和引用计数保护所有权。
if ~isfield(st,'banks')
    empty=struct('busy',false,'generation',uint64(0),'raw',[],'references',empty_refs(),'pulse_id',0);
    st.banks=repmat(empty,1,cfgCapture.bank_count);
end
descriptors=struct('pulse_id',{},'bank_id',{},'bank_generation',{},'sample_count',{});
diag=struct('captured',0,'dropped_no_bank',0,'invalid_events',0);
for k=1:numel(events)
    if ~strcmpi(events(k).type,'CAPTURE'), continue, end
    first=events(k).start_index; last=events(k).end_index;
    if first<1 || last>size(rangeIQ,1) || last<first
        diag.invalid_events=diag.invalid_events+1; continue
    end
    id=find(~[st.banks.busy],1);
    if isempty(id), diag.dropped_no_bank=diag.dropped_no_bank+1; continue, end
    b=st.banks(id); b.generation=b.generation+1; b.raw=rangeIQ(first:last,:,:); b.pulse_id=events(k).pulse_id;
    b.references=empty_refs(); consumers=field_or(cfgCapture,'initial_consumers',{'REPLAY','DMA'});
    for j=1:numel(consumers), name=upper(char(consumers{j})); b.references.(name)=b.references.(name)+1; end
    b.busy=sum(struct2array(b.references))>0; st.banks(id)=b;
    descriptors(end+1)=struct('pulse_id',b.pulse_id,'bank_id',id, ...
        'bank_generation',b.generation,'sample_count',size(b.raw,1)); %#ok<AGROW>
    diag.captured=diag.captured+1;
end
diag.busy_banks=sum([st.banks.busy]);
end

function refs=empty_refs(), refs=struct('REPLAY',0,'ANALYSIS',0,'DMA',0); end
function value=field_or(s,name,default), if isfield(s,name), value=s.(name); else, value=default; end, end
