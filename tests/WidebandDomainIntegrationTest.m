classdef WidebandDomainIntegrationTest < matlab.unittest.TestCase
    % 主链必须拒绝未覆盖的频移、采样率及物理网络尾长。

    methods (Test)

        function shiftedTransmitBandIsRejected(testCase)
            cfg = local_config();
            cfg.target.doppler_Hz = 1e6;
            testCase.verifyError(@()rtsim.sim.simulate_case(cfg, 'DOMAIN', []), ...
                'rtsim:calibration:OutOfDomain');
            cfg.target.doppler_Hz = -1e6;
            testCase.verifyError(@()rtsim.sim.simulate_case(cfg, 'DOMAIN', []), ...
                'rtsim:calibration:OutOfDomain');
        end

        function undeclaredPhysicalTailIsRejected(testCase)
            cfg = local_config();
            cfg.calibration.wideband.tx_plant_coeff(5, 1, 1) = 0.01;
            testCase.verifyError(@()rtsim.sim.simulate_case(cfg, 'DOMAIN', []), 'rtsim:WidebandRfTail');
        end

        function mismatchedCoefficientRateIsRejected(testCase)
            cfg = local_config();
            cfg.calibration.wideband.tx.sample_rate_hz = 62.5e6;
            testCase.verifyError(@()rtsim.sim.simulate_case(cfg, 'DOMAIN', []), 'rtsim:WidebandSampleRate');
        end

    end
end

function cfg = local_config()
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    cfg = rtsim.config.default_config('ALGORITHM_SMOKE');
    cfg.output.save = false;
    cfg.sim.duration_s = 200e-6;
    cfg.radar.pulse_count = 1;
    cfg.radar.bandwidth_Hz = 5e6;
    coeff = reshape(eye(2), 1, 2, 2);
    domain = struct('range_index', 1:3, 'temperature_c', [25 25], ...
        'power_dbm', [-30 -30], 'frequency_hz', [-2.5e6 2.5e6]);
    cal = struct('coeff', coeff, 'latency_samples', 0, 'sample_rate_hz', cfg.pl.output_fs_Hz, ...
        'domain', domain, 'qualification', 'SYNTHETIC');
    cfg.calibration.wideband = struct('enabled', true, 'rx', cal, 'tx', cal, ...
        'rx_plant_coeff', coeff, 'tx_plant_coeff', coeff, ...
        'operating_power_dbm', -30, 'tx_range_index', 2);
end
