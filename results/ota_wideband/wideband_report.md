# 宽带计量合成示例

资格：SYNTHETIC；无VNA、校准证书、RTL或板卡测量。

## 分数延迟

B定义为复基带[-B/2,B/2]，Fs=62.5MS/s。比较1/2/5/10/20MHz；H/V分别0.37/0.61样点。
LINEAR固定延迟0，其余8tap流式固定延迟4样点；表内误差已扣除理想总延迟。
整捕获随机插值附加延迟0，调用方必须先完成捕获。FARROW为Lagrange多项式浮点结构。
完整幅相、群延迟和极化差分见delay_comparison.csv及PNG。

## 独立频率校准

101个训练频点，80个不同留出频点及不同复极化激励。只有合成测量生成端知道二阶MIMO响应，估计器只收到X/Y。
因果逆FIR 33 taps，固定延迟12样点，留出复误差1.84588e-06。
留出最大幅度误差2.04357e-05 dB、相位误差0.00036002 deg；数字全频域峰值逆增益1.06978。
域仅range=2、T=25°C、P=-30dBm及[-10,10]MHz，未伪造温度/功率扫域。

## 不确定度

26个声明的合成标准不确定度及完整协方差；相关H/V增益、相位与方向图系数0.8。
源顺序见uncertainty_sources.csv；输入协方差、Jacobian与输出协方差均可复算。
功率取H极化；RCS方程为pH+40log10((R+dr)/R)-2(patternH+sH*attitude)。
delay=2dr/c+clock+cable+estimator；frequency=standard+oscillator+estimator。
ZDR=pH-pV+estimator，PhiDP=phaseH-phaseV+estimator；共同项按协方差抵消。
其余完整方程见metrology_budget.m；R=1000m，方向图斜率H/V=0.05/0.03 dB/deg。
扩展不确定度U=k*u，k=2对应正态近似95.45%，不表示实测覆盖资格。
20000次固定seed=7741蒙特卡洛使用非线性RCS距离项，和一阶解析预算比较。

|量|标准u|扩展U|MC标准u|
|---|---:|---:|---:|
|power_h_db|0.10198039|0.20396078|0.10192564|
|delay_ns|0.15100464|0.30200928|0.15155038|
|frequency_hz|0.13747727|0.27495454|0.13580152|
|zdr_db|0.050338852|0.1006777|0.04984688|
|phidp_deg|0.1787736|0.3575472|0.17794332|
|rcs_dbsm|0.10198098|0.20396196|0.10158173|
