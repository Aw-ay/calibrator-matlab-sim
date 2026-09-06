function selection = range_select_eop(qualification, policy)
    % 整脉冲 H/V 共用最高未削顶量程；任何时刻任一极化超限即失效。

    if isnumeric(qualification)
        peak = reshape(max(max(max(abs(real(qualification)), abs(imag(qualification))), [], 1), [], 2), 1, []);
    else
        peak = qualification.peak;
    end

    id = find(peak < policy.limit, 1, 'first');
    selection = struct('range_id', 0, 'status', 'INVALID', 'peak', peak);
    if ~isempty(id)
        selection.range_id = id;
        selection.status = 'VALID';
    end
end
