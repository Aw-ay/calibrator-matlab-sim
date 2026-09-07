function pattern = load_farfield_pattern(cfg)
    % LOAD_FARFIELD_PATTERN 读取CST规则球面复场；每文件仅对应一个已施加的激励向量。
    % 两个场分量不等于两个端口。恢复Jones须两份独立已知激励：J=F/A。

    files = string(field_or(cfg, 'files', field_or(cfg, 'file', '')));
    files = files(:);
    if isempty(files) || any(strlength(files) == 0) || numel(files) > 2
        error('rtsim:pattern:Files', '须提供一或两份远场文件。');
    end

    fields = [];
    hashes = cell(numel(files), 1);
    gainError = zeros(numel(files), 1);
    for k = 1:numel(files)
        if ~isfile(files(k))
            error('rtsim:pattern:MissingFile', '文件不存在：%s', files(k));
        end

        data = readmatrix(files(k), 'FileType', 'text', 'NumHeaderLines', 2);
        if size(data, 2) ~= 8 || isempty(data) || any(~isfinite(data), 'all')
            error('rtsim:pattern:InvalidData', '远场须为有限值的8列数值。');
        end

        theta = unique(data(:, 1));
        phi = unique(mod(data(:, 2), 360));
        if theta(1) ~= 0 || theta(end) ~= 180 || phi(1) ~= 0 || ...
                numel(theta) < 2 || numel(phi) < 2 || ...
                max(abs(diff(theta) - 180 / (numel(theta) - 1))) > 1e-8 || ...
                max(abs(diff(phi) - 360 / numel(phi))) > 1e-8
            error('rtsim:pattern:Grid', '要求含双极点及完整360度周期的规则球面网格。');
        end

        [~, ti] = ismember(data(:, 1), theta);
        [~, pi] = ismember(mod(data(:, 2), 360), phi);
        index = sub2ind([numel(theta) numel(phi)], ti, pi);
        if numel(unique(index)) ~= numel(index)
            error('rtsim:pattern:DuplicateGrid', '存在重复网格点，包括0/360重复接缝。');
        end

        if numel(index) ~= numel(theta) * numel(phi)
            error('rtsim:pattern:MissingGrid', '远场网格有缺点。');
        end

        f = complex(zeros(numel(theta), numel(phi), 2));
        for c = 1:2
            component = complex(zeros(numel(theta), numel(phi)));
            component(index) = 10.^(data(:, 2 * c + 2) / 20) .* exp(1j * deg2rad(data(:, 2 * c + 3)));
            f(:, :, c) = component;
        end

        if k > 1 && (~isequal(theta, pattern.theta_deg) || ~isequal(phi, pattern.phi_deg))
            error('rtsim:pattern:GridMismatch', '两个激励须使用相同角网格。');
        end

        fields(:, :, :, k) = f; %#ok<AGROW>
        gainError(k) = max(abs(10 * log10(10.^(data(:, 4) / 10) + 10.^(data(:, 6) / 10)) - data(:, 3)));
        fid = fopen(files(k), 'rb');
        cleaner = onCleanup(@() fclose(fid));
        bytes = fread(fid, Inf, '*uint8');
        clear cleaner;
        md = java.security.MessageDigest.getInstance('SHA-256');
        md.update(bytes);
        hashes{k} = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2).', 1, []));
        pattern.theta_deg = theta;
        pattern.phi_deg = phi;
    end

    fullJones = numel(files) == 2;
    if fullJones
        A = field_or(cfg, 'excitation_matrix', []);
        if ~isequal(size(A), [2 2]) || any(~isfinite(A), 'all') || rcond(A) < 1e-8
            error('rtsim:pattern:ExcitationMatrix', '两份文件须提供线性独立的已知2×2复激励矩阵。');
        end

        flat = reshape(permute(fields, [3 4 1 2]), 2, 2, []);
        for k = 1:size(flat, 3)
            flat(:, :, k) = flat(:, :, k) / A;
        end

        fields = permute(reshape(flat, 2, 2, numel(theta), numel(phi)), [3 4 1 2]);
    end

    pattern.kind = 'CST_FARFIELD';
    pattern.field_samples = fields;
    pattern.source_file = cellstr(files);
    pattern.source_sha256 = hashes;
    pattern.frequency_Hz = field_or(cfg, 'frequency_Hz', NaN);
    if ~isscalar(pattern.frequency_Hz) || ~(isnan(pattern.frequency_Hz) || ...
            (isfinite(pattern.frequency_Hz) && pattern.frequency_Hz > 0))
        error('rtsim:pattern:Frequency', '源频率须为正标量或未知NaN。');
    end

    pattern.excited_port = field_or(cfg, 'excited_port', 'UNKNOWN');
    pattern.excitation_matrix = field_or(cfg, 'excitation_matrix', []);
    pattern.basis = upper(string(field_or(cfg, 'basis', 'UNKNOWN')));
    pattern.metadata_verified = logical(field_or(cfg, 'metadata_verified', false));
    pattern.mode = upper(string(field_or(cfg, 'mode', 'PARSE_ONLY')));
    pattern.has_phase = true;
    pattern.has_full_jones = fullJones;
    pattern.az_range_deg = [-180 180];
    pattern.el_range_deg = [-90 90];
    pattern.freq_range_Hz = [pattern.frequency_Hz pattern.frequency_Hz];
    pattern.far_field_min_m = field_or(cfg, 'far_field_min_m', 0);
    pattern.quality_label = 'UNVERIFIED_EXCITATION_MODE';
    pattern.gain_consistency_max_dB = gainError;
    pattern.gain_precision_note = 'Finite printed component/total dBi precision; no renormalization applied.';
    pattern.pole_policy = 'Keep basis components at both poles; do not average phase or invent an unknown basis.';
    pattern.pole_check = pole_check(pattern);
    pattern.full_polarization_qualified = fullJones && pattern.metadata_verified && ...
        isfinite(pattern.frequency_Hz) && any(pattern.basis == ["THETA_PHI", "LUDWIG3", "PROJECTED_YZ"]);
    if pattern.full_polarization_qualified
        pattern.quality_label = 'FULL_JONES_METADATA_VERIFIED';
    end
end

function v = field_or(s, n, d)
    if isfield(s, n)
        v = s.(n);
    else
        v = d;
    end
end

function result = pole_check(p)
    % 极点各phi代表同一个物理方向；只有已知基才能比较其笛卡尔电场。

    result = struct('evaluated', false, 'north_relative_spread', NaN, 'south_relative_spread', NaN);
    if ~any(p.basis == ["LUDWIG3", "THETA_PHI"])
        return
    end

    result.evaluated = true;
    spread = zeros(1, 2);
    for pole = 1:2
        ti = 1 + (pole - 1) * (numel(p.theta_deg) - 1);
        theta = p.theta_deg(ti);
        xyz = complex(zeros(3, numel(p.phi_deg), size(p.field_samples, 4)));
        for k = 1:numel(p.phi_deg)
            phi = p.phi_deg(k);
            et = [cosd(theta) * cosd(phi); cosd(theta) * sind(phi); -sind(theta)];
            ep = [-sind(phi); cosd(phi); 0];
            B = [et ep];
            if p.basis == "LUDWIG3"
                B = B * [cosd(phi) sind(phi); -sind(phi) cosd(phi)];
            end

            xyz(:, k, :) = reshape(B * reshape(p.field_samples(ti, k, :, :), 2, []), 3, 1, []);
        end

        delta = xyz - mean(xyz, 2);
        spread(pole) = max(abs(delta), [], 'all') / max(max(abs(xyz), [], 'all'), eps);
    end

    result.north_relative_spread = spread(1);
    result.south_relative_spread = spread(2);
    result.tolerance_note = 'Diagnostic only: source phase origin and basis still require independent confirmation.';
end
