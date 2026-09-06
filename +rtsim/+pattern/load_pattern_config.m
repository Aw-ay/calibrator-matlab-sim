function patterns = load_pattern_config(cfgPattern)
%LOAD_PATTERN_CONFIG 载入理想Jones模型或含复Jones列的实测CSV。
kind=upper(string(cfgPattern.kind));
switch kind
    case "IDEAL"
        patterns=struct('kind','IDEAL','raw',cfgPattern,'has_phase',true, ...
            'has_full_jones',true,'az_range_deg',[-180,180],'el_range_deg',[-90,90], ...
            'freq_range_Hz',[-Inf,Inf],'far_field_min_m',0,'quality_label','IDEAL_MODEL');
    case "MEASURED_CSV"
        file=string(cfgPattern.file);
        if ~isfile(file), error('rtsim:pattern:MissingFile','找不到方向图CSV：%s',file); end
        T=readtable(file,'VariableNamingRule','preserve');
        required=["az_deg","el_deg","freq_Hz"];
        if ~all(ismember(required,string(T.Properties.VariableNames)))
            error('rtsim:pattern:Columns','CSV必须包含az_deg、el_deg和freq_Hz。');
        end
        [J,hasPhase,hasFullJones]=read_jones(T);
        patterns=struct('kind','MEASURED_CSV','raw',T,'source_file',char(file), ...
            'az_deg',T.az_deg(:),'el_deg',T.el_deg(:),'freq_Hz',T.freq_Hz(:), ...
            'jones_samples',J,'has_phase',hasPhase,'has_full_jones',hasFullJones, ...
            'az_range_deg',[min(T.az_deg),max(T.az_deg)], ...
            'el_range_deg',[min(T.el_deg),max(T.el_deg)], ...
            'freq_range_Hz',[min(T.freq_Hz),max(T.freq_Hz)], ...
            'far_field_min_m',field_or(cfgPattern,'far_field_min_m',0), ...
            'quality_label',char(string(field_or(cfgPattern,'quality_label','MEASURED_UNQUALIFIED'))));
    otherwise
        error('rtsim:pattern:Kind','方向图类型仅支持IDEAL或MEASURED_CSV。');
end
end

function [J,hasPhase,hasFull]=read_jones(T)
names=string(T.Properties.VariableNames); n=height(T); J=zeros(2,2,n);
complexCols=["J11_re","J11_im","J12_re","J12_im","J21_re","J21_im","J22_re","J22_im"];
amplitudeCols=["J11_mag","J12_mag","J21_mag","J22_mag"];
if all(ismember(complexCols,names))
    J(1,1,:)=T.J11_re+1j*T.J11_im; J(1,2,:)=T.J12_re+1j*T.J12_im;
    J(2,1,:)=T.J21_re+1j*T.J21_im; J(2,2,:)=T.J22_re+1j*T.J22_im;
    hasPhase=true; hasFull=true;
elseif all(ismember(amplitudeCols,names))
    J(1,1,:)=T.J11_mag; J(1,2,:)=T.J12_mag; J(2,1,:)=T.J21_mag; J(2,2,:)=T.J22_mag;
    hasPhase=false; hasFull=true;
else
    error('rtsim:pattern:JonesColumns','CSV须含8列Jij_re/im，或4列Jij_mag。');
end
end

function value=field_or(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
