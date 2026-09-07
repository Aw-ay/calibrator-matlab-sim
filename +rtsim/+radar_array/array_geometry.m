function positions_m = array_geometry(array_size, spacing_m)
    % 阵面YZ，+X正视；坐标为ENU列向量约定的逐阵元行存储。

    validateattributes(array_size, {'numeric'}, {'vector', 'numel', 2, 'integer', 'positive'});
    validateattributes(spacing_m, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    [y, z] = ndgrid((0:array_size(1) - 1) - (array_size(1) - 1) / 2, ...
        (0:array_size(2) - 1) - (array_size(2) - 1) / 2);
    positions_m = [zeros(numel(y), 1), y(:) * spacing_m, z(:) * spacing_m];
end
