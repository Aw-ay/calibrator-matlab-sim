# 事件、捕获与重放调度行为接口报告

## 新增接口

- `rtsim.sim.step_event_engine`：请求带 `available_tick`、`priority`、`type` 和 `payload`。引擎保存跨块队列，只派发当前网格末 tick 之前可用的事件，并按可用 tick、数值优先级、进入队列顺序稳定排序。同一 tick 不依赖 MATLAB 结构数组的偶然顺序。
- `rtsim.capture.capture_pingpong_step`：把完整 N×2×range RAW 捕获冻结到空闲 bank。描述符携带 `bank_id` 与单调递增的 `bank_generation`；消费者引用未清零时 bank 保持 busy，无空闲 bank 时记录丢弃，不覆盖已有内容。
- `rtsim.capture.consumer_arbiter_step`：所有消费者共享一个 `budget_bytes` 端口预算，优先级固定为 REPLAY、ANALYSIS、DMA。每次请求校验 bank id、generation 和 busy 状态；完成消费者请求后只释放对应引用，全部引用结束才释放 bank。
- `rtsim.capture.edge_fuse_2_8`：明确区分半功率与半幅阈值，先扣噪声功率基线，再融合两点阈值插值与最多八点的局部直线拟合。输出非零协方差；无交叉、平坦或局部数据不足时返回 `valid=false, quality=LOW` 和原因。
- `rtsim.capture.pdw_reference_map`：对尚未登记的增益和时延补偿各应用一次，并将补偿 ID 写入 `applied_compensations`。已在 IQ 中应用或已登记的补偿不会再次作用，输出参考面随校准估计更新。
- `rtsim.replay.replay_scheduler_step`：命令按 pulse id 关联描述符，校验 ready tick 和当前 bank generation。单读端口占用时将后续重放稳定排到前一任务结束，超出当前网格的任务保留到后续调用，不提前派发。

## 与当前核心的关系

现有 `instrument_core_step` 已内联实现捕获、bank busy、回放优先于 DMA 服务和数据 ready 检查的简化同等职责。本报告接口是可单测的独立行为模型，供扩展和逐项验收使用；本次没有重构或替换现有核心，也没有启用任何未确认 optional 分支。

## 限制

这些接口是行为级模型，不模拟双口 RAM 的逐拍握手、AXI burst、CDC 或真实 DDR 仲裁。`edge_fuse_2_8` 的八点模型是局部线性边沿，曲线明显非线性时其协方差只表示该局部模型残差。PDW 参考映射要求调用方提供稳定且唯一的补偿 ID。

## 验证

`tests/CaptureSchedulerTest.m` 覆盖未来事件不提前、同 tick 稳定排序、busy bank 不覆盖、回放硬优先与共享预算、边沿融合及低质量退化、补偿只登记一次、generation/ready/single-port 排队。MATLAB R2025a 最终结果：6 项通过、0 项失败、0 项未完成；新增接口 `checkcode` 诊断为 0。
