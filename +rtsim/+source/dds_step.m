function [iq, st] = dds_step(st, cfgDds, grid)
    % 相位由统一样点时轴确定，分块不会重置 DDS 相位。

    t = (grid.index0 + (0:grid.count - 1)') / grid.fs_Hz;
    iq = cfgDds.amplitude * exp(1i * (cfgDds.phase0_rad + 2 * pi * cfgDds.frequency_Hz * t)) * cfgDds.polarization.';
    st.next_index = grid.index0 + grid.count;
end
