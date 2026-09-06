function operator = build_polarization_operator(targetSpec,antennaEstimate,~)
% 定义 e_rx→Jrx→端口→K→Jtx→e_tx，故 K=逆Jtx*S*逆Jrx。
constraints=struct('lambda',targetSpec.lambda,'max_gain',targetSpec.max_gain);
a=rtsim.calibration.solve_regularized_inverse(antennaEstimate.Jtx,constraints);
b=rtsim.calibration.solve_regularized_inverse(antennaEstimate.Jrx,constraints);
operator.matrix=a.matrix*targetSpec.matrix*b.matrix;
operator.condition_number=[cond(antennaEstimate.Jtx),cond(antennaEstimate.Jrx)];
operator.limited=a.gain_limited || b.gain_limited;
operator.scope='确定性 Jones 映射，不生成任意随机相关系数';
end
