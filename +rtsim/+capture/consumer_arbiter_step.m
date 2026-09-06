function [grants, st, diag] = consumer_arbiter_step(requests, st, memoryPortModel)
%CONSUMER_ARBITER_STEP 以回放硬优先级分配共享存储端口预算。
if ~isfield(st,'pending'), st.pending=struct('consumer',{},'bank_id',{},'bank_generation',{},'bytes',{},'sequence',{}); end
if ~isfield(st,'next_sequence'), st.next_sequence=uint64(1); end
for k=1:numel(requests)
    q=requests(k); q.sequence=st.next_sequence; st.next_sequence=st.next_sequence+1; st.pending(end+1)=q;
end
grants=struct('consumer',{},'bank_id',{},'bank_generation',{},'bytes',{});
budget=memoryPortModel.budget_bytes; stale=0;
priority=arrayfun(@(q) consumer_priority(q.consumer),st.pending);
[~,order]=sortrows([priority(:),double([st.pending.sequence].')],[1,2]); st.pending=st.pending(order);
keep=true(1,numel(st.pending));
for k=1:numel(st.pending)
    q=st.pending(k); id=q.bank_id;
    valid=id>=1 && id<=numel(st.banks) && st.banks(id).busy && st.banks(id).generation==q.bank_generation;
    if ~valid, keep(k)=false; stale=stale+1; continue, end
    if budget<=0, continue, end
    served=min(q.bytes,budget); budget=budget-served; q.bytes=q.bytes-served;
    grants(end+1)=struct('consumer',upper(char(q.consumer)),'bank_id',id, ...
        'bank_generation',q.bank_generation,'bytes',served); %#ok<AGROW>
    if q.bytes<=0
        keep(k)=false; name=upper(char(q.consumer));
        if isfield(st.banks(id).references,name)
            st.banks(id).references.(name)=max(0,st.banks(id).references.(name)-1);
            st.banks(id).busy=sum(struct2array(st.banks(id).references))>0;
        end
    else
        st.pending(k)=q;
    end
end
st.pending=st.pending(keep);
diag=struct('remaining_budget_bytes',budget,'queued_requests',numel(st.pending),'stale_requests',stale);
end

function p=consumer_priority(name)
switch upper(char(name)), case 'REPLAY', p=1; case 'ANALYSIS', p=2; otherwise, p=3; end
end
