function [commands, data, st, diag] = ps_service_step(observations, queues, st, cfgPs)
%PS_SERVICE_STEP 用单一记录预算服务PDW与IQ，并模型化命令延迟。
arguments
    observations (1,1) struct
    queues (1,1) struct
    st (1,1) struct
    cfgPs (1,1) struct
end
if ~all(isfield(cfgPs,{'total_service_items','pdw_priority','command_delay_steps'})) || ...
        ~all(isfield(queues,{'pdw','iq'}))
    error('rtsim:dataflow:MissingField','PS服务字段不完整。');
end
if ~isfield(st,'command_queue'); st.command_queue=struct([]); end
commands=struct([]);
if ~isempty(st.command_queue)
    for k=1:numel(st.command_queue); st.command_queue(k).remaining=st.command_queue(k).remaining-1; end
    ready=[st.command_queue.remaining]<=0; commands=st.command_queue(ready);
    st.command_queue=st.command_queue(~ready);
end
if isfield(observations,'config_request')
    item.payload=observations.config_request; item.remaining=cfgPs.command_delay_steps;
    st.command_queue=[st.command_queue item];
end
budget=max(0,floor(cfgPs.total_service_items));
if cfgPs.pdw_priority
    np=min(numel(queues.pdw),budget); budget=budget-np;
    ni=min(numel(queues.iq),budget);
else
    ni=min(numel(queues.iq),budget); budget=budget-ni;
    np=min(numel(queues.pdw),budget);
end
data.pdw=queues.pdw(1:np); data.iq=queues.iq(1:ni);
diag.remaining_service_items=cfgPs.total_service_items-np-ni;
diag.pdw_served=np; diag.iq_served=ni;
diag.model_scope="aggregate PS item-service and delayed-command model";
end
