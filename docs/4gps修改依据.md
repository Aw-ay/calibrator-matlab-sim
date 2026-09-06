# 双偏振有源标定仪 MATLAB 仿真工程新工作方案修改意见

## 1. 修改目标

下一版工程应完成两个核心统一。

第一，将“20 MHz”重新定义为 **RFDC/DDC 后复基带有效信号带宽**，不再作为数字主链采样率。

第二，使 MATLAB 系统级模型与实际 FPGA 数据通路保持一致：

\[
\boxed{
4\ {\rm GS/s\ real\ ADC}
\rightarrow
RFDC\ DDC
\rightarrow
500\ {\rm MS/s\ complex}
}
\]

RFDC—PL 接口采用：

\[
\boxed{
62.5\ {\rm MHz\ PL\ clock}\times8\ {\rm SPC}
=
500\ {\rm MS/s}
}
\]

随后 PL 采用抗混叠 FIR 和 8 倍抽取：

\[
\boxed{
500\ {\rm MS/s},\ 8\ SPC
\xrightarrow{\mathrm{FIR}+D=8}
62.5\ {\rm MS/s},\ 1\ SPC
}
\]

最终以

\[
\boxed{62.5\ {\rm MS/s\ complex}}
\]

作为 DRFM、脉冲捕获、极化处理、延迟控制和回放的统一核心采样率。

---

# 2. 新旧工程区别

| 项目 | 原始工程 | 当前重构工程 | 下一版目标 |
|---|---|---|---|
| 20 MHz含义 | 实际被当作复采样率 | 已声明为算法演示采样率 | **定义为复基带有效带宽** |
| ADC层 | 未真实区分 | 有接口但未进入主链 | **4 GS/s仅做专项等效验证** |
| RFDC输出 | 未体现 | 有RFDC适配模块 | **500 MS/s complex，8 SPC** |
| PL接口时钟 | 未定义 | 尚未进入主闭环 | **62.5 MHz** |
| RFDC接口并行度 | 未定义 | 有SPC概念 | **8 SPC** |
| PL抽取 | 20→10 MS/s | 有独立FIR模块但未接主链 | **500→62.5 MS/s，D=8** |
| DRFM处理速率 | 10/20 MS/s | 20 MS/s | **62.5 MS/s，1 SPC** |
| 检测参数 | 按samples定义 | 仍主要按samples定义 | **按秒定义，再换算samples** |
| 缓存 | 2048点 | 2048点+容量检查 | **按最大雷达脉宽自动计算** |
| DMA与回放 | 耦合较强 | 已基本解耦 | 保持解耦 |
| 雷达参数 | 单一测试参数 | smoke测试参数 | **多工作模式参数族** |
| A/B阶段 | 存在部分差异 | 已共享核心 | 保持共享核心 |
| 4 GS/s全场景 | 不适用 | 未实现 | **不做；仅短窗专项模型** |

---

# 3. 新的数字接收链定义

建议建立四个不同概念，禁止再使用一个 `fs` 同时代表所有含义。

## 3.1 射频和ADC层

中心频率基准：

\[
f_c=2.8\ {\rm GHz}
\]

工程应允许：

\[
2.7\sim3.0\ {\rm GHz}
\]

范围配置。

ADC：

\[
\boxed{F_{\rm ADC}=4\ {\rm GS/s}}
\]

但系统级 MATLAB 仿真不需要连续产生 4 GS/s 长记录。

4 GS/s 只用于独立的 ADC/RFDC 专项模型，验证量化、采样抖动、RFDC NCO、数字下变频和抽取的正确性。

---

## 3.2 RFDC输出

RFDC 完成数字下变频后输出复 IQ：

\[
\boxed{F_{\rm RFDC}=500\ {\rm MS/s}}
\]

PL接口采用：

\[
F_{\rm clk}=62.5\ {\rm MHz}
\]

每时钟：

\[
N_{\rm SPC}=8
\]

因此：

\[
F_{\rm RFDC}
=
F_{\rm clk}N_{\rm SPC}
=
62.5\times8
=
500\ {\rm MS/s}.
\]

MATLAB 中建议真实表示为：

\[
N_{\rm clk}\times8\times2
\]

或三量程情况下：

\[
N_{\rm clk}\times8\times2\times3,
\]

分别对应：

\[
\text{clock}\times SPC\times(H/V)\times range.
\]

这样可以直接对应 FPGA 的实际并行数据接口。

---

# 4. 500 MS/s → 62.5 MS/s 的PL抽取方案

不能简单：

> 每8个样点取一个。

必须先完成抗混叠滤波。

推荐数学结构：

\[
\boxed{
x_{500}[n]
\xrightarrow{H(z)}
v[n]
\xrightarrow{\downarrow8}
y_{62.5}[m]
}
\]

其中：

\[
y[m]
=
\sum_k h[k]x[8m-k].
\]

因为 RFDC 输入本身已经是 8 SPC，FPGA 最适合采用 **8相多相 FIR**：

\[
H(z)
=
\sum_{r=0}^{7}z^{-r}E_r(z^8).
\]

从接口上表现为：

\[
\boxed{
8\ SPC/input\ clock
\rightarrow
1\ SPC/output\ clock
}
\]

并且输入输出可以保持同一：

\[
62.5\ {\rm MHz}
\]

PL时钟域，避免额外高速时钟域转换。

内部也可以采用三级：

\[
500
\rightarrow250
\rightarrow125
\rightarrow62.5\ {\rm MS/s}
\]

半带结构优化乘法器资源，但 MATLAB 的系统级功能模型应直接体现“总抽取率8”。

---

# 5. 20 MHz基带的重新定义

定义：

\[
\boxed{
B_{\rm BB}=20\ {\rm MHz}
}
\]

表示 DDC 后实际需要无失真保留的复基带信号频谱。

若信号以零频为中心：

\[
-10\ {\rm MHz}
\le f
\le
+10\ {\rm MHz}.
\]

62.5 MS/s 复采样的 Nyquist 区域为：

\[
-31.25
\le f
<
31.25\ {\rm MHz}.
\]

因此存在很大的滤波过渡带：

\[
10\ {\rm MHz}
\rightarrow
31.25\ {\rm MHz}.
\]

所以：

\[
\boxed{
20\ {\rm MHz\ signal\ bandwidth}
+
62.5\ {\rm MS/s\ complex\ sampling}
}
\]

是合理组合。

采样过采样倍率约为：

\[
\frac{62.5}{20}=3.125.
\]

---

# 6. 新雷达参数不再采用单一固定值

工程应建立“雷达参数族”，而不是只有一个 10 μs、1 MHz、固定PRI的雷达源。

建议基准中心频率：

\[
f_c=2.8\ {\rm GHz}.
\]

对应：

\[
\lambda=\frac{c}{f_c}\approx0.1071\ {\rm m}.
\]

建议设置以下典型模式。

| 模式 | 脉冲 | 带宽 | PRF建议 | CPI | 主要目的 |
|---|---:|---:|---:|---:|---|
| Smoke测试 | 10 μs | 1 MHz | 1 kHz | 4–16 | 快速软件回归 |
| 近程短脉冲 | 1–2 μs | 1–2 MHz | 1–3.3 kHz | 32–64 | 近距离/强天气 |
| 常规天气 | 30–50 μs LFM | 2–5 MHz | 0.8–1.5 kHz | 64 | 常规双偏振 |
| 远程探测 | 80–120 μs LFM | 1–2 MHz | 0.5–0.8 kHz | 64 | 灵敏度/远距离 |
| 强天气高速 | 10–30 μs/LFM | 2–5 MHz | 2–3.3 kHz | 64–128 | 高速更新 |
| 标定仪测试 | 波形跟随雷达 | ≤20 MHz | 全范围 | 可配置 | 验证DRFM通用性 |

必须保持：

\[
T_p<T_{\rm PRI}.
\]

第一不模糊距离：

\[
R_u=\frac{c}{2f_{\rm PRF}}
\]

和 Nyquist 速度：

\[
v_N=\frac{\lambda f_{\rm PRF}}4
\]

均应由配置自动计算并输出，而不能人为假定所有模式均同时获得最大距离和最大速度。

---

# 7. 波形带宽和62.5 MS/s的关系

对于 LFM：

\[
\Delta R
\approx
\frac{c}{2B}.
\]

例如：

\[
B=1\ {\rm MHz}
\Rightarrow
\Delta R\approx150\ {\rm m},
\]

\[
B=2\ {\rm MHz}
\Rightarrow
\Delta R\approx75\ {\rm m},
\]

\[
B=5\ {\rm MHz}
\Rightarrow
\Delta R\approx30\ {\rm m},
\]

\[
B=10\ {\rm MHz}
\Rightarrow
\Delta R\approx15\ {\rm m},
\]

最大20 MHz：

\[
\Delta R\approx7.5\ {\rm m}.
\]

62.5 MS/s 的时间间隔：

\[
T_s=16\ {\rm ns}.
\]

对应双程距离时间栅格：

\[
\Delta R_s
=
\frac{c}{2F_s}
\approx2.40\ {\rm m}.
\]

必须在文档中明确：

\[
\boxed{
2.40\ {\rm m\ sampling\ grid}
\ne
雷达距离分辨率
}
\]

距离分辨率主要由实际信号带宽决定。

---

# 8. 捕获和缓存参数重新设计

所有捕获时序应改成物理时间：

```matlab
cfg.capture.pretrigger_s
cfg.capture.posttrigger_s
cfg.capture.end_hold_s
cfg.capture.max_pulse_s
```

再自动计算：

\[
N=\operatorname{round}(TF_s).
\]

禁止把：

```matlab
end_hold_samples = 4
```

作为独立物理参数长期保存。

因为换采样率以后它代表的时间会发生变化。

---

## 8.1 10 μs波形

62.5 MS/s下：

\[
10\ \mu s\times62.5\ {\rm MS/s}=625
\]

样点。

若：

\[
T_{\rm pre}=2\ \mu s,
\qquad
T_{\rm post}=2\ \mu s,
\]

完整捕获：

\[
14\ \mu s\times62.5\ {\rm MS/s}=875
\]

点。

所以当前2048点bank对于10 μs smoke波形已经足够。

---

## 8.2 必须考虑120 μs长脉冲

如果系统需要覆盖：

\[
T_p=120\ \mu s
\]

并保留前后各2 μs：

\[
N
=
124\ \mu s
\times62.5\ {\rm MS/s}
=
7750.
\]

所以作为普适设计：

\[
\boxed{
N_{\rm bank}\ge8192
}
\]

比较合理。

因此建议把默认：

```matlab
max_samples = 2048
```

分成：

```matlab
algorithm_smoke : 2048
hardware_weather : 8192
```

而不是全工程统一写死。

---

# 9. DMA和DRFM必须继续完全分离

新工程中已经形成的正确原则应继续保持：

\[
\boxed{
DRFM replay
\neq
DMA/storage
}
\]

实时路径：

\[
62.5\ {\rm MS/s}
\rightarrow
本地bank
\rightarrow
目标处理
\rightarrow
DAC
\]

不得依赖 PS、DMA 或上位机是否及时取走数据。

DMA只负责：

- 原始IQ记录；
- PDW；
- 调试；
- 离线分析；
- 无线/有线上传。

即使：

\[
B_{\rm DMA}=0
\]

也不能影响 DRFM 的实际回放时间。

---

# 10. 新延迟模型

DRFM核心公式保持：

\[
\boxed{
\tau_{\rm dev}
=
\frac{2R_v-R_f-R_b}{c}
}
\]

但下一版必须将三个时间明确分开。

目标实际发射时刻：

\[
t_{\rm TX,target}
=
t_{\rm RX}
+
\tau_{\rm dev}.
\]

FPGA命令时刻：

\[
\boxed{
t_{\rm cmd}
=
t_{\rm TX,target}
-
\tau_{\rm fixed}
}
\]

实际射频发射：

\[
\boxed{
t_{\rm TX,actual}
=
t_{\rm cmd}
+
\tau_{\rm fixed}.
}
\]

并要求：

\[
t_{\rm cmd}
\ge
t_{\rm data-ready}.
\]

其中：

\[
t_{\rm data-ready}
\]

必须包含：

- FIR群延迟；
- EOP确认；
- 选档；
- RX校准；
- bank读准备；
- 必需流水延迟。

这样才能严格地区分：

\[
\text{目标物理延迟}
\]

和：

\[
\text{数字处理最小因果延迟}.
\]

---

# 11. MATLAB不直接展开完整4 GS/s主链

下一版应有两个模型层级。

### 系统级主模型

从 RFDC 输出开始：

\[
500\ {\rm MS/s},8SPC
\rightarrow
D=8
\rightarrow
62.5\ {\rm MS/s},1SPC.
\]

用于：

- 捕获；
- 三量程；
- H/V校准；
- 极化矩阵；
- DRFM；
- 距离；
- Doppler；
- A/B平台；
- dataflow；
- 半双工。

### ADC/RFDC专项模型

仅在几个微秒短窗内运行：

\[
4\ {\rm GS/s}.
\]

用于验证：

- RF采样；
- Nyquist zone；
- ADC量化；
- 时钟抖动；
- NCO；
- DDC；
- RFDC抽取；
- 500 MS/s输出。

专项模型必须证明：

\[
\boxed{
4\ {\rm GS/s专项模型输出}
\approx
500\ {\rm MS/s系统级RFDC输入}
}
\]

然后系统级模型无需反复承担4 GS/s计算量。

---

# 12. 建议重新设计配置文件

下一版建议采用：

```matlab
cfg.rf.fc_Hz = 2.8e9;

cfg.baseband.usable_bandwidth_Hz = 20e6;

cfg.adc.fs_real_Hz = 4e9;

cfg.rfdc.output_fs_Hz = 500e6;
cfg.rfdc.samples_per_clock = 8;
cfg.rfdc.interface_clock_Hz = 62.5e6;

cfg.pl.decimation = 8;
cfg.pl.output_fs_Hz = 62.5e6;
cfg.pl.output_samples_per_clock = 1;

cfg.capture.pretrigger_s = 2e-6;
cfg.capture.posttrigger_s = 2e-6;
cfg.capture.end_hold_s = 1e-6;
cfg.capture.max_pulse_s = 120e-6;
cfg.capture.bank_capacity_samples = 8192;
```

配置检查必须自动验证：

\[
500\text{M}
=
62.5\text{M}\times8
\]

以及：

\[
62.5\text{M}
=
500\text{M}/8.
\]

还必须验证：

\[
B_{\rm BB}<F_{\rm core}.
\]

更严格地说，要根据实际FIR通带和阻带确定是否满足抗混叠条件。

---

# 13. 建议建立两套profile

保留快速测试档：

```text
ALGORITHM_SMOKE
```

仍可使用低采样率、小脉冲数，用于CI和代码回归。

新增：

```text
RFSoC_SYSTEM_EQUIVALENT
```

其基准参数为：

\[
4\ {\rm GS/s\ ADC}
\]

\[
500\ {\rm MS/s\ RFDC}
\]

\[
8\ SPC@62.5\ {\rm MHz}
\]

\[
D=8
\]

\[
62.5\ {\rm MS/s},1SPC
\]

\[
20\ {\rm MHz\ usable\ baseband}.
\]

二者必须使用完全相同的：

- DRFM数学模型；
- 极化矩阵；
- 延迟公式；
- 校准参考面；
- 雷达目标模型。

只有采样实现和计算粒度不同。

---

# 14. 下一版必须增加的回归测试

建议至少完成以下测试：

1. 验证

\[
4G/8=500M
\]

以及

\[
500M/8=62.5M.
\]

2. 验证：

\[
8SPC@62.5M
\rightarrow
1SPC@62.5M
\]

时样点顺序和时间戳完全正确。

3. FIR 分块前后结果必须完全一致。

4. ±10 MHz 信号必须位于无失真通带。

5. 31.25 MHz以上进入混叠危险区的信号必须得到规定的阻带抑制。

6. 修改 MATLAB block size 不得改变输出。

7. 10、30、50、80、100、120 μs 波形均不得出现 bank 溢出。

8. 检测参数改变采样率以后对应的物理时间必须保持不变。

9. DMA拥塞不得移动 DRFM 回放时刻。

10. 20、50、100、200 km 等虚拟距离必须满足：

\[
t_{\rm echo}
=
t_{\rm radar-TX}
+
2R_v/c.
\]

11. A/B静止退化必须保持：

\[
B_{\rm static}=A.
\]

12. 对 H/V 分别注入已知幅相误差后，RX校准—目标矩阵—TX校准应恢复规定的最终 Jones 映射。

---

# 15. 推荐实施顺序

**阶段1：采样率和配置重构**

先删除主算法中模糊的统一 `fs` 定义，建立 ADC、RFDC、PL、DRFM 和基带带宽五套独立参数。

**阶段2：RFDC接口模型**

建立真正的：

\[
8\ SPC@62.5\ {\rm MHz}
\]

数据结构，并验证 lane、H/V和三量程的数据顺序。

**阶段3：PL D=8抽取**

将现有独立 FIR/decimator 接入主链，使输出真正成为：

\[
62.5\ {\rm MS/s},1SPC.
\]

**阶段4：DRFM核心迁移**

将检测、capture、calibration、target operator、replay、DAC等全部运行在62.5 MS/s核心时间轴。

**阶段5：雷达参数族**

建立 short pulse、normal LFM、long-range LFM、high-PRF severe-weather 和 calibration 五类profile。

**阶段6：4 GS/s专项模型**

最后补充短窗 ADC/RFDC 高保真模型，不影响系统级长时间仿真效率。

---

# 16. 最终工程基线

下一版正式工程建议统一采用以下主线：

\[
\boxed{
\begin{aligned}
&f_c=2.8\ {\rm GHz}
\\
&B_{\rm BB}=20\ {\rm MHz}
\\
&F_{\rm ADC}=4\ {\rm GS/s}
\\
&F_{\rm RFDC}=500\ {\rm MS/s}
\\
&N_{\rm RFDC}=8\ {\rm SPC}
\\
&F_{\rm PLclk}=62.5\ {\rm MHz}
\\
&D_{\rm PL}=8
\\
&F_{\rm DRFM}=62.5\ {\rm MS/s}
\\
&N_{\rm DRFM}=1\ {\rm SPC}.
\end{aligned}
}
\]

雷达波形不再固定为单一参数，而采用：

\[
1\sim2\ \mu s
\]

短脉冲，以及：

\[
30\sim120\ \mu s
\]

LFM长脉冲；

信号带宽主要取：

\[
1\sim5\ {\rm MHz},
\]

高分辨模式可扩展到：

\[
10\sim20\ {\rm MHz}.
\]

PRF根据距离—速度任务在：

\[
0.5\sim3.3\ {\rm kHz}
\]

范围内配置，CPI默认可采用：

\[
64
\]

脉冲并允许按任务变化。

最终设计原则可以概括成：

\[
\boxed{
20\ {\rm MHz是信号带宽，不是采样率；
500\ {\rm MS/s是RFDC样点率；
62.5\ {\rm MHz是PL接口时钟；
8SPC\rightarrow D8\rightarrow1SPC；
62.5\ {\rm MS/s是DRFM核心速率。
}
}
\]

这样 MATLAB 模型、FPGA 并行接口、DRFM时序和真实 S 波段相控阵气象雷达波形参数之间才能形成统一且可追溯的关系。
