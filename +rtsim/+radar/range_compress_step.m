function [gates,st,diag] = range_compress_step(iq,st,waveformProfile,timing)
% 匹配滤波以完整线性卷积实现，显式扣除参考波形长度造成的偏移。
fs=timing.fs_Hz; n=round(waveformProfile.pulse_width_s*fs);
t=(0:n-1)'/fs;
if strcmp(waveformProfile.kind,'CW'), ref=ones(n,1);
else, ref=exp(1i*2*pi*(-waveformProfile.bandwidth_Hz/2*t+waveformProfile.bandwidth_Hz/(2*waveformProfile.pulse_width_s)*t.^2)); end
h=conj(flipud(ref))/sum(abs(ref).^2);
gates.iq=[conv(iq(:,1),h),conv(iq(:,2),h)];
gates.delay_axis_s=((0:size(gates.iq,1)-1)'-(n-1))/fs;
gates.fs_Hz=fs; gates.reference_energy=sum(abs(ref).^2);
diag.filter_delay_samples=n-1; st.complete=true;
end
