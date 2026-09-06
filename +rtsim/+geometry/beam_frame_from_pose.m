function frame = beam_frame_from_pose(qBodyToENU, mountRotation, beamCommand)
%BEAM_FRAME_FROM_POSE 由完整姿态、安装矩阵和波束命令构造天线坐标架。
validateattributes(qBodyToENU, {'numeric'}, {'real','finite','numel',4});
validateattributes(mountRotation, {'numeric'}, {'real','finite','size',[3,3]});
if norm(mountRotation'*mountRotation-eye(3),'fro') > 1e-9 || det(mountRotation) < 0
    error('rtsim:geometry:InvalidRotation', '安装矩阵必须是右手正交旋转矩阵。');
end
q = qBodyToENU(:).' / norm(qBodyToENU);
w=q(1); x=q(2); y=q(3); z=q(4);
Rbody = [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w); ...
    2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w); ...
    2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)];
Rmount = Rbody * mountRotation;
validateattributes(beamCommand, {'numeric'}, {'real','finite'});
if numel(beamCommand) == 3
    target = Rmount * (beamCommand(:)/norm(beamCommand));
    zAxis = target;
    xTrial = Rmount(:,1) - zAxis*dot(zAxis,Rmount(:,1));
    if norm(xTrial) < 1e-12
        xTrial = Rmount(:,2) - zAxis*dot(zAxis,Rmount(:,2));
    end
    xAxis = xTrial/norm(xTrial); yAxis = cross(zAxis,xAxis);
    Rantenna = [xAxis,yAxis,zAxis];
elseif numel(beamCommand) == 2
    az = beamCommand(1); el = beamCommand(2);
    local = [cosd(el)*sind(az); cosd(el)*cosd(az); sind(el)];
    zAxis = Rmount*local; xTrial = Rmount(:,1)-zAxis*dot(zAxis,Rmount(:,1));
    xAxis=xTrial/norm(xTrial); yAxis=cross(zAxis,xAxis); Rantenna=[xAxis,yAxis,zAxis];
else
    error('rtsim:geometry:BeamCommand', '波束命令须为局部3维方向或[方位,仰角]。');
end
frame = struct('R_body_to_enu',Rbody,'R_mount_to_enu',Rmount, ...
    'R_antenna_to_enu',Rantenna,'boresight_enu',Rantenna(:,3), ...
    'is_right_handed',det(Rantenna)>0);
end
