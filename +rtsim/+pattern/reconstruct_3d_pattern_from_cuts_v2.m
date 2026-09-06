function model = reconstruct_3d_pattern_from_cuts_v2(cuts, modelAssumptions)
%RECONSTRUCT_3D_PATTERN_FROM_CUTS_V2 从幅度切面生成明确标注的近似三维模型。
% 不从幅度或图片伪造复相位；若只有一条方位切面，仰角方向按给定模型复制。
azGrid=modelAssumptions.az_grid_deg(:).'; elGrid=modelAssumptions.el_grid_deg(:);
if isfield(cuts,'az_deg') && isfield(cuts,'amplitude_linear')
    azAmplitude=interp1(cuts.az_deg(:),cuts.amplitude_linear(:),azGrid,'linear',0);
else
    error('rtsim:pattern:MissingCuts','至少需要az_deg和amplitude_linear切面。');
end
if isfield(cuts,'el_deg') && isfield(cuts,'el_amplitude_linear')
    elAmplitude=interp1(cuts.el_deg(:),cuts.el_amplitude_linear(:),elGrid,'linear',0);
    elAmplitude=elAmplitude/max(elAmplitude,[],'all');
else
    elAmplitude=ones(size(elGrid));
end
amplitude=elAmplitude*azAmplitude;
model=struct('az_deg',azGrid,'el_deg',elGrid,'amplitude_linear',amplitude, ...
    'status','APPROX_AMPLITUDE_ONLY','has_phase',false,'jones_matrix_available',false, ...
    'source_cuts',cuts,'assumptions',modelAssumptions, ...
    'warning','切面插值仅为幅度近似，不能用于复相位或完整极化验收。');
end
