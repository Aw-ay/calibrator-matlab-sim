function q = rotation_to_quaternion(R)
    % ROTATION_TO_QUATERNION 主动旋转的标量在前单位四元数，无工具箱依赖。

    t = trace(R);
    if t > 0
        s = 2 * sqrt(1 + t);
        q = [s / 4 (R(3, 2) - R(2, 3)) / s (R(1, 3) - R(3, 1)) / s (R(2, 1) - R(1, 2)) / s];
    else
        [~, i] = max(diag(R));
        j = mod(i, 3) + 1;
        k = mod(j, 3) + 1;
        s = 2 * sqrt(max(0, 1 + R(i, i) - R(j, j) - R(k, k)));
        v = zeros(1, 3);
        v(i) = s / 4;
        v(j) = (R(j, i) + R(i, j)) / s;
        v(k) = (R(k, i) + R(i, k)) / s;
        q = [(R(k, j) - R(j, k)) / s v];
    end

    q = q / norm(q);
    if q(1) < 0
        q = -q;
    end
end
