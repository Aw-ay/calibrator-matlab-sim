function pdwRef = pdw_reference_map(pdw, signalMetadata, calEstimate, ledger)
    % PDW_REFERENCE_MAP 只应用并登记尚未在IQ中实施的参考面补偿。

    pdwRef = pdw;
    applied = string(field_or(signalMetadata, 'applied_compensations', {}));
    calId = string(field_or(calEstimate, 'id', ''));
    if calId ~= "" && ~any(applied == calId)
        factor = field_or(calEstimate, 'power_gain_correction', 1);
        if isfield(pdwRef, 'peak_power_W')
            pdwRef.peak_power_W = pdwRef.peak_power_W * factor;
        end

        if isfield(pdwRef, 'mean_power_W')
            pdwRef.mean_power_W = pdwRef.mean_power_W * factor;
        end

        applied(end + 1) = calId;
    end

    corrections = field_or(ledger, 'corrections', struct([]));
    for k = 1:numel(corrections)
        id = string(corrections(k).id);
        if ~field_or(corrections(k), 'applied_in_iq', false) && ~any(applied == id)
            if isfield(pdwRef, 'toa_s')
                pdwRef.toa_s = pdwRef.toa_s - corrections(k).delay_s;
            end

            applied(end + 1) = id; %#ok<AGROW>
        end
    end

    pdwRef.reference_plane = field_or(calEstimate, 'output_reference_plane', signalMetadata.reference_plane);
    pdwRef.applied_compensations = cellstr(applied);
    pdwRef.reference_map_status = 'COMPENSATIONS_REGISTERED_ONCE';
end

function value = field_or(s, name, default)
    if isfield(s, name)
        value = s.(name);
    else
        value = default;
    end
end
