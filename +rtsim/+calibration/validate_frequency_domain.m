function validate_frequency_domain(cal, query)
    % 不外推温度、功率、量程或频率；缺少已声明域同样拒绝。

    d = cal.domain;
    names = fieldnames(d);
    for k = 1:numel(names)
        name = names{k};
        if ~isfield(query, name)
            error('rtsim:calibration:OutOfDomain', '缺少适用域字段：%s。', name);
        end

        value = query.(name);
        limits = d.(name);
        if ~isnumeric(value) || any(~isfinite(value), 'all') || isempty(value)
            error('rtsim:calibration:OutOfDomain', '适用域值必须有限。');
        end

        if strcmp(name, 'range_index')
            valid = all(ismember(value, limits), 'all');
        else
            valid = all(value >= min(limits) & value <= max(limits), 'all');
        end

        if ~valid
            error('rtsim:calibration:OutOfDomain', '超出已测量适用域：%s。', name);
        end
    end
end
