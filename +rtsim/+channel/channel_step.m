function [out, st, diag] = channel_step(in, st, channelCfg, geometry)
%CHANNEL_STEP 静态/冻结几何下的单程OTA或电缆传播。
% 主控短块调用时，块内距离和姿态冻结；本函数不模拟块内连续运动。
kind=upper(string(channelCfg.kind));
switch kind
    case "CABLE"
        path=struct('delay_s',channelCfg.cable_delay_s,'matrix',channelCfg.cable_gain*eye(2), ...
            'distance_m',NaN,'kind','CABLE','valid',true);
    case "OTA"
        tx=struct('position_m',geometry.tx_position_m, ...
            'tx_jones',field_or(geometry,'tx_jones',eye(2)));
        rx=struct('position_m',geometry.rx_position_m, ...
            'rx_jones',field_or(geometry,'rx_jones',eye(2)));
        path=rtsim.channel.direct_path(tx,rx,channelCfg);
        reflection=field_or(channelCfg,'reflection',struct('enabled',false));
        if field_or(reflection,'enabled',false)
            reflected=rtsim.channel.mirror_path(tx,rx,reflection,channelCfg.fc_Hz);
            path=[path,reflected];
        end
    otherwise
        error('rtsim:channel:Kind','channelCfg.kind仅支持OTA或CABLE。');
end
grid=struct('fs_Hz',channelCfg.fs_Hz);
[out,st]=rtsim.channel.combine_complex_paths(in,path,st,grid);
diag=struct('kind',char(kind),'path_count',numel(path),'paths',path, ...
    'geometry_mode','STATIC_FROZEN_PER_BLOCK','one_way',true, ...
    'fractional_delay_method','CAUSAL_LINEAR');
end

function value=field_or(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
