function [delivered, st, diag] = pdw_fifo_step(pdwInput, serviceEvents, st, cfgFifo)
%PDW_FIFO_STEP 独立PDW小队列行为模型，不受IQ队列背压支配。
arguments
    pdwInput struct
    serviceEvents (1,1) struct
    st (1,1) struct
    cfgFifo (1,1) struct
end
if ~all(isfield(cfgFifo,{'capacity','overflow_policy'})) || ...
        ~isfield(serviceEvents,'service_count')
    error('rtsim:dataflow:MissingField','PDW队列配置字段不完整。');
end
if ~isfield(st,'queue'); st.queue=struct([]); end
queue=[st.queue pdwInput(:).']; dropped=[];
if numel(queue)>cfgFifo.capacity
    excess=numel(queue)-cfgFifo.capacity;
    if cfgFifo.overflow_policy=="drop_newest"
        rejected=queue(end-excess+1:end); queue=queue(1:end-excess);
    elseif cfgFifo.overflow_policy=="drop_oldest"
        rejected=queue(1:excess); queue=queue(excess+1:end);
    else
        error('rtsim:dataflow:InvalidPolicy','未知PDW溢出策略。');
    end
    dropped=[rejected.id];
end
n=min(numel(queue),max(0,floor(serviceEvents.service_count)));
delivered=queue(1:n); queue=queue(n+1:end); st.queue=queue;
diag.dropped_ids=dropped; diag.queue_depth=numel(queue); diag.delivered_count=n;
diag.model_scope="record-count FIFO model";
end
