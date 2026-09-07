function B = field_basis(direction, kind)
    % FIELD_BASIS 返回3×2实横向单位基。方向是从天线向外的ANT/ENU列向量。
    % LUDWIG3: H=e_theta*cos(phi)-e_phi*sin(phi), V=e_theta*sin(phi)+e_phi*cos(phi)。

    d = direction(:) / norm(direction);
    switch upper(string(kind))
        case 'PROJECTED_YZ'
            h = [0; 1; 0] - d * d(2);
            if norm(h) < 1e-10
                h = [1; 0; 0] - d * d(1);
            end

            h = h / norm(h);
            v = cross(d, h);

            % 无向直线采用规范半球，双程公共H/V基不因传播方向取反而翻号。

            [~, i] = max(abs(d));
            if d(i) < 0
                v = -v;
            end

            B = [h v];
        case {'THETA_PHI', 'LUDWIG3'}
            phi = atan2d(d(2), d(1));
            theta = acosd(max(-1, min(1, d(3))));
            et = [cosd(theta) * cosd(phi); cosd(theta) * sind(phi); -sind(theta)];
            ep = [-sind(phi); cosd(phi); 0];
            B = [et ep];
            if upper(string(kind)) == "LUDWIG3"
                B = B * [cosd(phi) sind(phi); -sind(phi) cosd(phi)];
            end

        otherwise
            error('rtsim:pattern:UnknownBasis', '场基须明确为THETA_PHI、LUDWIG3或PROJECTED_YZ。');
    end
end
