# 双偏振有源标定仪 MATLAB 仿真程序

本工程依据上一级目录中的学习记录与 A/B 两阶段设计包实现。程序、测试说明和图表采用中文注释或中文标注；原设计资料没有被修改。

GitHub 公开仓库：<https://github.com/Aw-ay/calibrator-matlab-sim>。
下载或克隆后，将 MATLAB 当前文件夹切换至本仓库根目录，即可运行 `run_tests` 和 `run_demo`。下方绝对路径是原开发机器的示例，请按实际下载位置调整。

## 运行

已使用 Windows MATLAB R2025a 验证。只依赖基础 MATLAB 和自带 `matlab.unittest`，不需要 Phased Array、DSP、Statistics 或 Fixed-Point 工具箱。

在 MATLAB 命令窗口执行：

```matlab
cd('E:\AWAY\matlab\calibrator_sim');
addpath(pwd);
run_tests;                       % 执行全部自动测试，写出验收结果
results = run_demo;              % 运行固定平台 A 和飞行平台 B，保存图表
```

单独运行或修改参数：

```matlab
cfg = rtsim.config.default_config();
cfg.target.range_m = 25000;      % 虚拟目标距离，单位为米
cfg.target.doppler_Hz = 100;     % 独立多普勒测试频移
a = run_stage_a(cfg);

cfg = rtsim.config.apply_case_profile(cfg,'B1');
cfg.navigation.position_bias_m = [0.01;0;0]; % 导航位置偏差
b = run_stage_b(cfg);
```

默认波形为 2.8 GHz 载频的复包络表示，复采样率 20 MHz、带宽 1 MHz、脉宽 10 μs、PRI 1 ms、4 个脉冲。物理距离 2 km、虚拟距离 20 km。**这些都是算法演示假设，不是 RFSoC 实 ADC 采样率或整机验收指标。**

`run_stage_b()` 默认运行飞行场景；`run_stage_b(cfg)` 保留用户传入的全部配置。因此把同一个静止配置分别传给 A/B，就是严格退化回归。

## 结果文件

每次运行在 `results/A_时间戳` 或 `results/B_时间戳` 中保存：

- `result.mat`：雷达发射、RP1 接收、RP1 发射、雷达接收波形、距离像、PDW、选档、RAW 码字、拒绝原因和平台日志。
- `pdw.csv`：到达时间、脉宽、功率、频率、量程及校准编号。
- `run_report.json` 和 `运行报告.md`：误差、模型资格、缺失数据及延迟/相位账本。
- `run_manifest.json`：配置、MATLAB 版本、种子与源码 SHA-256。
- `仿真结果.png`：中文四联图。

`results/acceptance/automatic_tests.csv` 是**本工程实际执行的自动测试结果**。
`original_spec_matrix.csv` 是**原设计 T01–T40 的完整验收资格**。前者通过不会让未执行的硬件子场景自动变为 PASS；只有明确完整覆盖的 T30 退化断言直接映射 PASS。其余根据资料和覆盖情况保留 NOT_RUN、BLOCKED_MISSING_DATA 或 NOT_APPLICABLE。

## 已实现的主链

```text
有限 LFM/CW 雷达发射
  → 单程 OTA/电缆、Jones、多径分数延迟
  → 公共前端和公共噪声 → 三档 H/V 接收 → ADC 量化 → 基带 DDC
  → 因果检测、预触发捕获、EOP 整脉冲选档
  → 独立 RX 校准测量拟合 → DRFM 延迟/极化/剩余相位
  → 信号源选择和半双工/故障保护 → 共用 TX 校准 → DAC → RF
  → 反向传播 + 独立机体被动回波
  → 雷达接收死区/噪声 → 匹配滤波 → 距离/多普勒/HV 观测
```

捕获 bank 持有回放和 DMA 两份独立引用；DMA 服务每样点只消费一次总带宽预算。忙 bank 不覆盖，没有空闲 bank 会记录丢失。回放冲突显式拒绝，FIFO 等待和固定流水不重复加到虚拟距离。

校准由独立 H/V 激励的合成测量估计，再用另一种子留出数据验证。在线核心只接收估计系数和导航观测，不读取真实 RF 响应矩阵。实测数据接口和格式见 `docs/geometry_report.md`、`docs/calibration_airborne_report.md`。

## 信号源与安全

- `DRFM`：默认模式，检测并捕获完整脉冲后回放，短到无法取得数据的目标时延会被拒绝。
- `DDS`：按 `instrument.source_start_s` 起始，在有限脉冲窗产生独立单音。
- `AWG`：需提供 `instrument.awg_table`，形状为 N×2 的复数模板，采样率等于工程复采样率。
- `LIVE`：只允许电缆或明确隔离的收发端口；禁止物理正反馈回环。
- `MUTE`：所有有源输出为零，配置的机体被动散射仍存在。

DDS/AWG 同样检查完整发射区间与接收保护窗口；时钟失锁、欠压、过温、导航无效时关闭发射。`source_start_s` 表示仪器本地发射源起始时间，不自动等于虚拟目标距离。

## 数据约定和文件组织

- 物理复波形为 N×2，列顺序 H/V，单位 sqrt(W)，功率为 `abs(iq).^2`。
- 三档数据为 N×2×3，顺序 HIGH/MID/LOW；H/V 对同一脉冲选择同一档。
- RAW 记录使用分开的 `i_code/q_code` 与 `lsb`，明确 `ADC_RAW` 参考面；不把已校准数据标成 RAW。
- 坐标为 ENU 三元素列向量；角度明确使用度或弧度。方向图原始值与显示展宽分开保存。
- 独立模块的 SampleGrid 支持 uint64 大计数与有理数步长；主链采用有内存上限的短窗口局部样点索引。
- `+rtsim` 下按 config、geometry、pattern、channel、rx、ddc、capture、calibration、replay、tx、dataflow、radar、airborne、verification 分包。
- `docs/函数实现覆盖.json` 对照原 124 个设计名称。存在源码表示相应基线接口已实现，不表示原职责中的所有高保真分支均已实现。

## 模型范围与保留事项

本次交付是**可运行的复包络参考工程**，不是板卡逐拍复刻。

1. 主链使用理想复天线与频率平坦 2×2 校准。实测复方向图、全带宽校准、计量溯源数据缺失，因此不能宣称真实 XPD/相位/功率校准资格。
2. 线性分数延迟在近 Nyquist 处有幅度下垂。默认带宽保留裕量；独立滤波器工具可用于进一步验证。
3. B 主链按短块冻结真实几何，并用已到达观测的恒速度预测求未来回放延迟。独立 `solve_retarded_geometry` 实现迭代光行时，但主链尚不是逐样点连续运动/宽带天线迟滞传播，快速加速、姿态变化及长等待需做块长收敛和进一步模型验证。
4. 主链的记录窗口受 `sim.max_samples` 限制；独立队列/存储模型支持任务预算分析，但主链没有将长任务完整波形自动转换为事件压缩存储。
5. `SAMPLED_CONVERTER`、`BIT_TRUE_STREAM`、真实 AXI/MTS/RTL、4×8 频率子信道、随机天气源、完整 DPD 与近场扩展不会被静默当成已支持。未确认的可选分支默认关闭。
6. 固定门限检测用于可解释基线；独立 EWMA、边沿估计等模块供算法实验。低 SNR 虚警/漏检统计和所有原始 T19 子场景仍需专门任务，不能由演示曲线推断指标。
7. 单个确定性目标的相关系数不等于任意随机天气相关系数；点目标功率不转换为未定义的 dBZ。

更完整的模块约束、输入字段和测试证据见 `docs` 中各模块报告。
