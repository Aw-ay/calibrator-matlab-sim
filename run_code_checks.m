function issues = run_code_checks()
% 对所有 MATLAB 源码运行静态检查并保存可审阅诊断。
root=fileparts(mfilename('fullpath')); files=dir(fullfile(root,'**','*.m'));
issues=struct('file',{},'line',{},'message',{});
for k=1:numel(files)
    pathName=fullfile(files(k).folder,files(k).name); messages=checkcode(pathName,'-id');
    for j=1:numel(messages)
        issues(end+1)=struct('file',pathName,'line',messages(j).line,'message',messages(j).message); %#ok<AGROW>
    end
end
outDir=fullfile(root,'results','acceptance'); if ~exist(outDir,'dir'), mkdir(outDir); end
fid=fopen(fullfile(outDir,'code_analysis.json'),'w','n','UTF-8'); closer=onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(issues,'PrettyPrint',true));
fprintf('Code Analyzer: %d files, %d diagnostics.\n',numel(files),numel(issues));
disp(issues);
end
