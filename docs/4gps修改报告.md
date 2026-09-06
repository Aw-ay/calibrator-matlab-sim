# 4gps 修改与验证记录

## 实现对应

| 修改意见 | 实现位置 | 验证 |
|---|---|---|
| ADC / RFDC / PL / DRFM / 有效带宽分离 | `+config/default_config.m`、`derive_config.m`、`validate_config.m` | `SystemSamplingTest/rateRelations` |
| 8 SPC 连续样点及 H/V 三量程顺序 | `+ddc/pack_spc.m`、`unpack_spc.m` | `laneAndTimeOrder` |
| 抗混叠 FIR / D8 进入正式主链 | `+ddc/design_pl_filter.m`、`halfband_decimator.m`、`+sim/simulate_case.m` | `firArbitraryBlocks`、`firPassband`、`firStopband` |
| 主链分块状态一致 | `+sim/simulate_case.m`、`+core/instrument_core_step.m` | `mainChainBlockInvariant` |
| 秒参数派生与 8192 点容量 | `+config/derive_config.m`、`+sim/init_state.m` | `allPulseWidthsFitBank`、`physicalDetectionTimes` |
| DMA 和本地回放独立 | `+core/instrument_core_step.m` | `zeroDmaDoesNotMoveReplay` |
| 物理、可用、命令和实际发射时刻 | `+core/instrument_core_step.m` 的捕获记录 | `physicalEchoDistances` |
| A/B 共享核心 | `run_stage_a.m`、`run_stage_b.m` | `stationarySharedCore` |
| RX / 目标 Jones / TX 幅相恢复 | `+calibration` 与共享核心 | `knownJonesMapping` |
| ADC 4 GS/s 短窗专项 | `+ddc/rfdc_adc_specialty.m`、`run_adc_rfdc_demo.m` | `adcSpecialtyMatchesIdeal` |
| 雷达参数族与距离 / 速度指标 | `+config/apply_radar_profile.m`、`derive_config.m` | `radarProfiles` |

## 采样与参考面

正式默认采用 4 GS/s ADC、500 MS/s RFDC、8 SPC @ 62.5 MHz、FIR/D8、62.5 MS/s 核心、20 MHz 有效复基带。ADC 4 GS/s 仅在独立短窗中展开。

PL FIR 采用基础 MATLAB 的 Blackman 窗低通设计，默认 145 taps、群延迟 144 ns。设计声明通带纹波不超过 0.1 dB，31.25 MHz 起阻带至少抑制 60 dB。采用有状态 FIR 后抽取的功能等价实现，未模拟 FPGA 八相乘加资源调度或 RTL 周期。

记录参考面标为 `PL_FILTERED_RAW`：它是校准前、经过 PL FIR 的 IQ；保存时另行量化为码字，不能将其解读为未经滤波的 4 GS/s 实 ADC 原始数据。物理样点标签扣除 FIR 群延迟一次，数据可用时间保留实际处理等待。

## 排版规则

MATLAB 文件统一 UTF-8、LF 行尾、四空格缩进。拆分多语句单行，适当续行长表达式，清理尾随空白和重复空行，保留逻辑分组及中文注释。`miss_hit.cfg` 保存风格检查规则；MISS_HIT 只用于开发检查，运行仿真不依赖它。

## 验收证据

最终结果以 `results/acceptance/automatic_tests.csv`、`summary.json`、`code_analysis.json` 以及本次生成的 A/B 和 ADC_RFDC 报告为准。最终运行统计见本文末尾；演示目录与散列核对见 results/acceptance/release_verification.json。

`records.t_physical_rx_s` 指记录首样点的物理时间，包含预触发区；脉冲前沿测量仍由 PDW 提供。回放时刻与同一记录首样点对应，因此预触发区不会额外移动目标回波。

## 回放执行状态

捕获完成时只保存计划，`t_tx_actual_s` 初始化为 NaN。只有回放时钟实际抵达且安全门允许，才确认对应记录首样点的实际发射时间。`replay_accepted` 表示调度计划被接受，不能单独证明已经发射。

- `COMPLETED`：完整执行。
- `BLOCKED`：开始前被安全门阻止，未确认实际发射。
- `INTERRUPTED`：开始后被安全门中断，恢复后不补发残余波形。
- `OUTSIDE_WINDOW`：仿真结束时尚未执行。
- `WINDOW_TRUNCATED`：仿真结束时已开始但尚未完整执行。

正常执行、安全静音、窗口外计划及运行中导航故障分别由新增生命周期回归检查。

最终 DAC 使能同样属于执行门控：`instrument.dac.valid=false` 时，不能把 DRFM 计划标为实际发射。

## 最终验证

Windows MATLAB R2025a：112 项自动测试全部通过，失败 0、未完成 0。144 个 MATLAB 文件的 Code Analyzer 诊断为 0；MISS_HIT 0.9.44 与独立换行检查均通过，全部源码使用 UTF-8 / LF、无尾随空白或重复空行、行长不超过 120 字符。

全套测试后仅删除一条无用初始化和一条过期静态检查抑制注释；随后重新静态检查并运行正式 A/B 与 ADC 专项，刷新输出的源码散列清单。未修改仿真计算逻辑。
