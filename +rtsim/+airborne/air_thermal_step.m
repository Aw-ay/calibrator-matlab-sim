function [temperatures, st] = air_thermal_step(st, ambient, electricalLoads, cfgThermal, dt)
    % AIR_THERMAL_STEP 集总热阻热容与独立传感器滞后一阶模型。

    arguments
        st (1, 1) struct
        ambient (1, 1) struct
        electricalLoads (1, 1) struct
        cfgThermal (1, 1) struct
        dt (1, 1) double {mustBeNonnegative}
    end

    need(ambient, {'temperature_C'});
    need(electricalLoads, {'power_W'});
    need(cfgThermal, {'thermal_resistance_K_per_W', ...
        'thermal_capacitance_J_per_K', 'sensor_tau_s'});
    if ~isfield(st, 'junction_C')
        st.junction_C = ambient.temperature_C;
    end

    if ~isfield(st, 'sensor_C')
        st.sensor_C = ambient.temperature_C;
    end

    target = ambient.temperature_C + electricalLoads.power_W * ...
        cfgThermal.thermal_resistance_K_per_W;
    tau = cfgThermal.thermal_resistance_K_per_W * ...
        cfgThermal.thermal_capacitance_J_per_K;
    st.junction_C = st.junction_C + dt / tau * (target - st.junction_C);
    st.sensor_C = st.sensor_C + dt / cfgThermal.sensor_tau_s * ...
        (st.junction_C - st.sensor_C);
    temperatures.junction_C = st.junction_C;
    temperatures.sensor_C = st.sensor_C;
    temperatures.model_scope = "first-order lumped thermal assumption";
end

function need(s, n)
    for k = 1:numel(n)
        if ~isfield(s, n{k})
            error('rtsim:airborne:MissingField', '缺少必需字段%s。', n{k});
        end
    end
end
