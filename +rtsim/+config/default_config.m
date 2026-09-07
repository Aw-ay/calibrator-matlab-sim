function cfg = default_config(profile)
    % 正式系统等效采样配置；器件资源和模拟非理想仍是行为级假设。

    if nargin == 0
        profile = 'RFSoC_SYSTEM_EQUIVALENT';
    end

    cfg.schema_version = '2.0';

    cfg.seed = 20260906;

    cfg.fidelity = 'ENVELOPE';

    cfg.profile = upper(char(profile));

    cfg.sampling_profile = cfg.profile;

    cfg.constants.c_mps = 299792458;

    cfg.time.f_gsc_Hz = 500e6;

    cfg.radar.fc_Hz = 2.8e9;
    cfg.radar.Ptx_W = 1;
    cfg.radar.bandwidth_Hz = 1e6;
    cfg.radar.pulse_width_s = 10e-6;
    cfg.radar.pri_s = 1e-3;
    cfg.radar.pulse_count = 4;
    cfg.radar.start_s = 20e-6;
    cfg.radar.kind = 'LFM';
    cfg.radar.polarization = [1; 1] / sqrt(2);
    cfg.radar.noise_power_W = 0;
    cfg.radar.response_matrix = eye(2);
    cfg.radar.receive_gate_m = [500, 60000];

    cfg.target.range_m = 20000;
    cfg.target.gain = 100;
    cfg.target.doppler_Hz = 0;
    cfg.target.polar_matrix = eye(2);
    cfg.target.phase0_rad = 0;
    cfg.target.phase_policy = 'INDEPENDENT_DOPPLER';
    cfg.target.reference_plane = 'RP2_OTA';

    % 物理方向图与控制器名义标定模型分开，控制器不能读取真实方向图。

    cfg.antenna.pattern = struct('kind', 'IDEAL');
    cfg.antenna.calibration_pattern = struct('kind', 'IDEAL');
    cfg.antenna.mounting = struct('roll_offset_deg', 0, 'pitch_offset_deg', 0, ...
        'yaw_offset_deg', 0, 'phase_center_ant_m', [0; 0; 0]);
    cfg.antenna.lever_arm_body_m = [0; 0; 0];
    cfg.antenna.vibration = struct('roll_deg', 0);
    cfg.antenna.excitation_mode_only = false;
    cfg.antenna.max_inverse_gain = 100;

    cfg.radar.array = rtsim.radar_array.default_array_config(cfg.radar.fc_Hz, [1 1]);

    cfg.replay.interpolation_method = 'LINEAR';
    cfg.replay.interpolation_order = 7;

    cfg.calibration.wideband.enabled = false;

    cfg.instrument.mode = 'DRFM';
    cfg.instrument.half_duplex = true;
    cfg.instrument.source_start_s = 150e-6;
    cfg.instrument.isolated_ports = false;
    cfg.instrument.physical_loopback = false;
    cfg.instrument.fixed_latency_s = 1e-6;
    cfg.instrument.tx_rf_tail_bound_samples = 0;
    cfg.instrument.ranges.gains = [1e5, 1e4, 1e3];
    cfg.instrument.ranges.response = repmat([1, 0.005; 0.003, 0.98 * exp(0.04i)], 1, 1, 3);
    cfg.instrument.ranges.noise_power_W = 0;
    cfg.instrument.common.gain = 1;
    cfg.instrument.common.noise_power_W = 0;
    cfg.instrument.common.saturation_amplitude = 0.1;
    cfg.instrument.adc.bits = 12;
    cfg.instrument.adc.full_scale = 1;
    cfg.instrument.tx_response = [1.02, 0.004i; 0.002, 0.97 * exp(-0.03i)];
    cfg.instrument.tx_limit = 0.5;
    cfg.instrument.adc.enabled = true;
    cfg.instrument.dac = struct('bits', 16, 'full_scale', 0.01, 'nco_frequency_Hz', 0, 'phase0_rad', 0, 'valid', ...
        true, 'safe_value', 0);
    cfg.capture.threshold_W = 1e-13;
    cfg.capture.end_hold_s = 1e-6;
    cfg.capture.pretrigger_s = 2e-6;
    cfg.capture.posttrigger_s = 2e-6;
    cfg.capture.max_pulse_s = 120e-6;
    cfg.capture.bank_capacity_samples = 8192;
    cfg.capture.range_select_s = 16e-9;
    cfg.capture.rx_calibration_s = 16e-9;
    cfg.capture.bank_prepare_s = 16e-9;
    cfg.capture.bank_count = 8;
    cfg.capture.range_limit = 0.9;

    cfg.dataflow.dma_bytes_per_s = 200e6;
    cfg.dataflow.storage_bytes_per_s = 100e6;
    cfg.dataflow.radio_bytes_per_s = 1e6;
    cfg.dataflow.storage_capacity_bytes = 1e9;
    cfg.dataflow.pdw_capacity = 1024;

    cfg.channel.kind = 'OTA';
    cfg.channel.fc_Hz = cfg.radar.fc_Hz;
    cfg.channel.fs_Hz = 62.5e6;
    cfg.channel.cable_gain = 1e-5;
    cfg.channel.cable_delay_s = 0;
    cfg.channel.reflection = struct('enabled', false, 'coefficient', -0.3, 'height_m', 0);

    cfg.platform.position_m = [2000; 0; 0];
    cfg.platform.velocity_mps = [0; 0; 0];
    cfg.platform.acceleration_mps2 = [0; 0; 0];
    cfg.platform.roll_deg = 0;
    cfg.platform.roll_rate_dps = 0;
    cfg.platform.pitch_deg = 0;
    cfg.platform.yaw_deg = 0;
    cfg.platform.pitch_rate_dps = 0;
    cfg.platform.yaw_rate_dps = 0;

    cfg.navigation.delay_s = 0;
    cfg.navigation.position_bias_m = zeros(3, 1);
    cfg.navigation.velocity_bias_mps = zeros(3, 1);
    cfg.navigation.roll_bias_deg = 0;
    cfg.navigation.noise_std_m = 0;
    cfg.navigation.available = true;
    cfg.navigation.initial_position_m = [2000; 0; 0];

    cfg.environment.temperature_C = 25;
    cfg.environment.ambient_C = 25;
    cfg.environment.thermal_tau_s = 0.1;
    cfg.environment.voltage_V = 12;
    cfg.environment.gain_temp_dB_per_C = 0.01;
    cfg.environment.emc_amplitude = 0;
    cfg.environment.emc_frequency_Hz = 0.2e6;
    cfg.environment.body_rcs_m2 = 0;

    cfg.safety.pll_locked = true;
    cfg.safety.max_temperature_C = 85;
    cfg.safety.min_voltage_V = 10;
    cfg.safety.guard_s = 1e-6;

    cfg.calibration.noise_std = 1e-7;
    cfg.calibration.bias_std = 1e-5;

    cfg.sim.block_size = 512;
    cfg.sim.duration_s = 3.5e-3;
    cfg.sim.max_samples = 2e6;

    cfg.output.save = true;
    cfg.output.root = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'results');

    cfg.options.frequency_channels = false;
    cfg.options.weather = false;
    cfg.options.nearfield = false;
    cfg.options.dpd = false;

    cfg.acceptance.range_tolerance_m = 30;

    cfg.rf.fc_Hz = 2.8e9;

    cfg.baseband.usable_bandwidth_Hz = 20e6;

    cfg.adc.fs_real_Hz = 4e9;

    cfg.rfdc.output_fs_Hz = 500e6;
    cfg.rfdc.samples_per_clock = 8;
    cfg.rfdc.interface_clock_Hz = 62.5e6;

    cfg.pl.decimation = 8;
    cfg.pl.output_fs_Hz = 62.5e6;
    cfg.pl.output_samples_per_clock = 1;
    switch cfg.sampling_profile
        case 'ALGORITHM_SMOKE'
            cfg.rfdc.output_fs_Hz = 20e6;
            cfg.rfdc.samples_per_clock = 1;
            cfg.rfdc.interface_clock_Hz = 20e6;

            cfg.pl.decimation = 1;
            cfg.pl.output_fs_Hz = 20e6;

            cfg.baseband.usable_bandwidth_Hz = 5e6;

            cfg.capture.bank_capacity_samples = 2048;
            cfg.capture.max_pulse_s = 80e-6;
        case 'RFSOC_SYSTEM_EQUIVALENT'
        otherwise
            error('rtsim:SamplingProfile', '未知采样档：%s', profile);
    end

    cfg = rtsim.config.derive_config(cfg);
    cfg.reference_planes = {'RP1_RX', 'ADC_RAW', 'PL_FILTERED_RAW', 'RP1_TX', 'RP2_OTA', 'RADAR_RX'};
end
