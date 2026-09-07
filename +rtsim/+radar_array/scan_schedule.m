function angles = scan_schedule(cfg, time_s)
    % 分段常值命令：[起始秒 方位度 俯仰度]；边界属于新段，首段前用默认。

    angles = [cfg.steer_az_deg cfg.steer_el_deg];
    s = cfg.scan_schedule;
    if isempty(s)
        return
    end

    if size(s, 2) ~= 3 || any(diff(s(:, 1)) <= 0) || any(~isfinite(s(:)))
        error('rtsim:array:Schedule', '扫描排程必须按时间严格递增且为K×3。');
    end

    k = find(time_s >= s(:, 1), 1, 'last');
    if ~isempty(k)
        angles = s(k, 2:3);
    end
end
