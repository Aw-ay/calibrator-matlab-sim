function report = validate_config(cfg, capabilities)
% 只接受已实现的复包络模式；不把演示采样率当实 ADC 配置。
if nargin < 2, capabilities = []; end
assert(strcmp(cfg.fidelity,'ENVELOPE'),'rtsim:UnsupportedFidelity','当前闭环仅支持 ENVELOPE。');
fs=cfg.rates.fs_record_Hz;
validateattributes(fs,{'numeric'},{'scalar','finite','positive'});
validateattributes(cfg.sim.block_size,{'numeric'},{'scalar','integer','positive'});
validateattributes(cfg.radar.pulse_count,{'numeric'},{'scalar','integer','positive'});
assert(cfg.radar.pulse_width_s>0 && cfg.radar.pulse_width_s<=cfg.radar.pri_s,'rtsim:PulseTiming','脉宽必须大于零且不超过 PRI。');
assert(cfg.radar.bandwidth_Hz>0 && cfg.radar.bandwidth_Hz<0.4*fs,'rtsim:Bandwidth','带宽必须满足演示插值模型的带宽裕量。');
assert(ismember(cfg.instrument.mode,{'MUTE','LIVE','DRFM','DDS','AWG'}),'rtsim:Mode','信号源模式不支持。');
if strcmp(cfg.instrument.mode,'LIVE')
    assert((strcmp(cfg.channel.kind,'CABLE') || cfg.instrument.isolated_ports) && ~cfg.instrument.physical_loopback,'rtsim:UnsafeLive','LIVE 仅允许电缆或隔离端口，且禁止物理正反馈回环。');
end
assert(all(isfinite(cfg.platform.position_m)) && norm(cfg.platform.position_m)>0,'rtsim:Position','物理距离必须为正。');
assert(cfg.target.range_m>0 && isfinite(cfg.target.range_m),'rtsim:Target','目标距离必须为正。');
assert(isequal(size(cfg.target.polar_matrix),[2,2]),'rtsim:Polarization','目标极化矩阵必须为 2×2。');
assert(cfg.capture.bank_count>=1 && cfg.capture.max_samples>=ceil(cfg.radar.pulse_width_s*fs)+cfg.capture.pretrigger_samples+cfg.capture.end_hold_samples,'rtsim:Capacity','捕获容量不足。');
assert(cfg.sim.duration_s*fs<=cfg.sim.max_samples,'rtsim:MemoryLimit','记录长度超过内存保护上限，请缩短窗口。');
assert(~any(structfun(@(x) logical(x),cfg.options)),'rtsim:OptionalDisabled','未确认扩展不能直接开启。');
assert(strcmp(cfg.target.phase_policy,'INDEPENDENT_DOPPLER'),'rtsim:PhasePolicy','当前仅实现明确标注的独立多普勒体制。');
assert(cfg.dataflow.dma_bytes_per_s>=0,'rtsim:Service','服务率不能为负。');
validateattributes(cfg.capture.bank_count,{'numeric'},{'scalar','integer','positive'});
validateattributes(cfg.instrument.source_start_s,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(cfg.channel.cable_gain,{'numeric'},{'scalar','finite'});
validateattributes(cfg.channel.cable_delay_s,{'numeric'},{'scalar','finite','real','nonnegative'});
assert(ismember(cfg.channel.kind,{'OTA','CABLE'}),'rtsim:Channel','信道仅支持 OTA/CABLE。');
assert(cfg.instrument.tx_limit>0 && isfinite(cfg.instrument.tx_limit),'rtsim:TxLimit','发射限幅必须为有限正值。');
if strcmp(cfg.instrument.mode,'AWG')
    assert(isfield(cfg.instrument,'awg_table') && size(cfg.instrument.awg_table,2)==2 && all(isfinite(cfg.instrument.awg_table(:))),'rtsim:AWGData','AWG 需要有限 N×2 模板。');
end
report=struct('status','PASS','scope','复包络配置检查','capabilities',capabilities);
end
