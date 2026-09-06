function command = solve_phase_command(task, modeledPhaseEstimate, timeGrid, convention)
    % 只施加剩余相位；物理传播相位不能再次叠加完整运动多普勒。

    if nargin < 4
        convention = '负传播相位';
    end

    lambda = 299792458 / modeledPhaseEstimate.fc_Hz;
    origin = timeGrid.index0 / timeGrid.fs_Hz;
    command.phase0_rad = -4 * pi * task.range_m / lambda + task.phase0_rad - ...
        modeledPhaseEstimate.phase_rad + 2 * pi * modeledPhaseEstimate.doppler_Hz * origin;
    command.frequency_Hz = task.doppler_Hz - modeledPhaseEstimate.doppler_Hz;
    command.time_origin_s = timeGrid.index0 / timeGrid.fs_Hz;
    command.convention = convention;
end
