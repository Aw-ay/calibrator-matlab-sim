function [iq, st] = lfm_waveform(st, waveform, pulseEvents, grid)
    % 有限脉冲列基带 LFM；显式限制首脉冲之前及末脉冲之后。

    if nargin < 3
        pulseEvents = [];
    end

    assert(isempty(pulseEvents), 'rtsim:WaveformEvents', '本基线使用 waveform 有限任务配置，不接受额外事件覆盖。');
    t = (grid.index0 + (0:grid.count - 1)') / grid.fs_Hz;
    u = t - waveform.start_s;
    p = floor((u + 1e-14) / waveform.pri_s);
    local = u - p * waveform.pri_s;
    gate = u >= -1e-14 & p >= 0 & p < waveform.pulse_count & local >= -1e-14 & local < waveform.pulse_width_s - 1e-14;
    if strcmp(waveform.kind, 'CW')
        phase = zeros(size(t));
    else
        phase = 2 * pi * (-waveform.bandwidth_Hz / 2 * local + ...
            waveform.bandwidth_Hz / (2 * waveform.pulse_width_s) * local.^2);
    end

    iq = (sqrt(waveform.Ptx_W) * double(gate) .* exp(1i * phase)) * waveform.polarization.';
    st.next_index = grid.index0 + grid.count;
end
