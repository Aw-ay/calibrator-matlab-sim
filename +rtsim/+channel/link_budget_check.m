function report = link_budget_check(caseCfg, measuredPortPowers, channelDiag)
%LINK_BUDGET_CHECK 以独立标量Friis公式核对单程端口功率。
c=299792458; lambda=c/caseCfg.fc_Hz;
expected=caseCfg.tx_power_W*caseCfg.tx_gain_linear*caseCfg.rx_gain_linear* ...
    (lambda/(4*pi*caseCfg.range_m))^2;
measured=measuredPortPowers.rx_power_W;
report=struct('expected_rx_power_W',expected,'measured_rx_power_W',measured, ...
    'error_dB',10*log10(measured/expected),'pass',abs(10*log10(measured/expected))<=caseCfg.tolerance_dB, ...
    'path_count',channelDiag.path_count);
end
