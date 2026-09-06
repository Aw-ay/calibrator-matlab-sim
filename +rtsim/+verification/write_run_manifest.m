function manifest = write_run_manifest(cfg, files, versions, seeds, reports)
%WRITE_RUN_MANIFEST 保存配置、版本、种子、报告及工程内文件 SHA-256。
% files 可为路径 cellstr，或含 paths/out_dir/project_root 的结构体。
arguments
    cfg struct
    files
    versions struct
    seeds struct
    reports struct
end

[paths, outDir, projectRoot] = localInputs(cfg, files);
rootCanonical = localCanonical(projectRoot);
outCanonical = localCanonical(outDir);
if ~localIsInside(outCanonical, rootCanonical)
    error('rtsim:verification:ExternalOutput', '运行清单输出目录必须位于 project_root 内。');
end
if ~isfolder(outCanonical)
    [ok, message] = mkdir(outCanonical);
    assert(ok, 'rtsim:verification:CreateOutputFailed', '无法创建输出目录：%s', message);
end

emptyRecord = struct('path', "", 'status', "", 'sha256', "", 'bytes', uint64(0));
records = repmat(emptyRecord, numel(paths), 1);
for k = 1:numel(paths)
    requested = char(paths{k});
    if ~isfile(requested) && ~isfolder(fileparts(requested)) && ~localIsAbsolute(requested)
        requested = fullfile(rootCanonical, requested);
    elseif ~localIsAbsolute(requested)
        requested = fullfile(rootCanonical, requested);
    end
    canonical = localCanonical(requested);
    if ~localIsInside(canonical, rootCanonical)
        records(k).path = string(localSafeName(requested));
        records(k).status = "EXCLUDED_EXTERNAL";
        continue
    end
    relative = localRelative(canonical, rootCanonical);
    records(k).path = string(relative);
    if localLooksSecret(relative)
        records(k).status = "EXCLUDED_SECRET";
    elseif ~isfile(canonical)
        records(k).status = "MISSING";
    else
        info = dir(canonical);
        records(k).status = "HASHED";
        records(k).sha256 = string(localSha256(canonical));
        records(k).bytes = uint64(info.bytes);
    end
end

rawManifest = struct('schema_version', "rtsim-run-manifest-1", ...
    'configuration', cfg, 'versions', versions, 'seeds', seeds, ...
    'reports', reports, 'files', records);
% 返回值与 JSON 使用同一可序列化结构，复数可按 encoding/real/imag/size 还原。
manifest = localSerializable(rawManifest);
jsonPath = fullfile(outCanonical, 'run_manifest.json');
fid = fopen(jsonPath, 'wb');
assert(fid >= 0, 'rtsim:verification:WriteFailed', '无法写入 run_manifest.json。');
cleanup = onCleanup(@() fclose(fid));
payload = jsonencode(manifest, PrettyPrint=true);
fwrite(fid, unicode2native(payload, 'UTF-8'), 'uint8');
end

function [paths, outDir, projectRoot] = localInputs(cfg, files)
if iscellstr(files) || (iscell(files) && all(cellfun(@(x) ischar(x) || isstring(x), files)))
    paths = files;
    projectRoot = localField(cfg, 'project_root', pwd);
    outDir = localField(cfg, 'manifest_out_dir', fullfile(projectRoot, 'results'));
elseif isstruct(files) && isfield(files, 'paths') && isfield(files, 'out_dir')
    paths = files.paths;
    projectRoot = localField(files, 'project_root', localField(cfg, 'project_root', pwd));
    outDir = files.out_dir;
else
    error('rtsim:verification:InvalidFileList', 'files 必须为路径 cellstr 或含 paths/out_dir 的结构体。');
end
assert(iscell(paths), 'rtsim:verification:InvalidFileList', 'paths 必须为 cell 数组。');
end

function hash = localSha256(path)
fid = fopen(path, 'rb');
assert(fid >= 0, 'rtsim:verification:ReadFailed', '无法读取待哈希文件。');
cleanup = onCleanup(@() fclose(fid));
digest = java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes = fread(fid, 1024*1024, '*uint8');
    if ~isempty(bytes), digest.update(bytes); end
end
hash = lower(reshape(dec2hex(typecast(digest.digest(), 'uint8'), 2).', 1, []));
end

function canonical = localCanonical(path)
canonical = char(java.io.File(char(path)).getCanonicalPath());
end

function tf = localIsInside(path, root)
if strcmpi(path, root)
    tf = true;
else
    prefix = [root filesep];
    tf = strncmpi(path, prefix, numel(prefix));
end
end

function relative = localRelative(path, root)
if strcmpi(path, root), relative = '.'; else, relative = path(numel(root)+2:end); end
end

function tf = localLooksSecret(relative)
[~, name, ext] = fileparts(lower(relative));
base = [name ext];
tf = strcmp(base, '.env') || contains(base, 'credential') || ...
    contains(base, 'secret') || contains(base, 'private_key') || ...
    any(strcmp(ext, {'.pem','.p12','.pfx','.key'}));
end

function name = localSafeName(path)
[~, stem, ext] = fileparts(path);
name = [stem ext];
end

function tf = localIsAbsolute(path)
path = char(path);
tf = ~isempty(regexp(path, '^[A-Za-z]:[\\/]|^\\\\', 'once'));
end

function value = localField(s, name, defaultValue)
if isfield(s, name), value = s.(name); else, value = defaultValue; end
end

function out = localSerializable(in)
% 递归转换复数；对未知对象明确拒绝，禁止静默转成字符串。
if isnumeric(in)
    if ~isreal(in)
        out = struct('encoding', "complex", 'real', full(real(in)), ...
            'imag', full(imag(in)), 'size', size(in));
    else
        out = in;
    end
elseif islogical(in) || ischar(in) || isstring(in)
    out = in;
elseif iscell(in)
    out = cell(size(in));
    for k = 1:numel(in)
        out{k} = localSerializable(in{k});
    end
elseif isstruct(in)
    out = in;
    names = fieldnames(in);
    for k = 1:numel(in)
        for n = 1:numel(names)
            out(k).(names{n}) = localSerializable(in(k).(names{n}));
        end
    end
else
    error('rtsim:verification:UnsupportedManifestType', ...
        '清单含不支持的类型 %s；请先显式转换，不能静默字符串化。', class(in));
end
end
