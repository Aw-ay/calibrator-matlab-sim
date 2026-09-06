function plot_result(result,fileName)
% 中文图展示物理接收、仪器发射、雷达距离像和平台轨迹。
fig=figure('Visible','off','Color','w','Position',[100,100,1200,800]);
closer=onCleanup(@() close(fig));
t=(0:size(result.radar_iq,1)-1)'/result.config.rates.fs_record_Hz*1e3;
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
nexttile; plot(t,abs(result.port_rx)); xlabel('时间 / ms'); ylabel('幅度 / sqrt(W)'); title('标定仪接收端'); legend('H','V'); grid on
nexttile; plot(t,abs(result.tx_iq)); xlabel('时间 / ms'); ylabel('幅度 / sqrt(W)'); title('标定仪发射端'); grid on
nexttile; r=(result.range_profile.delay_axis_s-result.config.radar.start_s)*299792458/2/1000;
p=sum(abs(result.range_profile.iq).^2,2);
% 图上显示峰值以下八十 dB，避免理想零噪声把纵轴拉至负三千 dB。
floorPower=max(max(p)*1e-8,realmin); plot(r,10*log10(max(p,floorPower)));
xlim(result.config.radar.receive_gate_m/1000); xlabel('距离 / km'); ylabel('匹配滤波功率 / dBW'); title('首脉冲雷达距离像'); grid on
nexttile; plot(result.platform_log(:,1)*1e3,result.platform_log(:,2:4)); xlabel('时间 / ms'); ylabel('坐标 / m'); title('平台真实位置'); legend('东','北','天'); grid on
sgtitle(['阶段 ',result.stage,'：双偏振有源标定仪复包络参考仿真']);
exportgraphics(fig,fileName,'Resolution',150);
end
