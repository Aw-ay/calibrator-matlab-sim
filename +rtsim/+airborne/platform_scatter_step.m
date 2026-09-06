function [echo, st] = platform_scatter_step(radarTx, geometry, bodyModel, st)
%PLATFORM_SCATTER_STEP 独立生成机体被动回波，不经过仪器收发链。
arguments
    radarTx (:,2) double
    geometry (1,1) struct
    bodyModel (1,1) struct
    st (1,1) struct
end
if ~isfield(geometry,'range_m') || ~isfield(geometry,'phase_rad') || ...
        ~isfield(bodyModel,'amplitude_gain') || ...
        ~isfield(bodyModel,'polarization_matrix')
    error('rtsim:airborne:MissingField','散射几何或机体模型字段不完整。');
end
if geometry.range_m <= 0
    error('rtsim:airborne:InvalidRange','散射距离必须为正。');
end
% amplitude_gain应由调用方合并波长、RCS、天线增益及其它雷达方程常数；
% 此处仅明确施加单站往返传播的1/R^2场幅度。
gain = bodyModel.amplitude_gain/geometry.range_m^2 * exp(1i*geometry.phase_rad);
echo = gain * radarTx * bodyModel.polarization_matrix.';
st.last_range_m = geometry.range_m;
end
