function st = init_state(cfg)
    % 每个状态具有唯一更新者；捕获、回放与 DMA 引用独立。

    st.active = false;
    st.active_bank = 0;
    st.low_count = 0;
    st.pre = complex(zeros(0, 2, 3));
    st.next_pulse_id = 1;
    bank = struct('busy', false, 'generation', 0, 'raw', complex(zeros(cfg.capture.max_samples, 2, 3)), ...
        'record_index', 0, 'count', 0, 'start_index', 0, 'pulse_id', 0, 'replay', false, 'dma', false, ...
        'waveform', complex(zeros(0, 2)), 'tx_start', inf, 'dma_remaining', 0, 'phase', 0, 'frequency', 0);
    st.banks = repmat(bank, 1, cfg.capture.bank_count);
    st.source = struct();
    st.safety = struct();
    st.calrx = struct();
    st.caltx = struct();
    st.pdw = struct([]);
    st.records = struct([]);
    st.rejections = struct('pulse_id', {}, 'reason', {});
    st.diagnostics = struct('rejected_replays', 0, 'dropped_captures', 0, 'bank_highwater', 0, ...
        'dma_pending_bytes', 0, 'dma_completed_bytes', 0, 'tx_clipped_samples', 0, 'invalid_ranges', 0);
end
