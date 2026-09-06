function R = lookat_R(b)
%LOOKAT_R 生成右手正交坐标架，使第三轴指向b。
validateattributes(b, {'numeric'}, {'real','finite','numel',3});
z = b(:) / norm(b);
if ~all(isfinite(z))
    error('rtsim:geometry:ZeroDirection', '观察方向不能为零向量。');
end
reference = [0;0;1];
if abs(dot(z,reference)) > 0.95
    reference = [0;1;0];
end
x = cross(reference,z); x = x / norm(x);
y = cross(z,x);
R = [x,y,z];
end
