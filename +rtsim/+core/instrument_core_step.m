function [dacBaseband, pdw, records, st, diag] = instrument_core_step(nativeAdc, st, cfgCore, controlEstimate, ...
    serviceModel, grid)

    % A/B 共享因果核心。仅读取 ADC、控制估计和服务状态，禁止读取平台真值。

    cfg = cfgCore;
    n = size(nativeAdc, 1);
    fs = grid.fs_Hz;
    wideTx = isfield(controlEstimate.calTx, 'wideband');
    wideRx = isfield(controlEstimate.calRx, 'wideband');
    txLatency = 0;
    txTail = 0;
    interpolationTail = 0;
    if isfield(cfg, 'replay') && isfield(cfg.replay, 'interpolation_method') && ...
            ~strcmpi(cfg.replay.interpolation_method, 'LINEAR')
        interpolationTail = ceil(cfg.replay.interpolation_order / 2);
    end

    if (wideTx || wideRx) && ~ismember(cfg.instrument.mode, {'DRFM', 'MUTE'})
        error('rtsim:WidebandMode', '宽带校准当前仅支持完整捕获后的DRFM回放。');
    end

    if wideTx
        txLatency = controlEstimate.calTx.wideband.latency_samples;
        txTail = size(controlEstimate.calTx.wideband.coeff, 1) - 1;
    end

    if isfield(cfg.instrument, 'tx_rf_tail_bound_samples')
        txTail = txTail + cfg.instrument.tx_rf_tail_bound_samples;
    end

    dacBaseband = complex(zeros(n, 2));
    st.tx_allowed_mask = false(n, 1);
    pdw = struct([]);
    initialRecordCount = numel(st.records);
    [blockGate, st.safety] = rtsim.tx.safety_fsm_step(struct('enable', true), controlEstimate.status, ...
        st.safety, cfg.safety);
    for k = 1:n
        index = grid.index0 + k - 1;
        sample = nativeAdc(k, :, :);

        % 以最低增益档的可观测输入折算功率检测，不依赖真压缩标志。

        detectionPower = sum(abs(sample(1, :, 3)).^2) / cfg.instrument.ranges.gains(3)^2;

        % 最低档量化噪声可能掩盖弱脉冲；三档中选择未接近满量程的检测统计。

        powerByRange = reshape(sum(abs(sample).^2, 2), 1, 3) ./ (cfg.instrument.ranges.gains.^2);
        observablePeak = reshape(max(max(abs(real(sample)), abs(imag(sample))), [], 2), 1, 3);
        eligible = observablePeak < cfg.capture.range_limit;
        if any(eligible)
            detectionPower = max(powerByRange(eligible));
        end

        on = detectionPower > cfg.capture.threshold_W;
        if ~st.active && on
            id = find(~[st.banks.busy], 1);
            st.active = true;
            st.low_count = 0;
            st.active_bank = 0;
            if isempty(id)
                st.diagnostics.dropped_captures = st.diagnostics.dropped_captures + 1;
            else
                st.active_bank = id;
                b = st.banks(id);
                b.busy = true;
                b.generation = b.generation + 1;
                b.count = size(st.pre, 1);
                b.raw(1:b.count, :, :) = st.pre;
                b.start_index = index - b.count;
                b.pulse_id = st.next_pulse_id;
                b.replay = false;
                b.dma = false;
                st.banks(id) = b;
                st.next_pulse_id = st.next_pulse_id + 1;
            end
        end

        if st.active
            if on
                st.low_count = 0;
            else
                st.low_count = st.low_count + 1;
            end

            id = st.active_bank;
            if id > 0
                b = st.banks(id);
                if b.count < cfg.capture.max_samples
                    b.count = b.count + 1;
                    b.raw(b.count, :, :) = sample;
                    st.banks(id) = b;
                else
                    st.banks(id).busy = false;
                    st.active_bank = 0;
                    st.diagnostics.dropped_captures = st.diagnostics.dropped_captures + 1;
                end
            end

            if st.low_count >= max(cfg.capture.end_hold_samples, cfg.capture.posttrigger_samples)
                if st.active_bank > 0
                    [st, newPdw, newRecord] = finish_capture(st, st.active_bank, index, cfg, controlEstimate, grid);
                    if ~isempty(newPdw)
                        pdw = [pdw, newPdw]; %#ok<AGROW>
                    end

                    if ~isempty(newRecord)
                        st.records = [st.records, newRecord];
                        st.banks(st.active_bank).record_index = numel(st.records);
                    end
                end

                st.active = false;
                st.active_bank = 0;
                st.low_count = 0;
            end
        end

        st.pre = cat(1, st.pre, sample);
        if size(st.pre, 1) > cfg.capture.pretrigger_samples
            st.pre(1, :, :) = [];
        end

        % 回放有独立读端口。DMA 的服务停顿绝不改变回放样点编号。

        replaySample = complex(zeros(1, 2));

        % DAC最终使能也属于实际执行条件，不能把safe_value静音记录成发射。

        replayGate = blockGate && cfg.instrument.dac.valid;
        if cfg.instrument.half_duplex && strcmp(cfg.channel.kind, 'OTA') && ~cfg.instrument.isolated_ports && st.active
            replayGate = false;
        end

        for id = find([st.banks.replay])
            b = st.banks(id);
            if b.replay && index >= floor(b.tx_start - txLatency)
                recordId = b.record_index;
                if ~replayGate

                    % 门控失败立即终止描述符，恢复后不把残缺波形冒充按计划完整发射。

                    if strcmp(st.records(recordId).replay_status, 'PENDING')
                        st.records(recordId).replay_status = 'BLOCKED';
                    else
                        st.records(recordId).replay_status = 'INTERRUPTED';
                    end

                    b.replay = false;
                    st.banks(id) = b;
                    continue
                end

                if ~wideTx && strcmp(st.records(recordId).replay_status, 'PENDING')

                    % 确认回放事件已经执行，时间仍使用含前触发的连续物理首样点标签。

                    st.records(recordId).replay_status = 'STARTED';
                    st.records(recordId).t_tx_actual_s = b.tx_start / fs;
                end

                u = index - (b.tx_start - txLatency);

                % 描述符仅在EOP和准备完成后生效，因此可随机读取完整捕获波形。

                method = 'LINEAR';
                order = 7;
                if isfield(cfg, 'replay') && isfield(cfg.replay, 'interpolation_method')
                    method = cfg.replay.interpolation_method;
                    order = cfg.replay.interpolation_order;
                end

                replayValue = rtsim.replay.sample_delay_at(b.waveform, u + 1, method, order);
                replaySample = replaySample + replayValue * ...
                    exp(1i * (b.phase + 2 * pi * b.frequency * (index + txLatency) / fs));
                if u >= size(b.waveform, 1) + txTail + interpolationTail
                    b.replay = false;
                    st.records(recordId).replay_status = 'COMPLETED';
                end
            end

            % 每样点共享总服务预算，不能给每个 bank 各发一份总线带宽。

            st.banks(id) = b;
        end

        budget = serviceModel.dma_bytes_per_s / fs;
        for id = find([st.banks.busy])
            if st.banks(id).dma
                served = min(budget, st.banks(id).dma_remaining);
                budget = budget - served;
                st.banks(id).dma_remaining = st.banks(id).dma_remaining - served;
                st.diagnostics.dma_completed_bytes = st.diagnostics.dma_completed_bytes + served;
                if st.banks(id).dma_remaining <= 1e-8
                    st.banks(id).dma = false;
                end
            end

            if st.banks(id).busy && ~(st.active && st.active_bank == id) && ~st.banks(id).replay && ~st.banks(id).dma
                st.banks(id).busy = false;
            end
        end

        sources.DRFM = replaySample;
        sources.LIVE = complex(zeros(1, 2));
        if strcmp(cfg.instrument.mode, 'LIVE')
            selection = rtsim.capture.range_select_eop(sample, struct('limit', cfg.capture.range_limit));
        else
            selection.range_id = 0;
        end

        if selection.range_id > 0
            [sources.LIVE, st.calrx] = rtsim.calibration.apply_rx_cal(reshape(sample(:, :, selection.range_id), ...
                1, 2), st.calrx, controlEstimate.calRx, struct('range_id', selection.range_id));
        end

        local = (index / fs - cfg.instrument.source_start_s);
        ip = floor((local + 1e-14) / cfg.radar.pri_s);
        gatePulse = local >= 0 && ip < cfg.radar.pulse_count && local - ip * cfg.radar.pri_s < cfg.radar.pulse_width_s;
        sources.DDS = cfg.target.gain * 1e-6 * gatePulse * exp(1i * 2 * pi * cfg.target.doppler_Hz * index / fs) * ...
            cfg.radar.polarization.';
        sources.AWG = complex(zeros(1, 2));
        if strcmp(cfg.instrument.mode, 'AWG')
            assert(isfield(cfg.instrument, 'awg_table'), 'rtsim:AWGData', 'AWG 模式缺少 N×2 复数模板。');
            address = index - round(cfg.instrument.source_start_s * fs) + 1;
            if address >= 1 && address <= size(cfg.instrument.awg_table, 1)
                sources.AWG = cfg.instrument.awg_table(address, :);
            end
        end

        gate = blockGate;
        if cfg.instrument.half_duplex && strcmp(cfg.channel.kind, 'OTA') && ~cfg.instrument.isolated_ports && st.active
            gate = false;
        end

        % 独立信号源也必须先检查整个发射区间，不能只在已检测到 RX 时截断。

        if cfg.instrument.half_duplex && strcmp(cfg.channel.kind, ...
            'OTA') && ~cfg.instrument.isolated_ports && ismember(cfg.instrument.mode, {'DDS', 'AWG'})
            sourceStart = cfg.instrument.source_start_s + max(ip, 0) * cfg.radar.pri_s;
            sourceWidth = cfg.radar.pulse_width_s;
            if strcmp(cfg.instrument.mode, 'AWG')
                sourceStart = cfg.instrument.source_start_s;
                sourceWidth = size(cfg.instrument.awg_table, 1) / fs;
            end

            txWindow = struct('start_s', sourceStart, 'end_s', sourceStart + sourceWidth);
            decision = rtsim.replay.check_tx_windows(txWindow, controlEstimate.rx_windows, struct('ready_s', 0), ...
                struct('available', true));
            gate = gate && decision.accepted;
        end

        if ~strcmp(cfg.instrument.mode, 'MUTE') && gate
            dacBaseband(k, :) = sources.(cfg.instrument.mode);
        end

        st.tx_allowed_mask(k) = gate && cfg.instrument.dac.valid && ~strcmp(cfg.instrument.mode, 'MUTE');
        if wideTx
            enabled = st.tx_allowed_mask(k);
            [dacBaseband(k, :), st.caltx] = rtsim.calibration.apply_tx_cal( ...
                dacBaseband(k, :), st.caltx, controlEstimate.calTx, struct('enabled', enabled));
            if enabled && any(abs(dacBaseband(k, :)) > 0)
                for bankId = find([st.banks.replay])
                    recordId = st.banks(bankId).record_index;
                    if index >= floor(st.banks(bankId).tx_start - txLatency) && ...
                            strcmp(st.records(recordId).replay_status, 'PENDING')

                        % 宽带前驱也是真实发射；名义对齐时间单独保存，不能冒充实际能量起点。

                        st.records(recordId).replay_status = 'STARTED';
                        st.records(recordId).t_tx_actual_s = index / fs;
                        st.records(recordId).t_tx_first_nonzero_s = index / fs;
                    end
                end
            end
        end

        st.source.mode = cfg.instrument.mode;
        st.diagnostics.bank_highwater = max(st.diagnostics.bank_highwater, sum([st.banks.busy]));
    end

    if ~wideTx
        [dacBaseband, st.caltx] = rtsim.calibration.apply_tx_cal(dacBaseband, st.caltx, ...
            controlEstimate.calTx, struct());
    end

    st.diagnostics.dma_pending_bytes = sum([st.banks.dma_remaining]);
    st.pdw = [st.pdw, pdw];
    records = st.records(initialRecordCount + 1:end);
    diag = st.diagnostics;
end

function [st, pdw, record] = finish_capture(st, id, index, cfg, control, grid)
    % EOP 之后锁存量程、校准版本和目标命令，不等待最终 PDW 才调度。

    b = st.banks(id);
    raw = b.raw(1:b.count, :, :);
    pdw = [];
    record = [];
    selection = rtsim.capture.range_select_eop(raw, struct('limit', cfg.capture.range_limit));
    if selection.range_id == 0
        st.diagnostics.invalid_ranges = st.diagnostics.invalid_ranges + 1;
        b.busy = false;
        st.banks(id) = b;
        return
    end

    context = struct('range_id', selection.range_id, 'capture_complete', true);
    [wave, ~] = rtsim.calibration.apply_rx_cal(raw(:, :, selection.range_id), struct(), control.calRx, context);
    b.waveform = cfg.target.gain * wave * control.polar_operator.';
    physicalStart = b.start_index - cfg.pl.group_delay_s * grid.fs_Hz;
    geometryEstimate = control.geometry;
    if strcmp(cfg.channel.kind, 'OTA')

        % 用已到达导航作恒速度预测，分别估计接收与未来发射事件的距离。

        receiveTime = physicalStart / grid.fs_Hz;
        p = control.pose_estimate.position_m;
        v = control.pose_estimate.velocity_mps;
        receivePosition = p + v * (receiveTime - control.observation_time_s);
        txTime = receiveTime + 2 * cfg.target.range_m / 299792458 - geometryEstimate.roundtrip_delay_s;
        for iteration = 1:5
            transmitPosition = p + v * (txTime - control.observation_time_s);
            geometryEstimate.roundtrip_delay_s = (norm(receivePosition) + norm(transmitPosition)) / 299792458;
            txTime = receiveTime + 2 * cfg.target.range_m / 299792458 - geometryEstimate.roundtrip_delay_s;
        end
    end

    txLatency = 0;
    txTail = 0;
    interpolationTail = 0;
    if isfield(cfg, 'replay') && isfield(cfg.replay, 'interpolation_method') && ...
            ~strcmpi(cfg.replay.interpolation_method, 'LINEAR')
        interpolationTail = ceil(cfg.replay.interpolation_order / 2);
    end

    if isfield(control.calTx, 'wideband')
        txLatency = control.calTx.wideband.latency_samples;
        txTail = size(control.calTx.wideband.coeff, 1) - 1;
    end

    rfTail = 0;
    if isfield(cfg.instrument, 'tx_rf_tail_bound_samples')
        rfTail = cfg.instrument.tx_rf_tail_bound_samples;
        txTail = txTail + rfTail;
    end

    plan = rtsim.replay.solve_target_delay(cfg.target, geometryEstimate, struct('fixed_s', ...
        cfg.instrument.fixed_latency_s + txLatency / grid.fs_Hz), grid);
    targetTx = physicalStart / grid.fs_Hz + plan.device_delay_s;
    commandTime = targetTx - cfg.instrument.fixed_latency_s - txLatency / grid.fs_Hz;
    dataReady = index / grid.fs_Hz + cfg.capture.range_select_s + ...
        cfg.capture.rx_calibration_s + cfg.capture.bank_prepare_s;
    actualTx = commandTime + cfg.instrument.fixed_latency_s + txLatency / grid.fs_Hz;
    b.tx_start = actualTx * grid.fs_Hz;
    accepted = plan.accepted;
    reason = plan.reason;
    if commandTime < dataReady
        accepted = false;
        reason = 'DATA_NOT_READY';
    end

    if accepted && cfg.instrument.half_duplex && strcmp(cfg.channel.kind, 'OTA') && ~cfg.instrument.isolated_ports
        starts = (physicalStart + cfg.capture.pretrigger_samples) / grid.fs_Hz + ...
            (0:ceil(cfg.sim.duration_s / cfg.radar.pri_s)) * cfg.radar.pri_s;
        windows = [starts(:) - cfg.safety.guard_s, starts(:) + cfg.radar.pulse_width_s + cfg.safety.guard_s];
        txPlan = struct('start_s', (b.tx_start - txLatency) / grid.fs_Hz, ...
            'end_s', (b.tx_start - txLatency + b.count + txTail + interpolationTail) / grid.fs_Hz);
        decision = rtsim.replay.check_tx_windows(txPlan, windows, struct('ready_s', ...
            dataReady + cfg.instrument.fixed_latency_s), struct('available', true));
        accepted = decision.accepted;
        reason = decision.reason;
    end

    phase = rtsim.replay.solve_phase_command(cfg.target, control.phase, grid, []);
    b.phase = phase.phase0_rad;
    b.frequency = phase.frequency_Hz;
    b.replay = accepted && strcmp(cfg.instrument.mode, 'DRFM');

    % 同一回放读端口不可同时服务两个描述符，冲突明确拒绝。

    if b.replay
        others = find([st.banks.replay]);
        for other = others
            previous = st.banks(other);
            if b.tx_start < previous.tx_start + size(previous.waveform, ...
                1) + txTail + interpolationTail + 1 && ...
                    b.tx_start + b.count + txTail + interpolationTail + 1 > previous.tx_start
                accepted = false;
                reason = 'REPLAY_RESOURCE_BUSY';
                b.replay = false;
                break
            end
        end
    end

    if ~accepted && strcmp(cfg.instrument.mode, 'DRFM')
        st.diagnostics.rejected_replays = st.diagnostics.rejected_replays + 1;
        st.rejections(end + 1) = struct('pulse_id', b.pulse_id, 'reason', reason);
    end

    b.dma = true;
    b.dma_remaining = b.count * 2 * 2 * 2 + 128;
    context.pulse_id = b.pulse_id;
    context.start_index = physicalStart;
    context.calibration_id = control.calRx.id;
    context.available_index = index;
    pdw = rtsim.capture.pdw_measure(wave, context, struct('fs_Hz', grid.fs_Hz));
    record = struct('pulse_id', b.pulse_id, 'bank_id', id, 'bank_generation', b.generation, ...
        'reference_plane', 'PL_FILTERED_RAW', 'calibration_id', 'NONE', 'format', 'RAW_IQ', ...
        'sample_start', physicalStart, 'count', b.count, 'range_id', selection.range_id, 'bytes', b.dma_remaining);
    lsb = cfg.instrument.adc.full_scale / 2^(cfg.instrument.adc.bits - 1);
    record.t_physical_rx_s = physicalStart / grid.fs_Hz;
    record.t_cmd_s = commandTime;
    record.t_tx_target_s = targetTx;
    record.t_tx_actual_s = NaN;
    record.t_tx_aligned_s = targetTx;
    record.t_tx_first_nonzero_s = NaN;
    record.tx_calibration_latency_samples = txLatency;
    record.tx_calibration_tail_samples = txTail - rfTail;
    record.tx_rf_tail_bound_samples = rfTail;
    record.replay_status = 'NOT_REQUESTED';
    if strcmp(cfg.instrument.mode, 'DRFM')
        record.replay_status = 'REJECTED';
        if b.replay
            record.replay_status = 'PENDING';
        end
    end

    record.t_data_ready_s = dataReady;
    record.replay_accepted = b.replay;
    record.encoding = 'PL filtered complex IQ requantized to signed int16 for storage';
    record.i_code = int16(round(real(raw(:, :, selection.range_id)) / lsb));
    record.q_code = int16(round(imag(raw(:, :, selection.range_id)) / lsb));
    record.lsb = lsb;
    record.units = 'code';
    record.sample_rate_Hz = grid.fs_Hz;
    st.banks(id) = b;
end
