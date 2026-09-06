function [gate, st, faults] = safety_fsm_step(commands, observedStatus, st, cfgSafety)
% 观测到时钟失锁、过温、欠压时硬静音；所有信号源共用此门。
faults={};
if ~observedStatus.pll_locked, faults{end+1}='PLL_UNLOCKED'; end
if observedStatus.temperature_C>cfgSafety.max_temperature_C, faults{end+1}='OVER_TEMPERATURE'; end
if observedStatus.voltage_V<cfgSafety.min_voltage_V, faults{end+1}='UNDER_VOLTAGE'; end
gate=isempty(faults) && commands.enable;
st.muted=~gate; st.faults=faults;
end
