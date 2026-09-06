# 转换器与数字前端实现报告

## 已实现接口

- `rtsim.rx.adc_clip_round`：按 `bits` 和单个 I/Q 分量的 `full_scale` 做有符号舍入与饱和，输出 `int32` I/Q 码字、逐样点削顶标记和 LSB。
- `rtsim.rx.adc_pipeline`：接受 N×2×3（也兼容其他尾随维度）的复包络，返回码字反量化后的复幅度，并在诊断中保留 I/Q 码字与削顶标记。
- `rtsim.rx.rx_common_step`：公共增益、公共复高斯噪声和无记忆幅度限幅；噪声只在三档分路前注入一次。
- `rtsim.rx.rx_three_range_step`：三档增益、每档 2×2 H/V 复响应矩阵及可选独立支路噪声。
- `rtsim.ddc.nco_mixer`：显式频率、初相和旋向，跨任意块边界保存相位。
- `rtsim.ddc.halfband_decimator`：任意有限 FIR 系数和正整数抽取倍率，保存 FIR 状态及全局抽取相位，块分段不改变结果。
- `rtsim.ddc.fixedpoint_model`：单个显式量化级的浮点参考，要求位宽、小数位、舍入和饱和方式完整；拒绝 bit-true 声明。
- `rtsim.ddc.frequency_plan`：仅校验并回显完整、受能力表约束的显式频率规划。
- `rtsim.ddc.design_filter_chain`：只验算给定系数的实际通阻带响应，不从名义指标猜测系数。
- `rtsim.ddc.rfdc_stream_adapter`：只执行已核对的数组维度排列；未声明 lane/IQ 布局时拒绝运行。
- `rtsim.contract.make_signal_block`、`validate_signal_block`：建立并检查单位、参考面、布局、有效掩码和时间网格契约。
- `rtsim.time.validate_time_grid`、`advance_time_grid`、`gsc_stamp`：验证时间网格，用带溢出检查的 `uint64` 商余数算法推进大 GSC，并生成逐 lane 标记。
- `rtsim.time.model_mts`：只有明确禁用时透传；缺少板卡配置和实测残差时拒绝模拟真实 MTS。

## 适用范围

本实现是基础 MATLAB 的复包络、浮点行为参考。`adc_pipeline` 的输入不是 RF 实 ADC 波形，输出也不是 RFDC 原生逐拍流；整数码字仅用于记录量化边界。公共和支路噪声使用调用方当前 MATLAB 随机流，噪声功率定义为每个复样点的平均 `abs(x)^2`。

三档模型当前包含无记忆 2×2 复矩阵，不包含支路群时延、频率选择性、恢复动态或非线性记忆。FIR 抽取器支持跨块状态，但不声明系数已对应某块硬件，也不声明逐级定点结果。RFDC 布局只做经配置证明的维度排列。

绝对 GSC、样点计数和局部索引均为 `uint64`；一个 tick 内的 `fraction0_ticks` 为 `[0,1)` 的 double。大整数推进不先把绝对 GSC 转成 double，并显式检查加法和乘法溢出。该时间模型不是实际 PPS、时钟漂移或 MTS 测量模型。

新增的 ADC 非理想均为相互独立、约定显式的模型；只有调用方提供所需规范基准、输入频率含义或逐码数据时才运行，不由基础量化模型隐式代替。

## 扩展独立模型

- `noise_model`：从复相关矩阵和逐通道复样点功率构造协方差噪声，注明输入参考面和离散 Nyquist 白噪声范围。
- `adc_sigma_from_nsd`：将单边 dBFS/Hz（以 RMS 满量程为基准）积分成带内方差，并扣除已经包含的噪声源；负残差视为配置冲突。
- `adc_jitter_inject`：只提供以 ADC 端实际 RF/IF 输入频率为灵敏度的独立样点包络等效相位模型，不以低频基带频率代替输入载频。
- `adc_make_inl_from_dnl`：从完整逐码 DNL 和明确 LSB/下端点生成单调码宽、阈值、INL 与失码标记。
- `adc_apply_interleave_spurs`：按显式交织相位索引施加周期增益、偏置和相位误差，并跨块保存相位索引；不模拟真实非均匀采样。
- `adc_metrics`：只报告定义明确的时域功率、RMS、峰值和削顶比例；缺少音调、窗函数与积分范围时不生成 SINAD/SFDR 数字。
- `clock_model_step`：提供时间偏置、名义频偏和独立随机游走模型；它不是 PPS 驯服或实测相噪模型。
- `latency_ledger`：分别保存 RF 传播、滤波群时延、硬件流水和排队等待，只做账本，不自动修改波形时间。
- `channel_alignment_step`：对已核对的通道布局施加非负整数样点延迟，并保存跨块历史。
- `model_mts`：可用 `BEHAVIORAL_RESIDUAL` 注入已声明的整数残差，诊断明确标记其不等价于真实 RFDC MTS。

所有新增随机模型使用自己的 `st.seed` 和 `st.rng_state` 创建本地 `RandStream`，不读写 MATLAB 全局随机流。默认种子按模块区分；整块调用与携带状态的任意分块调用产生相同序列。主控可按计划为公共前端和三档分别传入 `cfg.seed+10`、`cfg.seed+11`。

`advance_time_grid` 已增加接近 `uint64` 上限的测试。实现将样点数与有理步长拆成商和余数后运算，对每次乘法和加法执行上溢检查；可精确推进到 `intmax('uint64')`，超过范围时报 `rtsim:time:CounterOverflow`，不会回绕或转成 double 绝对计数。若中间乘积本身超过 `uint64`，实现会保守拒绝该跨度，调用方应分段推进。

## 可重复运行清单

`rtsim.verification.write_run_manifest(cfg, files, versions, seeds, reports)` 将配置、软件版本、各模块种子、测试/运行报告和文件哈希写入 `run_manifest.json`。推荐的 `files` 形式为：

```matlab
files = struct( ...
    'paths', {{'run_stage_a.m', 'data/input.dat'}}, ...
    'project_root', projectRoot, ...
    'out_dir', fullfile(projectRoot, 'results', runId));
manifest = rtsim.verification.write_run_manifest( ...
    cfg, files, versions, seeds, reports);
```

也可直接传入路径 cellstr；此时从 `cfg.project_root` 和 `cfg.manifest_out_dir` 取目录，缺省分别为当前目录和其下 `results`。输出结构包含 `schema_version`、`configuration`、`versions`、`seeds`、`reports`、`files`。每个文件记录含工程内相对 `path`、`status`、`sha256` 和 `bytes`。

只有 `project_root` 内的普通文件会被读取和哈希。缺失文件记录为 `MISSING`；工程外文件记录为 `EXCLUDED_EXTERNAL`，且不保存绝对路径；常见凭据、秘密和私钥文件名记录为 `EXCLUDED_SECRET`。输出目录也必须位于 `project_root` 内。函数使用 MATLAB 所带 Java `MessageDigest` 逐块计算 SHA-256，避免把大文件整体读入内存。

函数返回值与 JSON 内容采用同一个可序列化结构。任意嵌套 struct/cell 中的复数数值数组编码为 `struct('encoding',"complex",'real',real(x),'imag',imag(x),'size',size(x))`；读取后用 `reshape(real + 1i*imag, size)` 可逆恢复。返回的 `manifest.configuration` 因此也是该可序列化形式，不保留原始复数 MATLAB 数组。实数 `NaN`/`Inf` 仍交由 MATLAB `jsonencode` 的标准 JSON 表示处理；不支持的对象类型会明确报错，不会静默转成字符串。

## 测试结果

测试文件：`tests/FrontendTest.m`、`tests/ExtendedFrontendTest.m` 和 `tests/ManifestTest.m`。测试先在生产函数缺失或旧随机行为存在时运行并得到预期失败，随后实现代码。2026-09-06 使用 MATLAB R2025a `-batch` 实际联合运行：22 项通过，0 项失败，0 项未完成。除前端行为外，运行清单测试覆盖相同内容哈希稳定、内容变化哈希变化、JSON 可读取、缺失文件记录和工程外文件排除。
