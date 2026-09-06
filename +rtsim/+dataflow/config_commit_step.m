function [activeCfg, st, diag] = config_commit_step(shadowWrites, safeBoundary, st)
%CONFIG_COMMIT_STEP 在安全边界将完整shadow配置原子提交。
arguments
    shadowWrites (1,1) struct
    safeBoundary (1,1) logical
    st (1,1) struct
end
if ~isfield(st,'activeCfg'); st.activeCfg=struct(); end
if ~isfield(st,'version'); st.version=uint32(0); end
if ~isfield(st,'pendingCfg'); st.pendingCfg=struct(); end
st.pendingCfg=merge(st.pendingCfg,shadowWrites);
diag.pending=~isempty(fieldnames(st.pendingCfg)); diag.committed=false;
if safeBoundary && diag.pending
    st.activeCfg=merge(st.activeCfg,st.pendingCfg); st.pendingCfg=struct();
    st.version=st.version+uint32(1); diag.committed=true; diag.pending=false;
end
activeCfg=st.activeCfg; diag.version=st.version;
end
function out=merge(out,in)
names=fieldnames(in); for k=1:numel(names); out.(names{k})=in.(names{k}); end
end
