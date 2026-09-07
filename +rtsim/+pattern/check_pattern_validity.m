function validity = check_pattern_validity(patterns, geometry, requirements)
    % CHECK_PATTERN_VALIDITY 检查方向图对指定几何和验收要求是否具备资格。

    reasons = strings(0, 1);
    if field_or(requirements, 'require_phase', false) && ~field_or(patterns, 'has_phase', false)
        reasons(end + 1) = "MISSING_PHASE";
    end

    if field_or(requirements, 'require_polarization', false) && ~field_or(patterns, 'has_full_jones', true)
        reasons(end + 1) = "INCOMPLETE_JONES";
    end

    outsideAz = diff(patterns.az_range_deg) < 359 && ...
        (geometry.az_deg < patterns.az_range_deg(1) || geometry.az_deg > patterns.az_range_deg(2));
    if outsideAz || geometry.el_deg < patterns.el_range_deg(1) || geometry.el_deg > patterns.el_range_deg(2)
        reasons(end + 1) = "OUTSIDE_ANGLE_DOMAIN";
    end

    if geometry.freq_Hz < patterns.freq_range_Hz(1) || geometry.freq_Hz > patterns.freq_range_Hz(2)
        reasons(end + 1) = "OUTSIDE_FREQUENCY_DOMAIN";
    end

    if geometry.range_m < field_or(patterns, 'far_field_min_m', 0)
        reasons(end + 1) = "FAR_FIELD_NOT_SATISFIED";
    end

    if strcmpi(patterns.kind, 'CST_FARFIELD')
        if ~isfinite(patterns.frequency_Hz)
            reasons(end + 1) = "UNKNOWN_SOURCE_FREQUENCY";
        end

        if field_or(requirements, 'require_polarization', false) && ~patterns.full_polarization_qualified
            reasons(end + 1) = "UNQUALIFIED_POLARIZATION_METADATA";
        end
    end

    maxCond = field_or(requirements, 'max_condition_number', Inf);
    if isfield(patterns, 'jones_samples')
        conds = zeros(1, size(patterns.jones_samples, 3));
        for k = 1:numel(conds)
            conds(k) = cond(patterns.jones_samples(:, :, k));
        end

        worst = max(conds);
    elseif strcmpi(patterns.kind, 'CST_FARFIELD') && patterns.has_full_jones && isfinite(maxCond)
        matrices = reshape(permute(patterns.field_samples, [3 4 1 2]), 2, 2, []);
        conds = zeros(1, size(matrices, 3));
        for k = 1:numel(conds)
            conds(k) = cond(matrices(:, :, k));
        end

        worst = max(conds);
    else
        worst = 1;
    end

    if worst > maxCond
        reasons(end + 1) = "ILL_CONDITIONED_JONES";
    end

    validity = struct('qualified', isempty(reasons), 'reasons', reasons, 'worst_condition_number', worst, ...
        'phase_qualified', field_or(patterns, 'has_phase', false), ...
        'polarization_qualified', field_or(patterns, 'has_full_jones', true) && ...
        field_or(patterns, 'has_phase', false) && field_or(patterns, 'full_polarization_qualified', true));
end

function value = field_or(s, name, default)
    if isfield(s, name)
        value = s.(name);
    else
        value = default;
    end
end
