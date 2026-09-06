function plan = solve_target_delay(task, geometryEstimate, latencyEstimate, grid)
% 虚拟总往返时间减真实两程估计，再拆分固定流水与等待时间。
c=299792458;
device=2*task.range_m/c-geometryEstimate.roundtrip_delay_s;
plan.device_delay_s=device; plan.fixed_latency_s=latencyEstimate.fixed_s;
plan.wait_s=device-plan.fixed_latency_s;
plan.delay_samples=device*grid.fs_Hz;
plan.accepted=plan.wait_s>=0;
plan.reason=''; if ~plan.accepted, plan.reason='NONCAUSAL_DELAY'; end
end
