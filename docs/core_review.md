# 核心闭环独立代码审查

范围：只读审阅 `+sim/simulate_case.m`、`+core/instrument_core_step.m`、`+replay`、`+radar`、`+config` 和 `tests/EndToEndTest.m`。重点按因果、距离/相位、bank/DMA、安全和真值边界检查。未修改被审源码。

## 严重问题

### [P0] DDS/AWG 可在单天线半双工 OTA 的雷达发射/接收窗口内发射

`instrument_core_step.m:84-95` 对 DDS 直接按雷达发射脉冲窗口置位，对 AWG 直接按绝对地址播放；运行时半双工门只在 `st.active` 为真时关闭。`st.active` 表示标定仪已经检测到到达自身接收端的脉冲，不表示雷达当前 RX/TX 窗口，也不覆盖 guard。`check_tx_windows` 仅在 `finish_capture` 的 DRFM 调度路径调用（`instrument_core_step.m:120-126`），DDS/AWG 完全绕过它。默认配置允许 DDS/AWG（`validate_config.m:11`），因此单天线非隔离 OTA 可在雷达脉冲发射时同步发射 DDS，或由 AWG 任意跨越保护窗。

后果：模型违反单天线半双工和 T/R 互锁，安全结果不能用于验收；DDS/AWG 还能绕过 DRFM 的数据就绪与窗口冲突检查。

建议：所有活动源先生成带时间范围的 TX 请求，再统一通过同一个窗口/guard/resource 安全仲裁；运行时安全门应依据明确的 RX/TX 占用状态，而不是检测器 `st.active`。

### [P1] 运动场景的重放命令使用 EOP 时刻观测，没有预测到实际发射事件

`simulate_case.m:49` 只把导航消息对齐到当前块时刻 `t`。`instrument_core_step.m:42` 在 EOP 调用 `finish_capture`，后者用这一份当前 `controlEstimate` 直接计算目标延迟、相位和极化（`instrument_core_step.m:112-128`）。实际 `b.tx_start` 可能晚很多，但没有以该发射事件时刻重新请求或外推位置/姿态；更没有分别求接收和发射事件的迟滞几何。

后果：B1 运动时距离、极化和载频相位命令对应 EOP，而物理回程使用后续块的真实位置。误差随虚拟延迟、速度和块边界变化，无法归因成受控导航残差。

建议：先从捕获事件和目标延迟确定候选 TX 时刻，再仅用当时已到达的导航观测预测该事件姿态，分别建立去程/回程估计；把命令版本和估计时刻锁存在 bank 描述符中。

### [P1] `worldProvider`/`observationProvider` 契约没有实现，真值与观测仍由配置内建生成

`simulate_case.m:4` 明确丢弃 `observationProvider`；`worldProvider` 仅在 `result.stage` 中转成标签（`simulate_case.m:9`）。真实轨迹固定由 `cfg.platform` 生成（`simulate_case.m:42`），观测也固定由同一个真实轨迹回看后注噪生成（`simulate_case.m:44-49`）。这与函数签名所表达的可替换真值物理侧和观测侧边界不一致。

后果：测试无法注入独立真值/观测提供者验证“核心不读真值”，A/B 的差异主要来自配置而非适配器边界；一个错误地把真值复制成观测的实现也可能通过现有端到端测试。

建议：真正调用两个 provider，并给核心只传 provider 产生的可用观测；测试用故意不同的 truth/estimate 和延迟观测证明输出只随后者改变。

## 重要问题

### [P1] 无导航分支从真实平台配置复制“名义位置”

`simulate_case.m:51-53` 在导航不可用时用 `cfg.platform.position_m` 构造 estimate，而同一字段正是 `platform_truth_step` 的真实轨迹初值。当前 `pll_locked && navValid` 会令安全门静音，所以默认没有形成实际发射，但控制对象和日志仍含真实初始位置；一旦安全状态逻辑调整或其他非发射消费者使用该 estimate，就形成直接真值泄漏。

建议：无导航时返回显式无效估计和协方差/可用性，不复制物理真值字段；所有依赖几何命令必须检查有效性。

### [P1] DMA 不影响回放的测试没有覆盖 bank 耗尽和 generation 生命周期

bank 在回放或 DMA 任一未完成时保持 busy（`instrument_core_step.m:67-77`），零 DMA 服务会永久占住每个完成捕获的 bank。这是合理的保守所有权，但 `EndToEndTest.m:31-36` 只有默认 4 脉冲、8 个 bank，因此从不触发耗尽；它只证明短场景回放样点不随 DMA 服务率变化。测试没有验证第 9 次捕获被拒绝、generation 不被旧 DMA/描述符混淆、busy bank 不覆写，以及释放顺序。

建议：使用 `pulse_count > bank_count` 和零/慢 DMA，逐脉冲断言 bank generation、拒绝原因、保留记录内容与回放时刻；再用 DMA 完成事件验证恰好一次释放。

### [P1] DRFM 窗口资源被硬编码为始终可用

`instrument_core_step.m:124` 调用 `check_tx_windows` 时传入 `struct('available',true)`，没有检查 TX 资源、其他 bank 已排定的重放、AWG/DDS 占用或发射队列。同一时刻多个 bank 的 `b.replay` 会在 `instrument_core_step.m:53-63` 直接复数相加。

后果：互相重叠的任务不会得到 `RESOURCE_BUSY`，可能超过单路 DAC/PA 的功率能力；最终只由 `simulate_case.m:84-86` 统一硬裁剪，失真被当成物理链结果而不是调度拒绝。

建议：调度阶段维护所有已承诺 TX 区间和资源计数，明确允许叠加还是拒绝；功率/峰值约束也应在接受任务前检查。

### [P1] 配置检查遗漏会让非有限信道和安全参数进入运行时

`validate_config.m` 没有验证 `channel.kind` 枚举、`fc_Hz/fs_Hz` 一致性、非负有限 cable delay、有限 cable gain/reflection coefficient、bank_count 为整数、DMA 速率为有限数，也没有检查温度/电压阈值和 AWG 表维度/峰值。只对 LIVE 做了特殊安全组合检查（`validate_config.m:12-14`）。

后果：NaN/Inf 或非法模式可能在深层传播；DDS/AWG 的危险配置不会在入口拒绝。

建议：入口完整验证所有已支持分支及单位，特别是所有发射模式的端口隔离、窗口和峰值限制。

## 中等问题与测试盲区

### [P2] “固定延迟”只参与可用性检查，没有独立的状态或相位账本证据

`solve_target_delay.m:4-9` 计算 `wait_s=device-fixed`，但 `delay_samples` 仍为完整 device delay；`instrument_core_step.m:117-119` 只用 fixed latency 判断是否来得及。作为总时延调度这可以成立，但实现没有独立流水状态，无法证明固定延迟不会在其他层重复加入，也无法报告实际等待与流水完成事件。现有测试只检查“不可能距离”总拒绝数。

建议：描述符记录 capture-ready、pipeline-ready、scheduled-TX 三个时间，并分别测试固定延迟边界前后一个样点。

### [P2] 端到端距离测试依赖同一主控配置，缺少独立相位与因果断言

`EndToEndTest.m:10-16` 只检查最终距离、PDW 数和拒绝数；`impossibleRange` 也只检查静音（`EndToEndTest.m:47-51`）。没有断言任何输出样点早于数据 ready 时为零，没有核对传播相位、残余相位、固定延迟分项，也没有在观测偏差下证明控制不访问真值。

建议：加入首个非零 TX 样点与 `available_index/fixed_latency` 的独立边界测试、已知 CW 的复相位测试，以及 truth 不变/estimate 改变与 estimate 不变/truth 改变的成对测试。

### [P2] 雷达估计器对缺测和退化极化没有明确资格状态

`radar_observable_estimator.m:18-27` 对全 NaN/零功率直接产生 NaN/Inf 的 ZDR、PhiDP 和 rho，没有 validity/原因；Doppler 仅要求 H 通道全部峰值有限，未检查脉冲 ID 匹配、相位展开模糊和 PRI 均匀性。宽接收门中每个脉冲独立取最大值，可能把其他目标或噪声峰当成本目标。

建议：输出每项 applicability/validity，显式处理零功率、缺脉冲、多目标关联和 Doppler 模糊；测试这些退化输入。

## 总体判断

静态 A0/A2 演示可作为行为级冒烟模型，但当前实现不能签发半双工发射安全、运动相位/距离一致性、bank/DMA 满载生命周期或真值隔离验收。最先应修复统一 TX 安全仲裁和事件时刻几何/相位命令，然后补充 bank 耗尽及 provider 隔离测试。

## 相位项复核更正

对恒定径向速度，若 `modeledPhase(t0)=phi0+2*pi*fd*t0`，当前公式中的 `-modeledPhase(t0)+2*pi*fd*t0` 正好消除块原点，随后以绝对时间施加 residual frequency 可恢复目标线性相位。因此早期审查中“恒速下相位随分块改变”的判断已撤回。加速度、块内冻结和命令没有预测到实际发射事件的问题仍归入前述运动几何缺陷。

## 最终修复复核

- **RESOLVED — DDS/AWG 半双工整窗口检查。** `instrument_core_step.m:84-103` 以 `source_start_s` 建立 DDS 脉冲或完整 AWG 区间，并在选源前统一调用 `check_tx_windows`；`SafetyIntegrationTest.m:4-13` 同时覆盖冲突静音和安全窗口可发射。该修复消除了原 P0 所述 DDS/AWG 绕过窗口仲裁的问题。
- **RESOLVED — DRFM 单回放端口冲突。** `instrument_core_step.m:152-160` 在接受新 bank 前与所有活动回放区间比较，重叠时明确返回 `REPLAY_RESOURCE_BUSY`，不再把两个 bank 静默复数叠加。
- **RESOLVED — 真值/观测 provider 边界及失锁回退。** `simulate_case.m:45` 实际调用真值 provider，`:52-55` 强制自定义真值配套独立观测 provider 并实际调用，`:56` 拒绝未来尚未可用消息。失锁分支 `:59-62` 改用 `cfg.navigation.initial_position_m`，不再读取 `cfg.platform.position_m`；核心配置仍在 `:25-29` 移除平台、导航和环境真值。
- **RESOLVED WITH DOCUMENTED MODEL LIMIT — 未来收发事件恒速度几何。** `instrument_core_step.m:123-136` 用已到达观测的速度分别外推捕获接收位置和未来发射位置，并迭代更新两段距离后再求目标延迟。它修复了“直接把 EOP 位置用于未来 TX”的行为缺陷。该实现仍是恒速度和短块冻结近似；`simulate_case.m:128-130` 已明确声明不是逐样点运动或完整连续迟滞闭环，因此不将加速度、姿态连续变化或逐样点多普勒列为已实现能力。
- **RESOLVED — bank 压力与 generation 验证。** `SafetyIntegrationTest.m:15-23` 用单 bank、三脉冲和零 DMA 服务触发实际耗尽，断言仅首帧生成 PDW、后两帧明确丢弃且 generation 保持 1；独立 `CaptureSchedulerTest` 另覆盖 busy bank 内容不被覆盖和 generation 引用校验。
- **RESOLVED — 恒速相位原点回归。** `SafetyIntegrationTest.m:41-47` 用相隔 0.1 秒、相位随已建模 Doppler 推进的两个控制时刻验证 `phase0_rad` 不随块原点改变，和上节解析推导一致。

以上项目复核后，原报告相应 P0/P1 行为缺陷视为已解决。仍保留的限制是文档中明确的 ENVELOPE、短块冻结运动和行为级 bank/DMA 范围，以及未在本轮要求内处理的雷达退化资格和更细粒度固定流水事件账本。
