> 本文为初版设计或验证记录。4gps 分支的最新采样体系、捕获时序及验收结果见 [4gps修改报告](4gps修改报告.md)；初版测试数量和运行记录保留作历史追溯。

# 几何、方向图与传播实现报告

## 支持范围

- `+rtsim/+geometry`：基础 MATLAB 实现 WGS-84 大地坐标到 ECEF、固定站点 ECEF 到 ENU、北起顺时针 ENU 方位/水平仰角、右手观察坐标架、标量优先的 `[w x y z]` 四元数姿态与安装/波束坐标架，以及 ENU/NED 三维方向到 MATLAB az-el、北基 az-el、数学 theta-phi 的转换。
- `solve_retarded_geometry`：雷达与设备轨迹均可由真值或预测函数句柄提供。去程在固定 `t0` 发射位置与迭代的 `t1` 设备位置间求光行时；回程在 `t2` 设备发射位置与迭代的 `t3` 雷达位置间独立求解，并分别输出四个事件位置、距离、视线和径向速度。设备周转时间或指定发射时刻单独入账。
- `+rtsim/+pattern`：支持 `IDEAL` 恒等 Jones 模型和 `MEASURED_CSV`。CSV 必须含 `az_deg,el_deg,freq_Hz`，并含八列 `Jij_re/Jij_im` 复数据或四列 `Jij_mag` 幅度数据。原表保存在 `patterns.raw`。复 Jones 在测量角频包络内按最多八个邻点作周期方位反距离插值，包络外拒绝外推。
- 方向图资格检查覆盖相位完整性、完整 2×2 Jones、角域、频域、远场最小距离和 Jones 条件数。只有幅度数据时可用于幅度近似，不签发相位或完整极化资格。
- 离线方向图工具支持显示专用扫描/接收积分、在实现增益口径充分时恢复绝对幅度、从方位/仰角切面作三维幅度近似，以及按 HSV 指定颜色从带完整轴像素元数据的 PNG 提取轨迹。显示结果保存未修改的 `Pattern_raw`；图片和切面结果均不生成复相位，三维重构固定标记 `APPROX_AMPLITUDE_ONLY`。
- `+rtsim/+channel`：支持静态直达、水平面镜像反射、有限点散射体双站路径、复矩阵路径叠加，以及 `OTA`/`CABLE` 顶层。每个 `path.delay_s` 是标量，每个 `path.matrix` 是含路径幅度、载频相位和 Jones 算子的 2×2 复矩阵。
- 输入/输出均为 N×2 的 `sqrt(W)` 复功率波。直达路径采用 `Jrx * lambda/(4*pi*R) * exp(-j*2*pi*R/lambda) * Jtx`，不在传播标量中重复加入天线增益。
- `combine_complex_paths` 使用 `grid.fs_Hz`，保存跨块历史并以过去和当前可用样点作因果线性分数延迟。状态字段包括 `history`、`delay_samples`、`interpolation` 和带宽说明。

## 接口与约定

`channel_step(in, st, channelCfg, geometry)` 的 `channelCfg` 要求 `fc_Hz`、`fs_Hz`、`kind`。`CABLE` 还要求 `cable_gain`、`cable_delay_s`；`OTA` 可带 `reflection.enabled/coefficient/height_m`。`geometry` 要求 3×1 的 `tx_position_m/rx_position_m`，可带 `tx_jones/rx_jones`，缺省为 `eye(2)`。

`channel_step` 明确表示单程传播。主控应为去程和回程分别维护状态实例。当前几何在一个输入块内冻结，短块运动近似由主控负责；这里没有实现迟滞时刻求解、连续多普勒或块内变距离传播。

镜像路径的 `coefficient` 是用户给定的复场反射系数，属于明确简化模型，没有从介电常数计算 Fresnel s/p 系数。双站散射的 `effective_area_m2` 作为等效双站散射截面积，并使用雷达方程的场幅归一化。

线性分数延迟适用于相对 Nyquist 充分带限的复包络；接近 Nyquist 时存在幅度下垂和相位误差。它是持续状态的因果实现，不读取整块之后的未来样点。更高保真宽带传播需要单独的多相 FIR/Farrow 设计和误差预算。

## 验证

`tests/GeometryChannelTest.m` 和 `tests/ExtendedGeometryTest.m` 是 `matlab.unittest.TestCase` 类式测试，覆盖坐标基准、批量 ENU、方向退化、姿态滚转、方向约定、Friis/Jones 单径、镜像和双站路径、跨块 1.5 样点延迟、OTA/电缆顶层、理想/CSV Jones 插值、缺相位资格拒绝、运动轨迹光行时、原始方向图不变、绝对增益依据不足拒绝、幅度重构标记和缺图片拒绝。MATLAB R2025a 实机最终结果：本职责域 16 项通过、0 项失败、0 项未完成，所有几何、方向图和信道文件 `checkcode` 诊断为 0。全工程并行测试当时另有端到端、数据流和前端模块失败，不属于本报告实现范围。
