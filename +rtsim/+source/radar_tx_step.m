function [tx, events, st] = radar_tx_step(st, cfgRadar, grid)
    % 真值事件只提供给评分方，检测器不会接收此标签。

    [tx, st] = rtsim.source.lfm_waveform(st, cfgRadar, [], grid);
    starts = cfgRadar.start_s + (0:cfgRadar.pulse_count - 1) * cfgRadar.pri_s;
    events = starts(starts >= grid.index0 / grid.fs_Hz & starts < (grid.index0 + grid.count) / grid.fs_Hz);
end
