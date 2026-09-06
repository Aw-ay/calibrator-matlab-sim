function [events, audit] = pdw_fuse(candidates, ~)
    % 默认保留所有物理候选，仅有明确重复标识时合并同源报告。

    events = candidates;
    audit.raw_candidates = candidates;
    audit.rejection_reason = {};
    audit.scope = '未提供同源标识则不删除弱直达或邻近脉冲';
    if ~isempty(candidates) && isfield(candidates, 'association_id')
        [~, keep] = unique([candidates.association_id], 'stable');
        events = candidates(keep);
        audit.rejection_reason = repmat({'EXPLICIT_DUPLICATE_ID'}, 1, numel(candidates) - numel(keep));
    end
end
