function displayPattern = render_pattern_sys(rawPattern, scanModel, receiverModel)
%RENDER_PATTERN_SYS 生成扫描和接收积分后的显示方向图，不修改Pattern_raw。
displayPattern=rawPattern;
displayPattern.Pattern_raw=rawPattern;
field=select_amplitude_field(rawPattern);
values=rawPattern.(field);
scanKernel=normalize_kernel(field_or(scanModel,'kernel',1));
receiverKernel=normalize_kernel(field_or(receiverModel,'kernel',1));
filtered=convn(values,reshape(scanKernel,[],1),'same');
filtered=convn(filtered,reshape(receiverKernel,[],1),'same');
displayPattern.(field)=filtered;
displayPattern.processing=struct('scan_kernel',scanKernel,'receiver_kernel',receiverKernel, ...
    'purpose','DISPLAY_ONLY','raw_unchanged',true);
end

function field=select_amplitude_field(s)
choices={'amplitude_linear','gain_linear','gain_dB'};
for k=1:numel(choices)
    if isfield(s,choices{k}), field=choices{k}; return, end
end
error('rtsim:pattern:MissingAmplitude','原始方向图缺少可显示的幅度或增益字段。');
end

function kernel=normalize_kernel(kernel)
validateattributes(kernel,{'numeric'},{'real','finite','nonempty'});
if sum(kernel)==0, error('rtsim:pattern:Kernel','积分核的和不能为零。'); end
kernel=kernel(:)/sum(kernel);
end

function value=field_or(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
