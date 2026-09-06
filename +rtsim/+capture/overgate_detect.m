function [events,st,diag] = overgate_detect(power,st,cfgDetector,grid)
% 因果门限检测，物理末沿与确认末沿的可用时间分别记录。
if ~isfield(st,'active'), st.active=false; st.low=0; st.start=0; end
events=struct('start_index',{},'end_index',{},'available_index',{});
for k=1:numel(power)
    index=grid.index0+k-1;
    if power(k)>cfgDetector.threshold
        if ~st.active, st.active=true; st.start=index; end
        st.low=0;
    elseif st.active
        st.low=st.low+1;
        if st.low>=cfgDetector.end_hold
            events(end+1)=struct('start_index',st.start,'end_index',index-st.low,'available_index',index); %#ok<AGROW>
            st.active=false; st.low=0;
        end
    end
end
diag.active=st.active;
end
