function [completed, st, diag] = dma_queue_step(frames, st, busService, cfgDma)
%DMA_QUEUE_STEP 按一次共享字节预算服务FIFO帧队列。
arguments
    frames struct
    st (1,1) struct
    busService (1,1) struct
    cfgDma (1,1) struct
end
if ~isfield(busService,'total_bytes') || ~isfield(cfgDma,'capacity_frames')
    error('rtsim:dataflow:MissingField','DMA字段不完整。');
end
if ~isfield(st,'queue'); st.queue=struct([]); end
queue=[st.queue frames(:).']; dropped=[];
if numel(queue)>cfgDma.capacity_frames
    rejected=queue(cfgDma.capacity_frames+1:end); dropped=[rejected.id];
    queue=queue(1:cfgDma.capacity_frames);
end
budget=max(0,busService.total_bytes); n=0; served=0;
while n<numel(queue) && served+queue(n+1).size_bytes<=budget
    n=n+1; served=served+queue(n).size_bytes;
end
completed=queue(1:n); st.queue=queue(n+1:end);
diag.bytes_served=served; diag.remaining_service_bytes=budget-served;
diag.dropped_ids=dropped; diag.backpressure=~isempty(st.queue);
diag.model_scope="frame FIFO and aggregate byte-service model; not AXI proof";
end
