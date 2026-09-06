function sync = source_sync_model(radarClock, instrumentClock, triggerObservation, cfgSync)
    % SOURCE_SYNC_MODEL 分开描述秒对齐、频率相干和射频相位关系。

    arguments
        radarClock (1, 1) struct
        instrumentClock (1, 1) struct
        triggerObservation (1, 1) struct
        cfgSync (1, 1) struct
    end

    need(radarClock, {'frequency_Hz', 'phase_rad'});
    need(instrumentClock, {'frequency_Hz', 'phase_rad'});
    need(triggerObservation, {'pps_locked', 'quality'});
    need(cfgSync, {'shared_frequency_reference', 'phase_strategy'});
    sync.pps_aligned = logical(triggerObservation.pps_locked) && triggerObservation.quality > 0;
    sync.frequency_offset_Hz = instrumentClock.frequency_Hz - radarClock.frequency_Hz;
    sync.frequency_coherent = logical(cfgSync.shared_frequency_reference) && ...
        sync.frequency_offset_Hz == 0;
    sync.relative_phase_rad = instrumentClock.phase_rad - radarClock.phase_rad;
    sync.phase_strategy = cfgSync.phase_strategy;
    sync.rf_phase_coherent = sync.frequency_coherent && cfgSync.phase_strategy == "LOCKED";
    sync.statement = "PPS alignment alone does not establish RF coherence";
end

function need(s, n)
    for k = 1:numel(n)
        if ~isfield(s, n{k})
            error('rtsim:source:MissingField', '缺少必需字段%s。', n{k});
        end
    end
end
