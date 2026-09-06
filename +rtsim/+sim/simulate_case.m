function result = simulate_case(cfg,worldProvider,observationProvider)
% 复包络全链路主控：真实传播与仪器估计边界分离。
% 可传入 worldProvider(t) 与 observationProvider(t)；两者不互相接收结构。
% 默认 A/B 采用规定轨迹与延迟传感器，连续飞行按短块冻结几何近似。
if nargin<3, observationProvider=[]; end
rtsim.config.validate_config(cfg,[]);
originalRng=rng; cleanup=onCleanup(@() rng(originalRng));
rng(cfg.seed,'twister'); fs=cfg.rates.fs_record_Hz;
count=ceil(cfg.sim.duration_s*fs); c=cfg.constants.c_mps;
result.config=cfg;
if isa(worldProvider,'function_handle'), result.stage='CUSTOM'; else, result.stage=char(worldProvider); end
result.audit=rtsim.config.audit_inputs(fileparts(fileparts(fileparts(mfilename('fullpath')))),cfg);
% 校准实验使用独立标准源及独立随机会话，拟合器不接收真实矩阵。
plant.rx_response=cfg.instrument.ranges.response;
for r=1:3, plant.rx_response(:,:,r)=plant.rx_response(:,:,r)*cfg.instrument.ranges.gains(r)*cfg.instrument.common.gain; end
plant.tx_response=cfg.instrument.tx_response;
excitation=repmat([1,0;0,1;1,1;1,1i],16,1);
tasks=struct('rx_inputs',excitation,'tx_inputs',excitation);
measurements=rtsim.calibration.simulate_calibration_session(plant,cfg.calibration,tasks,cfg.seed+1);
fit=struct('lambda',1e-12,'max_gain',1e3);
calRx=rtsim.calibration.estimate_rx_cal(measurements,struct(),fit);
calTx=rtsim.calibration.estimate_tx_cal(measurements,struct(),fit);
holdout=rtsim.calibration.simulate_calibration_session(plant,cfg.calibration,tasks,cfg.seed+2);
calReport=rtsim.calibration.validate_calibration(struct('rx',calRx,'tx',calTx),holdout,struct('max_rmse',1e-3));
coreCfg=cfg;
% 核心只保留名义量程增益；移除真实串扰/发射链/平台导航模型。
coreCfg.instrument.ranges=rmfield(coreCfg.instrument.ranges,'response');
coreCfg.instrument=rmfield(coreCfg.instrument,'tx_response');
coreCfg=rmfield(coreCfg,{'platform','navigation','environment'});
st=rtsim.sim.init_state(cfg); forward=struct(); backward=struct(); source=struct();
rxst=struct('seed',cfg.seed+10); rangest=struct('seed',cfg.seed+11); adcst=struct(); bodyst=struct(); navst=struct();
radarState=struct('seed',cfg.seed+12); dacState=struct(); txState=struct(); ddcState=struct();
sensorState=struct('seed',cfg.seed+13);
result.radar_tx=complex(zeros(count,2)); result.port_rx=result.radar_tx;
result.tx_iq=result.radar_tx; result.radar_iq=result.radar_tx;
trajectoryLog=zeros(ceil(count/cfg.sim.block_size),9); bindex=0;
temperature=cfg.environment.temperature_C;
for first=1:cfg.sim.block_size:count
    n=min(cfg.sim.block_size,count-first+1); index0=first-1;
    grid=struct('index0',index0,'fs_Hz',fs,'count',n,'gsc0',uint64(index0*cfg.time.f_gsc_Hz/fs), ...
        'fraction0_ticks',0,'step_num',cfg.time.f_gsc_Hz/fs,'step_den',1, ...
        'f_gsc_Hz',cfg.time.f_gsc_Hz,'epoch_id','LOCAL','clock_id','NOMINAL');
    t=index0/fs;
    [truth,~]=rtsim.airborne.platform_truth_step(struct(),cfg.platform,struct('roll_amplitude_deg',0,'frequency_Hz',0,'phase_rad',0),grid);
    if isa(worldProvider,'function_handle'), truth=worldProvider(t); end
    % 生成已经延迟到达的观测：仅取 t-delay 的状态，外推使用观测速度。
    sensorGrid=grid; sensorGrid.index0=(t-cfg.navigation.delay_s)*fs;
    [pastTruth,~]=rtsim.airborne.platform_truth_step(struct(),cfg.platform,struct('roll_amplitude_deg',0,'frequency_Hz',0,'phase_rad',0),sensorGrid);
    [message,sensorState]=rtsim.airborne.nav_sensor_step(pastTruth,sensorState,cfg.navigation);
    % 合成消息的到达时刻按构造恰为 t，消除减后再加造成的浮点末位差。
    message.available_time_s=t;
    if isa(worldProvider,'function_handle') && isempty(observationProvider)
        error('rtsim:IndependentObservation','自定义物理 provider 必须提供独立观测 provider。');
    end
    if isa(observationProvider,'function_handle'), message=observationProvider(t); end
    navValid=cfg.navigation.available && message.available && message.available_time_s<=t;
    if navValid
        [estimate,navst]=rtsim.airborne.nav_time_aligner(message,struct(),navst,t);
    else
        % 无有效导航时保留名义安全位置，关闭发射而非用真值替代。
        estimate=struct('position_m',cfg.navigation.initial_position_m,'velocity_mps',zeros(3,1),'roll_deg',0);
    end
    R=norm(truth.position_m); estimatedR=norm(estimate.position_m);
    angleTrue=truth.roll_deg*pi/180; angleEstimate=estimate.roll_deg*pi/180;
    J=[cos(angleTrue),sin(angleTrue);-sin(angleTrue),cos(angleTrue)];
    Je=[cos(angleEstimate),sin(angleEstimate);-sin(angleEstimate),cos(angleEstimate)];
    [radarTx,~,source]=rtsim.source.radar_tx_step(source,cfg.radar,grid);
    geometry=struct('tx_position_m',zeros(3,1),'rx_position_m',truth.position_m,'tx_jones',eye(2),'rx_jones',J);
    [port,forward,forwardDiag]=rtsim.channel.channel_step(radarTx,forward,cfg.channel,geometry);
    temperature=cfg.environment.ambient_C+(temperature-cfg.environment.ambient_C)*exp(-n/fs/cfg.environment.thermal_tau_s);
    condition.temperature_C=temperature;
    rfCfg=cfg.instrument.common;
    rfCfg.gain=rfCfg.gain*10^(cfg.environment.gain_temp_dB_per_C*(temperature-25)/20);
    localTime=(index0+(0:n-1)')/fs;
    port=port+cfg.environment.emc_amplitude*exp(1i*2*pi*cfg.environment.emc_frequency_Hz*localTime)*[1,1]/sqrt(2);
    [common,rxst]=rtsim.rx.rx_common_step(port,rxst,rfCfg,condition);
    [ranges,rangest]=rtsim.rx.rx_three_range_step(common,rangest,cfg.instrument.ranges,condition);
    if cfg.instrument.adc.enabled
        [native,adcst]=rtsim.rx.adc_pipeline(ranges,adcst,cfg.instrument.adc,[]);
    else
        native=ranges;
    end
    % 默认基带 DDC 为零频移旁路；原生复 ADC 不做未经定义的额外共轭。
    [native,ddcState]=rtsim.ddc.nco_mixer(native,ddcState,struct('frequency_Hz',0,'phase0_rad',0,'sign',-1),grid);
    control.calRx=calRx; control.calTx=calTx;
    control.pose_estimate=estimate; control.observation_time_s=t;
    control.geometry.roundtrip_delay_s=2*estimatedR/c;
    modeledPhase=-4*pi*estimatedR*cfg.radar.fc_Hz/c;
    modeledDoppler=-2*dot(estimate.position_m,estimate.velocity_mps)/estimatedR*cfg.radar.fc_Hz/c;
    if strcmp(cfg.channel.kind,'CABLE')
        control.geometry.roundtrip_delay_s=2*cfg.channel.cable_delay_s; modeledPhase=0; modeledDoppler=0;
    end
    control.phase=struct('fc_Hz',cfg.radar.fc_Hz,'phase_rad',modeledPhase,'doppler_Hz',modeledDoppler);
    control.polar_operator=Je*cfg.target.polar_matrix*Je.';
    rxStarts=cfg.radar.start_s+(0:cfg.radar.pulse_count-1)*cfg.radar.pri_s+control.geometry.roundtrip_delay_s/2;
    control.rx_windows=[rxStarts(:)-cfg.safety.guard_s,rxStarts(:)+cfg.radar.pulse_width_s+cfg.safety.guard_s];
    control.status=struct('pll_locked',cfg.safety.pll_locked && navValid,'temperature_C',temperature,'voltage_V',cfg.environment.voltage_V);
    [dac,~,~,st]=rtsim.core.instrument_core_step(native,st,coreCfg,control,cfg.dataflow,grid);
    [analog,dacState]=rtsim.tx.duc_dac_step(dac,dacState,cfg.instrument.dac,struct('frequency_error_Hz',0,'fs_Hz',fs));
    rfTx=struct('response_matrix',plant.tx_response,'voltage_gain',1,'saturation_amplitude',cfg.instrument.tx_limit, ...
        'ampm_rad_at_saturation',0,'monitor_coupling',0.01);
    [transmitted,~,txState,txDiagnostic]=rtsim.tx.tx_rf_step(analog,txState,rfTx,struct('gain_scale',1));
    st.diagnostics.tx_clipped_samples=st.diagnostics.tx_clipped_samples+txDiagnostic.clipped_samples;
    geometry.tx_position_m=truth.position_m; geometry.rx_position_m=zeros(3,1);
    geometry.tx_jones=J.'; geometry.rx_jones=eye(2);
    [arriving,backward]=rtsim.channel.channel_step(transmitted,backward,cfg.channel,geometry);
    if cfg.environment.body_rcs_m2>0
        % 被动机体回波独立于仪器发射开关，幅度遵循单站雷达方程。
        lambda=c/cfg.radar.fc_Hz;
        gain=lambda*sqrt(cfg.environment.body_rcs_m2)/((4*pi)^(3/2)*R^2);
        path=struct('delay_s',2*R/c,'matrix',gain*exp(-1i*4*pi*R/lambda)*eye(2));
        [body,bodyst]=rtsim.channel.combine_complex_paths(radarTx,path,bodyst,grid);
        arriving=arriving+body;
    end
    [arriving,radarState]=rtsim.radar.radar_rx_step(arriving,radarState,cfg.radar,grid);
    result.radar_tx(first:first+n-1,:)=radarTx; result.port_rx(first:first+n-1,:)=port;
    result.tx_iq(first:first+n-1,:)=transmitted; result.radar_iq(first:first+n-1,:)=arriving;
    bindex=bindex+1; trajectoryLog(bindex,:)=[t,truth.position_m.',estimate.position_m.',truth.roll_deg,temperature];
end
% 所有雷达端算法只在信号观测上解算；真值仅在最后的评分中使用。
[gates,~,compressionDiag]=rtsim.radar.range_compress_step(result.radar_iq,struct(),cfg.radar,struct('fs_Hz',fs));
pulseTimes=cfg.radar.start_s+(0:cfg.radar.pulse_count-1)*cfg.radar.pri_s;
result.observables=rtsim.radar.radar_observable_estimator(gates,pulseTimes,cfg.radar);
result.range_profile=gates; result.pdw=st.pdw; result.records=st.records;
result.rejections=st.rejections; result.diagnostics=st.diagnostics;
result.platform_log=trajectoryLog; result.calibration=struct('rx',calRx,'tx',calTx,'holdout',calReport);
result.latency_ledger=struct('physical_roundtrip_s',2*norm(cfg.platform.position_m)/c, ...
    'virtual_roundtrip_s',2*cfg.target.range_m/c,'fixed_device_s',cfg.instrument.fixed_latency_s, ...
    'note','固定流水属于设备附加时延；匹配滤波偏移只在解算扣除一次');
result.phase_ledger=struct('propagation','每条单程路径产生 -2*pi*fc*tau', ...
    'replay','目标相位减已建模相位；独立多普勒减估计物理多普勒','motion','短块冻结几何近似，非完整连续光行时闭环');
result.model_scope='ENVELOPE；理想方向图；频率平坦校准；块内冻结运动；行为级 bank/DMA';
result.scores=struct('range_error_m',result.observables.range_m-cfg.target.range_m, ...
    'range_pass',abs(result.observables.range_m-cfg.target.range_m)<=cfg.acceptance.range_tolerance_m);
result.forward_diagnostic=forwardDiag; result.compression_diagnostic=compressionDiag;
result.created_at=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
if cfg.output.save, result.output_dir=rtsim.verification.save_result(result); end
end
