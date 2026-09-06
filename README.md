# 双偏振有源标定仪 MATLAB 仿真

公开仓库：[Aw-ay/calibrator-matlab-sim](https://github.com/Aw-ay/calibrator-matlab-sim)，本次修改位于 `4gps` 分支。实现依据见 [4gps修改依据](docs/4gps修改依据.md)。代码注释和运行报告使用中文。

## 运行

使用 MATLAB R2025a，依赖基础 MATLAB 和自带 `matlab.unittest`，无需 DSP、Phased Array 或 Fixed-Point 工具箱。下载后将 MATLAB 当前目录切换到本仓库根目录：

```matlab
addpath(pwd);
run_tests;                           % 全部回归及验收记录
run_code_checks;                     % MATLAB 静态检查
results = run_demo;                  % 正式采样链的 A/B 示例及中文图表
adc = run_adc_rfdc_demo;              % 独立4GS/s短窗、误差报告和对比图
```

正式配置与快速算法回归分别选择：

```matlab
cfg = rtsim.config.default_config('RFSoC_SYSTEM_EQUIVALENT');
cfg.target.range_m = 50000;           % 虚拟目标距离，单位米
result = run_stage_a(cfg);

quick = rtsim.config.default_config('ALGORITHM_SMOKE');
quick.output.save = false;           % 快速回归可关闭图表与波形落盘
result = run_stage_a(quick);
```

两档使用相同的 DRFM、延迟公式、校准参考面、极化处理和 A/B 核心。快速档用于软件回归；正式档使用下列采样结构。

## 采样体系

| 参数 | 正式配置 | 含义 |
|---|---:|---|
| RF 载频 | 2.8 GHz，可设 2.7–3.0 GHz | 射频中心频率 |
| 实 ADC 采样率 | 4 GS/s | 仅用于独立短窗专项模型 |
| RFDC 复数输出 | 500 MS/s | 主仿真的输入采样率 |
| RFDC 并行接口 | 8 SPC、62.5 MHz | 每时钟八个连续样点 |
| PL 抽取 | 抗混叠 FIR、D=8 | 500 → 62.5 MS/s |
| DRFM 核心 | 62.5 MS/s、1 SPC | 捕获、校准、目标处理与回放 |
| 有效复基带带宽 | 20 MHz | 以零频为中心的 −10 至 +10 MHz |

主链真实构造 `clock × 8 × H/V × 三量程` 数据，经有状态 FIR 抽取送入核心。20 MHz 始终表示需要保留的有效带宽；62.5 MHz 表示接口时钟；两者均不能代替 RFDC 的 500 MS/s 样点率。

```text
雷达复包络 → 前向传播 → 公共前端 / 三量程 H/V / RFDC 等效 IQ
          → 500 MS/s、8 SPC → 抗混叠 FIR / D8
          → 62.5 MS/s、1 SPC → 捕获 / EOP / 选档 / RX 校准
          → 目标 Jones 矩阵 / 因果延迟调度 / 回放
          → TX 校准 / DAC / RF → 反向传播 → 雷达接收与匹配滤波
```

4 GS/s 专项在几微秒窗口内生成实 RF 采样，检查 Nyquist 区、NCO 符号、量化、抖动、DDC 和 RFDC 抽取，并与理想 500 MS/s 复基带比较。系统级长记录从 RFDC 复数端开始，避免连续展开 4 GS/s 数据。

## 雷达波形与捕获

支持 smoke、近程短脉冲、常规天气 LFM、远程 LFM、强天气高 PRF 和标定波形参数族。每次配置检查严格要求脉宽小于 PRI，并计算：

- 第一不模糊距离：`c / (2 PRF)`。
- Nyquist 速度：`λ PRF / 4`。
- 理论距离分辨率：`c / (2 B)`。
- 距离采样栅格：`c / (2 Fcore)`，正式配置约 2.398 m。

**2.398 m 是采样栅格，距离分辨率由波形带宽决定。** 例如 1 MHz 带宽的分辨率约 150 m，20 MHz 带宽约 7.5 m。不同 PRF 的不模糊距离与速度不同。

| `apply_radar_profile` 名称 | 默认脉宽 | 带宽 | PRF | 脉冲数 |
|---|---:|---:|---:|---:|
| `SMOKE` | 10 μs | 1 MHz | 1 kHz | 4 |
| `SHORT_PULSE` | 2 μs | 2 MHz | 3 kHz | 64 |
| `NORMAL_LFM` | 40 μs | 5 MHz | 1 kHz | 64 |
| `LONG_RANGE_LFM` | 120 μs | 2 MHz | 0.5 kHz | 64 |
| `SEVERE_WEATHER` | 20 μs | 5 MHz | 3.3 kHz | 128 |
| `CALIBRATION` | 保留用户波形参数 | ≤20 MHz | 可配置 | 可配置 |

```matlab
cfg = rtsim.config.default_config();
cfg.target.range_m = 100000;
cfg.radar.receive_gate_m = [500, 150000];
cfg = rtsim.config.apply_radar_profile(cfg, 'LONG_RANGE_LFM');
% 完整64脉冲任务比默认smoke波形需要更多时间和内存。
result = run_stage_a(cfg);
```

捕获参数以秒配置，运行时根据核心采样率派生点数：预触发 2 μs、后触发 2 μs、EOP 保持 1 μs。正式配置按最大 120 μs 脉宽使用 8192 点 bank；124 μs 对应 7750 点，并为滤波尾部预留空间。改变采样率时不应手工覆盖派生点数。

## 时间与数据流

物理接收时间和数据可用时间分别记录。FIR 群延迟从样点物理时间标签中补偿一次；数据可用时间仍包含 FIR、EOP 确认、选档、RX 校准及 bank 读准备。

```text
tau_dev  = (2 Rv - Rf - Rb) / c
t_target = t_RX + tau_dev
t_cmd    = t_target - tau_fixed
t_actual = t_cmd + tau_fixed
t_cmd   >= t_data_ready
```

无法满足因果约束的回放会被明确拒绝。固定流水和 FIR 延迟不会再叠加到虚拟目标距离。长脉冲在近虚拟距离处可能尚未捕获完成，这属于不可实现时延，不能通过等待后再发射冒充正确距离。

bank 对回放和 DMA 保持独立引用。DMA 为零或拥塞不会移动已接受回放的时刻；bank 被占满时，新捕获会记录丢失，已有记录不会被覆盖。

## 输出与模型范围

每次 A/B 运行保存 `result.mat`、`pdw.csv`、`run_report.json`、`运行报告.md`、`run_manifest.json` 和 `仿真结果.png`。报告包含采样体系、雷达限制、观测误差及时间账本；清单记录配置、种子、MATLAB 版本和源码 SHA-256。

`results/acceptance/automatic_tests.csv` 是实际运行的测试结果。`original_spec_matrix.csv` 保留原 T01–T40 规格的资格边界：软件测试通过不能替代尚缺的实测天线、实测校准、板卡与 RTL 验证。

校准由独立 H/V 合成激励估计，再用独立种子留出数据验证。在线核心只接收估计系数与导航观测；真实平台状态只进入传播和评分。相同静止配置下 A/B 使用同一核心。

仍保留以下模型范围：频率平坦 2×2 校准；线性分数延迟；B 平台按块冻结传播几何；完整输出受内存上限约束。长 CPI 会增加运算与存储量。当前工程是系统功能参考，不提供板卡逐拍 RTL、真实 AXI/MTS、全带宽计量校准或随机天气统计资格。`LIVE` 需要电缆或明确隔离的端口；其他信号源继续执行半双工和故障保护。

历史模块报告描述初版接口；采样率、捕获和时间链的最新约定以本 README 与 4gps 修改报告为准。
