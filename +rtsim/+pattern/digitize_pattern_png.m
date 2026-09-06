function cuts = digitize_pattern_png(imageFiles, axisMetadata)
%DIGITIZE_PATTERN_PNG 以HSV指定颜色从方向图图片提取单值轨迹。
% axisMetadata须给出hue_deg、hue_tolerance_deg、x_limits、y_limits和plot_box_px。
files=string(imageFiles); files=files(:);
if any(~isfile(files))
    missing=files(~isfile(files));
    error('rtsim:pattern:MissingImage','缺少方向图图片：%s',strjoin(missing,', '));
end
required={'hue_deg','hue_tolerance_deg','x_limits','y_limits','plot_box_px'};
for k=1:numel(required)
    if ~isfield(axisMetadata,required{k}), error('rtsim:pattern:AxisMetadata','缺少轴元数据%s。',required{k}); end
end
cuts=repmat(struct('x',[],'y',[],'valid',[],'source_file','', ...
    'pixel_uncertainty_y',[],'status','AMPLITUDE_TRACE_FROM_IMAGE','has_phase',false),numel(files),1);
for k=1:numel(files)
    rgb=imread(files(k)); hsv=rgb2hsv(rgb(:,:,1:3));
    box=round(axisMetadata.plot_box_px); x0=box(1); y0=box(2); width=box(3); height=box(4);
    if x0<1 || y0<1 || x0+width-1>size(rgb,2) || y0+height-1>size(rgb,1)
        error('rtsim:pattern:PlotBox','plot_box_px超出图片范围。');
    end
    hue=hsv(y0:y0+height-1,x0:x0+width-1,1)*360;
    hueDistance=abs(mod(hue-axisMetadata.hue_deg+180,360)-180);
    saturation=hsv(y0:y0+height-1,x0:x0+width-1,2);
    value=hsv(y0:y0+height-1,x0:x0+width-1,3);
    mask=hueDistance<=axisMetadata.hue_tolerance_deg & ...
        saturation>=field_or(axisMetadata,'min_saturation',0.35) & value>=field_or(axisMetadata,'min_value',0.1);
    row=nan(1,width); spread=nan(1,width);
    for column=1:width
        hits=find(mask(:,column));
        if ~isempty(hits), row(column)=median(hits); spread(column)=max(0.5,std(double(hits))); end
    end
    x=linspace(axisMetadata.x_limits(1),axisMetadata.x_limits(2),width);
    y=axisMetadata.y_limits(2)-(row-1)/(max(height-1,1))*diff(axisMetadata.y_limits);
    yUncertainty=spread/max(height-1,1)*abs(diff(axisMetadata.y_limits));
    cuts(k)=struct('x',x,'y',y,'valid',isfinite(row),'source_file',char(files(k)), ...
        'pixel_uncertainty_y',yUncertainty,'status','AMPLITUDE_TRACE_FROM_IMAGE','has_phase',false);
end
end

function value=field_or(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
