function outDir = save_result(result)
% 每次运行创建独立目录，保存波形、元数据、PDW、中文报告和图片。
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
outDir=fullfile(result.config.output.root,[result.stage,'_',stamp]);
if ~exist(outDir,'dir'), mkdir(outDir); end
save(fullfile(outDir,'result.mat'),'result','-v7.3');
if ~isempty(result.pdw), writetable(struct2table(result.pdw),fullfile(outDir,'pdw.csv'),'Encoding','UTF-8'); end
report=struct('stage',result.stage,'created_at',result.created_at,'model_scope',result.model_scope, ...
    'observables',result.observables,'diagnostics',result.diagnostics,'scores',result.scores, ...
    'audit',result.audit,'latency_ledger',result.latency_ledger,'phase_ledger',result.phase_ledger);
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
sources=dir(fullfile(root,'**','*.m')); sourcePaths=fullfile({sources.folder},{sources.name});
files=struct('paths',{sourcePaths},'project_root',root,'out_dir',outDir);
rtsim.verification.write_run_manifest(result.config,files,struct('matlab',version), ...
    struct('scenario',result.config.seed,'calibration_train',result.config.seed+1,'calibration_holdout',result.config.seed+2),report);
fid=fopen(fullfile(outDir,'run_report.json'),'w','n','UTF-8');
assert(fid>=0,'rtsim:Output','无法创建报告文件。'); closer=onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true)); clear closer
fid=fopen(fullfile(outDir,'运行报告.md'),'w','n','UTF-8'); closer=onCleanup(@() fclose(fid));
fprintf(fid,'# 阶段 %s 仿真运行报告\n\n模型：%s\n\n',result.stage,result.model_scope);
fprintf(fid,'目标距离：%.3f m；估计距离：%.3f m；误差：%.3f m。\n\n',result.config.target.range_m,result.observables.range_m,result.scores.range_error_m);
fprintf(fid,'检测脉冲：%d；拒绝回放：%d；捕获丢失：%d；DMA 待传：%.0f 字节。\n\n',numel(result.pdw),result.diagnostics.rejected_replays,result.diagnostics.dropped_captures,result.diagnostics.dma_pending_bytes);
fprintf(fid,'结果仅用于算法参考。实测复方向图、板卡精确配置与实测校准资料缺失，对应资格为 BLOCKED_MISSING_DATA。\n');
clear closer
rtsim.verification.plot_result(result,fullfile(outDir,'仿真结果.png'));
end
