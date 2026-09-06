function calDelay = estimate_delay_cal(measurements, timingReference, cfg)
    % ESTIMATE_DELAY_CAL 分离已知路径、排队等待和仪器固定延迟。

    arguments
        measurements (1, 1) struct
        timingReference (1, 1) struct
        cfg (1, 1) struct
    end

    if ~isfield(measurements, 'delay') || ...
            ~all(isfield(measurements.delay, {'input_time_s', 'output_time_s', 'queue_wait_s'})) || ...
            ~isfield(timingReference, 'known_path_delay_s') || ~isfield(cfg, 'max_residual_s')
        error('rtsim:calibration:MissingField', '延迟测量或参考字段不完整。');
    end

    d = measurements.delay;
    raw = d.output_time_s - d.input_time_s;
    instrument = raw - timingReference.known_path_delay_s - d.queue_wait_s;
    fixed = median(instrument);
    residual = instrument - fixed;
    calDelay.fixed_delay_s = fixed;
    calDelay.known_path_delay_s = timingReference.known_path_delay_s;
    calDelay.queue_wait_s = d.queue_wait_s;
    calDelay.residual_s = residual;
    calDelay.max_abs_residual_s = max(abs(residual));
    if calDelay.max_abs_residual_s <= cfg.max_residual_s
        calDelay.status = "OK";
    else
        calDelay.status = "RESIDUAL_EXCEEDED";
    end

    calDelay.model_scope = "fixed instrument delay after known path and queue removal";
end
