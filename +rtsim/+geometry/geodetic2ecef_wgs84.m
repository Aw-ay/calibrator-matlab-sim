function [ecef_m, R_ECEF_to_ENU] = geodetic2ecef_wgs84(lat_deg, lon_deg, h_ellip_m)
%GEODETIC2ECEF_WGS84 将WGS-84大地坐标转换为ECEF坐标。
% 输入允许标量或等尺寸数组，输出采用3×N列向量约定。
validateattributes(lat_deg, {'numeric'}, {'real','finite'});
validateattributes(lon_deg, {'numeric'}, {'real','finite'});
validateattributes(h_ellip_m, {'numeric'}, {'real','finite'});
if ~isequal(size(lat_deg), size(lon_deg), size(h_ellip_m))
    error('rtsim:geometry:SizeMismatch', '纬度、经度和椭球高必须同尺寸。');
end
if any(abs(lat_deg(:)) > 90) || any(abs(lon_deg(:)) > 180)
    error('rtsim:geometry:AngleRange', '纬度须在[-90,90]，经度须在[-180,180]度。');
end
a = 6378137;
f = 1 / 298.257223563;
e2 = f * (2-f);
lat = deg2rad(lat_deg(:).');
lon = deg2rad(lon_deg(:).');
h = h_ellip_m(:).';
N = a ./ sqrt(1 - e2 .* sin(lat).^2);
ecef_m = [(N+h).*cos(lat).*cos(lon); (N+h).*cos(lat).*sin(lon); (N.*(1-e2)+h).*sin(lat)];
R_ECEF_to_ENU = zeros(3,3,numel(lat));
for k = 1:numel(lat)
    R_ECEF_to_ENU(:,:,k) = [-sin(lon(k)), cos(lon(k)), 0; ...
        -sin(lat(k))*cos(lon(k)), -sin(lat(k))*sin(lon(k)), cos(lat(k)); ...
        cos(lat(k))*cos(lon(k)), cos(lat(k))*sin(lon(k)), sin(lat(k))];
end
if isscalar(lat)
    R_ECEF_to_ENU = R_ECEF_to_ENU(:,:,1);
end
end
