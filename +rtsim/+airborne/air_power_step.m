function [supplies, observations, st] = air_power_step(st, battery, motorLoads, cfgSupply, dt)
%AIR_POWER_STEP 简化电池荷电量、内阻压降和遥测滞后一阶模型。
arguments
    st (1,1) struct
    battery (1,1) struct
    motorLoads (1,1) struct
    cfgSupply (1,1) struct
    dt (1,1) double {mustBeNonnegative}
end
need(battery,{'voltage_V','capacity_Ah'}); need(motorLoads,{'current_A'});
need(cfgSupply,{'internal_resistance_Ohm','nominal_voltage_V', ...
    'undervoltage_V','telemetry_tau_s'});
if ~isfield(st,'remaining_Ah'); st.remaining_Ah=battery.capacity_Ah; end
if ~isfield(st,'telemetry_voltage_V'); st.telemetry_voltage_V=cfgSupply.nominal_voltage_V; end
st.remaining_Ah = max(0,st.remaining_Ah-motorLoads.current_A*dt/3600);
busVoltage = battery.voltage_V-motorLoads.current_A*cfgSupply.internal_resistance_Ohm;
st.telemetry_voltage_V = st.telemetry_voltage_V + dt/cfgSupply.telemetry_tau_s * ...
    (busVoltage-st.telemetry_voltage_V);
supplies.bus_voltage_V = busVoltage;
supplies.remaining_Ah = st.remaining_Ah;
supplies.voltage_perturbation_V = busVoltage-cfgSupply.nominal_voltage_V;
supplies.model_scope = "first-order battery and source-impedance assumption";
observations.bus_voltage_V = st.telemetry_voltage_V;
observations.undervoltage = busVoltage < cfgSupply.undervoltage_V;
end
function need(s,n)
for k=1:numel(n); if ~isfield(s,n{k}); error('rtsim:airborne:MissingField','缺少必需字段%s。',n{k}); end; end
end
