function [pulseEvents, st, diag] = burst_scheduler_step(st, descriptors, grid)
    % BURST_SCHEDULER_STEP 锁存描述符并在网格内产生有限脉冲事件。

    arguments
        st (1, 1) struct
        descriptors struct
        grid (1, 1) struct
    end

    if ~all(isfield(grid, {'index0', 'count'}))
        error('rtsim:source:MissingField', 'grid必须包含index0和count。');
    end

    required = {'id', 'start_index', 'pulse_width_samples', 'pri_samples', 'pulse_count', ...
        'source', 'available_index', 'prepare_samples'};
    if ~isempty(descriptors) && ~all(isfield(descriptors, required))
        error('rtsim:source:MissingField', 'burst描述符字段不完整。');
    end

    if ~isfield(st, 'emitted_keys')
        st.emitted_keys = strings(0);
    end

    if ~isfield(st, 'emitted_count')
        st.emitted_count = 0;
    end

    pulseEvents = struct([]);
    reasons = strings(0);
    blockStart = uint64(grid.index0);
    blockEnd = blockStart + uint64(grid.count) - 1;
    for d = descriptors(:).'
        if d.pulse_width_samples <= 0 || d.pri_samples < d.pulse_width_samples || d.pulse_count < 1
            error('rtsim:source:InvalidBurst', 'PW、PRI或脉冲数不合法。');
        end

        readyDeadline = d.start_index - uint64(d.prepare_samples);
        if d.available_index > readyDeadline
            reasons(end + 1) = "INSUFFICIENT_PREPARATION"; %#ok<AGROW>
            continue
        end

        for p = 0:d.pulse_count - 1
            start = d.start_index + uint64(p * d.pri_samples);
            finish = start + uint64(d.pulse_width_samples) - 1;
            key = string(d.id) + ":" + string(p);
            if finish >= blockStart && start <= blockEnd && ~any(st.emitted_keys == key)
                event.descriptor_id = d.id;
                event.pulse_index = p + 1;
                event.start_index = start;
                event.end_index = finish;
                event.source = d.source;
                pulseEvents = [pulseEvents event]; %#ok<AGROW>
                st.emitted_keys(end + 1) = key;
                st.emitted_count = st.emitted_count + 1;
            end
        end
    end

    if isempty(reasons)
        diag.rejected_reason = "";
    else
        diag.rejected_reason = reasons(1);
    end

    diag.model_scope = "finite descriptor-level burst event scheduler";
end
