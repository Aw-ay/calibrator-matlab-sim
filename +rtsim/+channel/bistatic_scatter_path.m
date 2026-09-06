function paths = bistatic_scatter_path(txPose, rxPose, scatterers, cfg)
%BISTATIC_SCATTER_PATH 构造有限散射体的双站路径。
% effective_area_m2按双站等效散射截面积解释，采用雷达方程场幅归一化。
c=299792458; lambda=c/cfg.fc_Hz;
n=numel(scatterers);
paths=repmat(struct('delay_s',0,'matrix',zeros(2),'distance_m',0, ...
    'tx_distance_m',0,'rx_distance_m',0,'kind','BISTATIC','valid',false),1,n);
Jtx=field_or(txPose,'tx_jones',eye(2)); Jrx=field_or(rxPose,'rx_jones',eye(2));
for k=1:n
    p=scatterers(k).position_m(:);
    Rt=norm(p-txPose.position_m(:)); Rr=norm(rxPose.position_m(:)-p);
    if Rt<=0 || Rr<=0, error('rtsim:channel:ZeroRange','散射体不能与相位中心重合。'); end
    S=field_or(scatterers(k),'scattering_matrix',eye(2));
    sigma=field_or(scatterers(k),'effective_area_m2',1);
    amplitude=lambda*sqrt(sigma)/((4*pi)^(3/2)*Rt*Rr);
    phase=exp(-1j*2*pi*(Rt+Rr)/lambda);
    paths(k)=struct('delay_s',(Rt+Rr)/c,'matrix',Jrx*(amplitude*phase*S)*Jtx, ...
        'distance_m',Rt+Rr,'tx_distance_m',Rt,'rx_distance_m',Rr,'kind','BISTATIC','valid',true);
end
end

function value=field_or(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
