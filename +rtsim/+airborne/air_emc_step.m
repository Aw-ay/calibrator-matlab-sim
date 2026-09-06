function [disturbances, st] = air_emc_step(st, motorState, couplingModel, grid)
%AIR_EMC_STEP 用确定性谐波表示假设的电机耦合路径。
arguments
    st (1,1) struct
    motorState (1,1) struct
    couplingModel (1,1) struct
    grid (1,1) struct
end
need(motorState,{'rotation_Hz','load_fraction'});
need(couplingModel,{'rf_amplitude_sqrt_W','clock_phase_rad', ...
    'supply_modulation_fraction','digital_error_probability'});
need(grid,{'index0','fs_Hz'});
t=double(grid.index0)/grid.fs_Hz;
carrier=sin(2*pi*motorState.rotation_Hz*t);
level=motorState.load_fraction*carrier;
disturbances.rf_additive = couplingModel.rf_amplitude_sqrt_W*level*[1 1];
disturbances.clock_phase_rad = couplingModel.clock_phase_rad*level;
disturbances.supply_modulation_fraction = ...
    couplingModel.supply_modulation_fraction*level;
disturbances.digital_error_probability = ...
    couplingModel.digital_error_probability*motorState.load_fraction;
disturbances.source = "assumption_model";
st.last_time_s=t;
end
function need(s,n)
for k=1:numel(n); if ~isfield(s,n{k}); error('rtsim:airborne:MissingField','缺少必需字段%s。',n{k}); end; end
end
