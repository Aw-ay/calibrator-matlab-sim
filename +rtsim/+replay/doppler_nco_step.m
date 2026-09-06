function [out, st] = doppler_nco_step(in, st, residualPhaseCommand, grid)
    % 唯一相位命令入口；不在此函数再次加入完整物理多普勒。

    t = (grid.index0 + (0:size(in, 1) - 1)') / grid.fs_Hz;
    out = in .* exp(1i * (residualPhaseCommand.phase0_rad + 2 * pi * residualPhaseCommand.frequency_Hz * t));
    st.next_index = grid.index0 + size(in, 1);
end
