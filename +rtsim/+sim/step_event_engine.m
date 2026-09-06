function [events, st] = step_event_engine(requests, st, grid)
%STEP_EVENT_ENGINE 按可用tick和优先级稳定派发当前网格内事件。
if ~isfield(st,'queue'), st.queue=struct('available_tick',{},'priority',{},'type',{},'payload',{},'sequence',{}); end
if ~isfield(st,'next_sequence'), st.next_sequence=uint64(1); end
for k=1:numel(requests)
    item=requests(k); item.sequence=st.next_sequence; st.next_sequence=st.next_sequence+1;
    st.queue(end+1)=item;
end
if grid.count<=0, events=st.queue([]); return, end
lastTick=double(grid.gsc0)+(grid.count-1)*double(grid.step_num)/double(grid.step_den);
eligible=find(double([st.queue.available_tick])<=lastTick);
if isempty(eligible), events=st.queue([]); return, end
keys=[[st.queue(eligible).available_tick].',[st.queue(eligible).priority].',double([st.queue(eligible).sequence].')];
[~,order]=sortrows(keys,[1,2,3]); chosen=eligible(order); events=st.queue(chosen);
keep=true(1,numel(st.queue)); keep(chosen)=false; st.queue=st.queue(keep);
st.current_tick=lastTick;
end
