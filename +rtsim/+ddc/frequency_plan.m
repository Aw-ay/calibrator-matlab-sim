function plan = frequency_plan(cfgRf, cfgRfdc, capabilities)
%FREQUENCY_PLAN 校验并回显完全显式的频率规划。
arguments
    cfgRf struct
    cfgRfdc struct
    capabilities struct
end
rfFields = {'rf_Hz','if_Hz'};
rfdcFields = {'adc_real_fs_Hz','ddc_Hz','pl_fs_Hz','record_fs_Hz','dac_real_fs_Hz','mixer_sign','decimation'};
if ~all(isfield(cfgRf, rfFields)) || ~all(isfield(cfgRfdc, rfdcFields))
    error('rtsim:ddc:IncompleteFrequencyPlan', '必须明确 RF、IF、ADC/DDC、PL、记录、DAC、混频符号和抽取倍率。');
end
if ~isfield(capabilities, 'supported_adc_rates_Hz') || ...
        ~any(cfgRfdc.adc_real_fs_Hz == capabilities.supported_adc_rates_Hz)
    error('rtsim:ddc:UnsupportedFrequencyPlan', 'ADC 采样率不在已声明能力范围内。');
end
assert(cfgRfdc.mixer_sign == -1 || cfgRfdc.mixer_sign == 1, ...
    'rtsim:ddc:UnsupportedFrequencyPlan', 'mixer_sign 只能为 -1 或 +1。');
assert(cfgRfdc.decimation >= 1 && cfgRfdc.decimation == fix(cfgRfdc.decimation), ...
    'rtsim:ddc:UnsupportedFrequencyPlan', 'decimation 必须为正整数。');
plan = struct('rf_Hz', cfgRf.rf_Hz, 'if_Hz', cfgRf.if_Hz, ...
    'adc_real_fs_Hz', cfgRfdc.adc_real_fs_Hz, 'ddc_Hz', cfgRfdc.ddc_Hz, ...
    'pl_fs_Hz', cfgRfdc.pl_fs_Hz, 'record_fs_Hz', cfgRfdc.record_fs_Hz, ...
    'dac_real_fs_Hz', cfgRfdc.dac_real_fs_Hz, 'mixer_sign', cfgRfdc.mixer_sign, ...
    'decimation', cfgRfdc.decimation, 'provenance', "EXPLICIT_CONFIGURATION_ONLY");
end
