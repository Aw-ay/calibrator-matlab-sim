> 本文为初版设计或验证记录。4gps 分支的最新采样体系、捕获时序及验收结果见 [4gps修改报告](4gps修改报告.md)；初版测试数量和运行记录保留作历史追溯。

# 校准与机载适配器实施报告

## 实施范围

本次实现覆盖 `+rtsim/+calibration`、`+rtsim/+airborne`、
`+rtsim/+dataflow` 以及对应的 `CalibrationAirborneTest` 和
`ExtendedDataflowTest`。实现仅依赖基础 MATLAB 与 `matlab.unittest`。

校准基线把每条 H/V 信号表示为 N×2 行矩阵，并按
`output = input * response.'` 通过二维复响应。RX 独立估计三个量程的
2×2 响应，TX 使用独立参考测量；两者都拒绝秩不足的 H/V 激励。
`solve_regularized_inverse` 返回包装结构，其中 `matrix` 是实际逆算子，
其余字段记录 `lambda`、增益上限、是否裁剪、未裁剪增益和拟合残差。
`apply_rx_cal` 只按 `context.range_id` 选择估计系数，`apply_tx_cal` 使用独立
TX 系数；两者都不接收或读取 plant 真值。`validate_calibration` 明确在独立
holdout 测量上评价校正后 RMSE。

这是一套**频率平坦的二维矩阵校准基线**。它没有实现清单中提到的宽带
FIR 逆、群时延、温度分档、频域不可补偿区间或实际量值溯源，因此不能将
结果表述为宽带全校准或实测计量资格证明。

`estimate_delay_cal` 从输入/输出时刻差中明确扣除参考路径时延与逐记录排队
等待，只把剩余中位数作为仪器固定延迟，并保留逐记录残差。它不把 OTA
传播或队列等待并入固定硬件时延。`update_calibration` 是慢环候选更新模型：
观测有效时按 `alpha` 与 `max_step` 产生完整候选系数集，只在 `commit=true`
的安全边界一次性递增版本并替换整组系数，否则旧系数保持活动且候选集通过
诊断输出。

## 随机性与数据要求

`simulate_calibration_session` 使用函数内部的独立 `RandStream`，由调用方
种子固定，不改变 MATLAB 全局随机流。`standards.bias_std` 在每条响应上形成
一次固定复偏差，`standards.noise_std` 形成逐样点复噪声。验收场景应使用
与拟合会话不同的种子或实测 holdout 数据。

校准会话严格要求以下字段：

- `plant.rx_response`：2×2×3；`plant.tx_response`：2×2。
- `standards.noise_std`、`standards.bias_std`：非负标量。
- `calTasks.rx_inputs`、`calTasks.tx_inputs`：N×2 且满列秩。
- 拟合约束 `lambda`、`max_gain`；RX 应用上下文 `range_id`。
- 验证限制 `max_rmse`。

## 机载假设模型

`platform_truth_step` 把轨迹作为规定输入，使用 `grid.index0/grid.fs_Hz`
得到局部时间，以恒加速度更新位置和速度，以恒滚转率加正弦滚转振动更新
姿态。它不是飞控动力学模型。零加速度、零滚转率、零振动时可严格退化到
静止平台。

`nav_sensor_step` 加入位置、速度和滚转偏置，以及位置白噪声，并把测量时刻
与消息可用时刻分开。`nav_time_aligner` 缓存消息，只允许使用请求时刻之前
已到达且标记可用的观测；采用恒速度线性外推，滚转保持最近观测值。PPS
参数在当前基线中保留接口但未进行 GSC 映射，因此不构成真实 PPS 同步验证。

其余机载函数均为清楚标记的简化假设模型：

- `antenna_pose_step`：仅滚转轴旋转的安装偏差与杆臂几何。
- `air_thermal_step`：单节点热阻/热容和独立传感器一阶滞后。
- `air_power_step`：电池容量积分、源内阻压降和遥测一阶滞后。
- `air_emc_step`：与电机转速同步的确定性正弦耦合，分别输出 RF、时钟、供电
  和数字错误概率量；系数须来自假设扫描或实测配置。
- `platform_scatter_step`：按单站双程 `1/R²` 场幅度、给定相位和 2×2 极化
  矩阵生成独立被动回波，不经过标定仪 ADC/TX 链。调用方提供的
  `bodyModel.amplitude_gain` 应合并波长、RCS、收发天线增益和未在函数中显式
  建模的损耗；`bodyModel.polarization_matrix` 是 2×2 被动散射极化算子。
- `air_adapter_step`：保持 plant 真值边界和 measurement 观测边界分离。

机载函数不读取尚未定义的全局配置，调用方必须显式提供签名所需字段。
热、供电、EMC 和散射参数未经实测时只能用于灵敏度分析。

导航的位置、速度及对应偏置允许 1×3 或 3×1，但输出严格保持真值输入形状，
防止 MATLAB 隐式广播生成 3×3 伪观测。主控使用的 3×1 契约已单独回归测试。

## 数据流行为模型

`pdw_fifo_step` 是独立的小型记录 FIFO，支持 `drop_newest` 或 `drop_oldest`
溢出策略。其服务单位是记录数，IQ 队列背压不会直接清空 PDW。
`iq_frame_pack` 要求 descriptor 明确标记 `RAW` 或 `CAL` 并保留采样网格；
细 PDW 未完成时按 `wait` 拒绝封帧，或按 `separate` 生成未附着 PDW 的帧。
载荷 CRC 使用基础 MATLAB 实现的 IEEE 反射式 CRC32，多字节数值按 MATLAB
内存字节序编码。该帧是逻辑记录格式，不是实际 AXI 线上编码。

`dma_queue_step` 对所有帧只消费一次 `busService.total_bytes` 总预算，完成不了
的整帧留在队列形成背压。它只表示整帧、容量和聚合有效服务率，没有模拟
AXIS 逐拍握手、TLAST 时序、BD 取回或真实 HP 端口吞吐。
`ps_service_step` 同样在 PDW 和 IQ 之间共享一次
`cfgPs.total_service_items`，优先级只决定预算分配顺序；控制命令经过配置的
软件步延迟，不能承担逐样点实时控制。

`config_commit_step` 把多次 shadow 写合并为候选配置，只在
`safeBoundary=true` 时原子替换活动配置并递增版本，避免脉冲中途半配置更新。
它不负责判断射频发射是否安全；实际启用 TX 仍必须经过独立安全状态机和
静音门。`storage_link_step` 分别核算本地容量和当次无线总字节预算，并优先
保存 PDW；`retain_iq=false` 或容量不足时可丢弃 IQ。该函数不代表持久介质
写入成功，也不把无线发送等同于本地保存。

数据流严格配置字段如下：PDW `capacity/overflow_policy`；DMA
`capacity_frames` 与一次性的 `total_bytes`；PS `total_service_items`、
`pdw_priority`、`command_delay_steps`；存储 `capacity_bytes/retain_iq` 和无线
`budget_bytes`。记录需携带 `id/kind/size_bytes`，其中 `kind` 为 `PDW` 或
`IQ`。

## 自动测试

测试按先失败后实现的顺序执行。初次运行的 8 项测试均因目标函数缺失而以
`MATLAB:undefinedVarOrClass` 失败；实现后同一测试文件在 MATLAB R2025a 中
得到 8 passed、0 failed、0 incomplete。覆盖内容包括三档 RX 与独立 TX
恢复、固定种子、秩不足拒绝、正则逆增益限制、量程选择、holdout 验证、
规定轨迹、导航延迟与因果性，以及各简化环境模型的基本数据契约。

扩展测试另覆盖固定延迟分账、慢校准原子提交、PDW 溢出、RAW/CAL 元数据、
CRC32 对载荷变化的响应、DMA 与 PS 的单一共享预算、shadow 配置提交、PDW
优先存储、单站双程距离律，以及 3×1 导航向量形状契约。

## 波形源与发射链复包络基线

`burst_scheduler_step` 锁存调用方给出的有限描述符，并只为当前网格内、尚未
发出且准备时间满足要求的脉冲生成事件。描述符必须给出 `id`、
`start_index`、`pulse_width_samples`、`pri_samples`、`pulse_count`、`source`、
`available_index` 和 `prepare_samples`；函数拒绝 PW 大于 PRI、非正脉宽或无限
脉冲数。它是描述符事件调度器，不是逐拍 RTL 调度证明。

`source_sync_model` 要求雷达和仪器时钟分别给出 `frequency_Hz/phase_rad`，
触发观测给出 `pps_locked/quality`，配置给出 `shared_frequency_reference` 和
`phase_strategy`。输出分别报告 PPS 秒对齐、频差、频率相干和 RF 相位相干；
PPS 对秒本身不会被表述为射频相参。只有共享频率参考、零模型频差且相位策略
明确为 `LOCKED` 时才标记 RF 相位相干。

`duc_dac_step` 在复包络上施加连续样点索引的 NCO 相位，并分别量化 I/Q。
调用方必须提供位数、满量程、NCO 频率、初相、valid 与安全样值，以及时钟的
`frequency_error_Hz/fs_Hz`。valid 为假时仍推进样点状态并输出复数安全样值。
量化复用 RX 的 `adc_clip_round` 契约：2 到 31 位有符号二补码，LSB 为
`full_scale/2^(bits-1)`，负满量程可达 `-full_scale`，正端最大码对应
`full_scale-LSB`。位数、满量程和采样率均执行有限范围检查。本模型未实现
插值滤波、模拟重构、镜像谱或真实 DAC INL/DNL。

`tx_rf_step` 使用频率平坦的 2×2 `response_matrix`、`voltage_gain`、环境
`gain_scale`、逐通道幅度限幅、饱和点 AM/PM 和 `monitor_coupling`。这是无记忆
复包络模型，没有滤波器频响、PA 热记忆、宽带互调或真实 T/R 开关动态。
`tx_monitor_step` 只读取耦合 tap，经独立 `response_matrix`、bias、时钟相位误差
和由独立种子驱动的复噪声后形成 IQ、功率和相位观测；它不读取端口真值。
随机流状态保存在 `st.rng_state`，并按每个样点固定 H-I、H-Q、V-I、V-Q 顺序
抽样，因此同一输入整块或任意拆块处理得到逐样点相同的噪声。RF 诊断同时
提供总布尔 `clipped` 和实际超限复通道元素数 `clipped_samples`。

`loopback_channel_step` 在任何响应或延迟处理前按每行 H/V 总功率检查
`max_input_power_W`，超限直接拒绝。通过后使用
`response_matrix + fixture_error_matrix` 和跨块整数 `delay_samples` 形成 RX
输入。夹具误差在诊断中单独保留。它不模拟电缆宽带色散、连接器重复性或 ADC
非线性，因此不能作为真实 RF 回环安全认证或计量结论。

`SourceTxTest` 覆盖复数 DAC 量化和静音时间推进、RF 矩阵响应与限幅/AM-PM、
独立可复现监测噪声、回环功率拒绝与跨块延迟、有限 burst 边界和准备时间，
以及 PPS、频率参考和 RF 相位关系的区分。
