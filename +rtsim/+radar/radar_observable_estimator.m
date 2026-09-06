function obs = radar_observable_estimator(gates,pulseTimes,cfgEstimator)
% 在预先配置的雷达接收门内估计各脉冲峰值，不以目标真值定位峰。
c=299792458; count=numel(pulseTimes); ranges=nan(count,1);
peaks=complex(nan(count,2)); powers=nan(count,2);
for p=1:count
    r=(gates.delay_axis_s-pulseTimes(p))*c/2;
    valid=find(r>=cfgEstimator.receive_gate_m(1) & r<=cfgEstimator.receive_gate_m(2));
    energy=sum(abs(gates.iq(valid,:)).^2,2);
    [peak,j]=max(energy);
    if isempty(j) || peak<=0, continue; end
    k=valid(j); delta=0;
    if k>1 && k<size(gates.iq,1)
        e=sum(abs(gates.iq(k-1:k+1,:)).^2,2); den=e(1)-2*e(2)+e(3);
        if den<0, delta=max(-0.5,min(0.5,0.5*(e(1)-e(3))/den)); end
    end
    ranges(p)=r(k)+delta/gates.fs_Hz*c/2; peaks(p,:)=gates.iq(k,:); powers(p,:)=abs(peaks(p,:)).^2;
end
obs.range_per_pulse_m=ranges; obs.range_m=mean(ranges,'omitnan');
obs.power_W=mean(powers,1,'omitnan'); obs.ZDR_dB=10*log10(obs.power_W(1)/obs.power_W(2));
obs.PhiDP_deg=angle(sum(peaks(:,1).*conj(peaks(:,2)),'omitnan'))*180/pi;
obs.doppler_Hz=NaN; obs.velocity_mps=NaN;
if count>=2 && all(isfinite(peaks(:,1)))
    dt=diff(pulseTimes(:)); phase=angle(peaks(2:end,1).*conj(peaks(1:end-1,1)));
    obs.doppler_Hz=mean(phase./(2*pi*dt));
    obs.velocity_mps=-obs.doppler_Hz*299792458/cfgEstimator.fc_Hz/2;
end
obs.rho_HV=abs(sum(peaks(:,1).*conj(peaks(:,2)),'omitnan'))/sqrt(sum(abs(peaks(:,1)).^2,'omitnan')*sum(abs(peaks(:,2)).^2,'omitnan'));
obs.rho_scope='仅确定性相干信号相关性，不构成随机天气相关系数验收';
obs.reflectivity_status='NOT_APPLICABLE'; obs.range_kind='当前门内表观距离';
end
