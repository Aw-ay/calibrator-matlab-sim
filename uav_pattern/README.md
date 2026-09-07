# 远场输入元数据

原始文件 `farfield_resolution1deg.txt` 保持未修改。

| 字段 | 当前信息 |
|---|---|
| 载频 | 2.8 GHz，用户确认 |
| 激励 | UAV H/V 两端口同时激励，用户确认 |
| H/V 相对幅度和相位 | 未确认 |
| Horizontal/Vertical 极化基 | 未确认；示例仅假设 Ludwig-3 |
| 相位参考原点、端口参考面、归一输入功率 | 未确认 |
| 独立激励数量 | 1，不能辨识完整 2×2 Jones |
| 网格 | theta 0:1:180，phi 0:1:359，共 65,160 点 |

依次为 theta、phi、总实现增益、Horizontal 增益及相位、Vertical 增益及相位、轴比。
增益单位 dBi，相位单位度。解析器保留复幅相，并记录源文件 SHA-256。

提供两份线性独立激励的远场及其复激励矩阵后，可通过 `cfg.files` 和 `cfg.excitation_matrix` 恢复完整 Jones。
仅确认两端口等幅同相仍只能确定一个激励向量，不会增加独立方程数量。
