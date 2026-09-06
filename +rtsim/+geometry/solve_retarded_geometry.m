function geometry = solve_retarded_geometry(txEvent, deviceTask, trajectories, cfgGeom)
%SOLVE_RETARDED_GEOMETRY 迭代求解去程和回程的迟滞传播几何。
% trajectories.radar/device可为函数句柄；句柄在给定秒时刻返回3×1位置，
% 或返回含position_m及可选velocity_mps的结构。真值和预测轨迹共用此接口。
c = field_or(cfgGeom,'c_mps',299792458);
tol = field_or(cfgGeom,'time_tolerance_s',1e-13);
maxIterations = field_or(cfgGeom,'max_iterations',30);
t0 = txEvent.time_s;
radar0 = sample_trajectory(trajectories.radar,t0);
t1 = t0 + norm(sample_trajectory(trajectories.device,t0).position_m-radar0.position_m)/c;
[t1, outboundIterations, outboundConverged] = solve_arrival(t0,radar0.position_m, ...
    trajectories.device,t1,c,tol,maxIterations);
deviceRx = sample_trajectory(trajectories.device,t1);
if isfield(deviceTask,'transmit_time_s')
    t2 = deviceTask.transmit_time_s;
else
    t2 = t1 + field_or(deviceTask,'turnaround_s',field_or(deviceTask,'delay_s',0));
end
if t2 < t1
    error('rtsim:geometry:NoncausalTask','设备发射事件不能早于接收事件。');
end
deviceTx = sample_trajectory(trajectories.device,t2);
t3 = t2 + norm(sample_trajectory(trajectories.radar,t2).position_m-deviceTx.position_m)/c;
[t3, returnIterations, returnConverged] = solve_arrival(t2,deviceTx.position_m, ...
    trajectories.radar,t3,c,tol,maxIterations);
radarRx = sample_trajectory(trajectories.radar,t3);
outVector=deviceRx.position_m-radar0.position_m;
returnVector=radarRx.position_m-deviceTx.position_m;
geometry=struct('t0_s',t0,'t1_s',t1,'t2_s',t2,'t3_s',t3, ...
    'radar_tx_position_m',radar0.position_m,'device_rx_position_m',deviceRx.position_m, ...
    'device_tx_position_m',deviceTx.position_m,'radar_rx_position_m',radarRx.position_m, ...
    'outbound_range_m',norm(outVector),'return_range_m',norm(returnVector), ...
    'outbound_los',outVector/norm(outVector),'return_los',returnVector/norm(returnVector), ...
    'outbound_radial_velocity_mps',dot(deviceRx.velocity_mps-radar0.velocity_mps,outVector/norm(outVector)), ...
    'return_radial_velocity_mps',dot(radarRx.velocity_mps-deviceTx.velocity_mps,returnVector/norm(returnVector)), ...
    'outbound_iterations',outboundIterations,'return_iterations',returnIterations, ...
    'converged',outboundConverged && returnConverged);
if ~geometry.converged
    error('rtsim:geometry:LightTimeNoConvergence','光行时迭代未在限定次数内收敛。');
end
end

function [arrival,iterations,converged]=solve_arrival(departure,sourcePosition,targetTrajectory,guess,c,tol,maxIterations)
arrival=guess; converged=false;
for iterations=1:maxIterations
    target=sample_trajectory(targetTrajectory,arrival);
    next=departure+norm(target.position_m-sourcePosition)/c;
    if abs(next-arrival)<=tol
        arrival=next; converged=true; return
    end
    arrival=next;
end
end

function state=sample_trajectory(trajectory,t)
if isa(trajectory,'function_handle'), value=trajectory(t); else, value=trajectory; end
if isnumeric(value), state=struct('position_m',value(:),'velocity_mps',zeros(3,1)); else, state=value; end
validateattributes(state.position_m,{'numeric'},{'real','finite','numel',3});
state.position_m=state.position_m(:);
state.velocity_mps=field_or(state,'velocity_mps',zeros(3,1)); state.velocity_mps=state.velocity_mps(:);
end

function value=field_or(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
