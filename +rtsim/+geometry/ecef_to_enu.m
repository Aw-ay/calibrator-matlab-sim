function enu_m = ecef_to_enu(ecef_m, stationEcef_m, R_station)
%ECEF_TO_ENU 用同一个站点基准将ECEF点转换为局部ENU。
validateattributes(ecef_m, {'numeric'}, {'real','finite','nrows',3});
validateattributes(stationEcef_m, {'numeric'}, {'real','finite','numel',3});
validateattributes(R_station, {'numeric'}, {'real','finite','size',[3,3]});
enu_m = R_station * (ecef_m - stationEcef_m(:));
end
