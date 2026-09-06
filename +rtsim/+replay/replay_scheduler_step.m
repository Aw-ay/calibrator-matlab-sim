function [requests, st, diag] = replay_scheduler_step(descriptors, commands, st, grid)
    % REPLAY_SCHEDULER_STEP 校验ready/generation并在单读端口上稳定排队重放。

    if ~isfield(st, 'queue')
        st.queue = struct('pulse_id', {}, 'bank_id', {}, 'bank_generation', {}, 'ready_tick', {}, ...
            'requested_start_tick', {}, 'sample_count', {}, 'sequence', {});
    end

    if ~isfield(st, 'next_sequence')
        st.next_sequence = uint64(1);
    end

    if ~isfield(st, 'port_busy_until')
        st.port_busy_until = -Inf;
    end

    rejected = 0;
    for k = 1:numel(commands)
        match = find([descriptors.pulse_id] == commands(k).pulse_id, 1);
        if isempty(match)
            rejected = rejected + 1;
            continue
        end

        d = descriptors(match);
        id = d.bank_id;
        valid = id >= 1 && id <= numel(st.bank_generations) && st.bank_generations(id) == d.bank_generation;
        if ~valid || commands(k).start_tick < d.ready_tick
            rejected = rejected + 1;
            continue
        end

        q = struct('pulse_id', d.pulse_id, 'bank_id', id, 'bank_generation', d.bank_generation, ...
            'ready_tick', d.ready_tick, 'requested_start_tick', commands(k).start_tick, ...
            'sample_count', d.sample_count, 'sequence', st.next_sequence);
        st.next_sequence = st.next_sequence + 1;
        st.queue(end + 1) = q;
    end

    if grid.count <= 0
        lastTick = -Inf;
    else
        lastTick = double(grid.gsc0) + (grid.count - 1) * double(grid.step_num) / double(grid.step_den);
    end

    if isempty(st.queue)
        requests = struct('pulse_id', {}, 'bank_id', {}, 'bank_generation', {}, 'actual_start_tick', {}, ...
            'sample_count', {});
        diag = struct('rejected', rejected, 'queued_for_port', 0, 'pending', 0);
        return
    end

    [~, order] = sortrows([[st.queue.requested_start_tick].', double([st.queue.sequence].')], [1, 2]);
    st.queue = st.queue(order);
    requests = struct('pulse_id', {}, 'bank_id', {}, 'bank_generation', {}, 'actual_start_tick', {}, ...
        'sample_count', {});
    keep = true(1, numel(st.queue));
    queuedForPort = 0;
    for k = 1:numel(st.queue)
        q = st.queue(k);
        actual = max(double(q.requested_start_tick), st.port_busy_until);
        if actual > double(q.requested_start_tick)
            queuedForPort = queuedForPort + 1;
        end

        if actual > lastTick
            continue
        end

        requests(end + 1) = struct('pulse_id', q.pulse_id, 'bank_id', q.bank_id, ...
            'bank_generation', q.bank_generation, 'actual_start_tick', actual, 'sample_count', ...
                q.sample_count); %#ok<AGROW>
        st.port_busy_until = actual + q.sample_count;
        keep(k) = false;
    end

    st.queue = st.queue(keep);
    diag = struct('rejected', rejected, 'queued_for_port', queuedForPort, 'pending', numel(st.queue));
end
