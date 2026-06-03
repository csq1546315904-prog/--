# ST 程序块 AI 修改记录

本文档用于记录 `RT_FunctionBlock` 目录下 ST 程序块及相关类型文件的 AI 辅助修改历史，便于后续追踪变更原因、影响范围和验证结果。

## 记录规则

每次由 AI 修改 ST 程序块后，在“修改记录”中追加一条记录，建议包含以下信息：
| 字段 | 说明 |
| --- | --- |
| 日期 | 修改日期，格式建议为 `YYYY-MM-DD` |
| 修改人 | 执行修改的人员或 AI 标识 |
| 关联文件 | 涉及的 `.st`、`.md` 或其他相关文件 |
| 修改目的 | 为什么要改，例如修复问题、优化逻辑、补充注释 |
| 主要变更 | 简要列出核心改动 |
| 验证结果 | 编译、仿真、测试或人工检查结果 |
| 备注 | 风险、待确认事项或后续建议 |

## 修改记录

### 2026-06-03

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `海天_FunctionBlock/prHMI_Error.st` |
| 修改目的 | 从 DEMO.export 摘抄 prHMI_Error 报警处理程序 |
| 主要变更 | 新建 `prHMI_Error.st`，包含查表法报警映射（DrvAlarmMap）、双 VAR 块变量声明、HMI Modbus 地址映射 |
| 验证结果 | 文本核对通过；未在 IndraWorks 中编译 |
| 备注 | 查表法替代传统逐条 IF 判断，增删报警码只需改数组 |

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `海天_FunctionBlock/Modbus_Client_Fanuc.st`、`海天_FunctionBlock/prHMI.st` |
| 修改目的 | 统一两个新增 POU 文件的格式与现有 FB 文件一致 |
| 主要变更 | 章节标题统一（`模块名称`→`程序名称`，`主要流程`→`主要逻辑`）；变量说明从独立章节改为行内 `//` 注释；对齐变量声明格式 |
| 验证结果 | 文本核对通过；未在 IndraWorks 中编译 |
| 备注 | 格式参照 FB_HeightToAngle.st 等现有文件 |

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `海天_FunctionBlock/Readme.md` |
| 修改目的 | 修复 Readme.md 编码乱码，新增 Modbus_Client_Fanuc、prHMI、prHMI_Error 三个 POU 说明 |
| 主要变更 | 从 ST 文件注释重建乱码文档；新增三个 POU 的功能描述、核心逻辑、I/O 表和文件索引；prHMI_Error 章节包含查表法的新手向详细讲解 |
| 验证结果 | 文本核对通过 |
| 备注 | 原始乱码为编码转换错误导致，内容已根据 .st 文件注释和 DEMO.export 重建 |

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `海天_FunctionBlock/prHMI.st` |
| 修改目的 | 从 DEMO.export 导出 prHMI 为独立 POU 文件 |
| 主要变更 | 新建 `prHMI.st`，包含变量声明、地址映射和 `FB_CrankSliderHeight` 实例 |
| 验证结果 | 已创建文件，未编译验证 |
| 备注 | 该 POU 当前仅包含声明性变量 |

### 2026-05-31

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `00_PLC_RT_FunctionBlock/FB_BLINK.st`、`00_PLC_RT_FunctionBlock/FB_CrankSliderHeight.st`、`00_PLC_RT_FunctionBlock/海天冲压程序拆解.md` |
| 修改目的 | 从 AP 工程导出 FB_BLINK、FB_CrankSliderHeight 并纳入项目文档体系 |
| 主要变更 | 新建 `FB_BLINK.st`（TON 闪烁信号发生器）和 `FB_CrankSliderHeight.st`（曲柄连杆正解），按项目统一模板补充功能描述和维护记录；在 `海天冲压程序拆解.md` 中追加两个 FB 说明和文件索引 |
| 验证结果 | 文本核对通过；未在 IndraWorks 中编译 |
| 备注 | FB_CrankSliderHeight 与 FB_HeightToAngle 互为逆运算，RR/L 默认值必须一致 |

### 2026-05-31

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `00_PLC_RT_FunctionBlock/FB_Toggle.st`、`00_PLC_RT_FunctionBlock/海天冲压程序拆解.md` |
| 修改目的 | 从 AP 工程导出 FB_Toggle 并纳入项目文档体系 |
| 主要变更 | 新建 `FB_Toggle.st`，按项目统一模板补充功能描述、主要逻辑、维护注意和历史修改记录；在 `海天冲压程序拆解.md` 中追加 FB 说明和文件索引 |
| 验证结果 | 文本核对通过；未在 IndraWorks 中编译 |
| 备注 | Set > Reset > Key 翻转优先级，适用于 HMI 按钮或物理按键状态切换 |

### 2026-05-31

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `00_PLC_RT_FunctionBlock/FB_HeightToAngle.st`、`00_PLC_RT_FunctionBlock/海天冲压程序拆解.md` |
| 修改目的 | 从 AP 工程导出 FB_HeightToAngle 并纳入项目文档体系 |
| 主要变更 | 新建 `FB_HeightToAngle.st`，按项目统一模板补充功能描述、主要逻辑、维护注意和历史修改记录；在 `海天冲压程序拆解.md` 中追加 FB 说明和文件索引 |
| 验证结果 | 文本核对通过；未在 IndraWorks 中编译 |
| 备注 | 曲柄连杆运动学转换功能块，曲柄半径 RR=16.0 mm，连杆长度 L=220.0 mm |

### 2026-05-17

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `00_PLC_RT_FunctionBlock/prMultiplex_02.st` |
| 修改目的 | 保持 X 方向漂移为整条曲线整体偏移估算，同时优化偏移闭环触发和回写条件 |
| 主要变更 | `FB_CurveDriftEstimator` 触发源由 `fbCollector.bRunDone` 调整为 `fbCollector.bMonitorRunDone`，避免 baseline 学习轮次参与漂移估算；`lrMonitorPosOffset` 仅在 `FB_Curve.bNewOffsetDone AND FB_Curve.bOffsetValid` 时回写 |
| 验证结果 | 文本核对通过；未在 IndraWorks 中编译 |
| 备注 | 漂移算法仍为全局曲线平移匹配，不做局部尖峰逐点漂移 |

### 2026-05-17

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `00_PLC_RT_FunctionBlock/FB_EnergyCollectorMonitor.st`、`00_PLC_RT_FunctionBlock/prMultiplex_02.st` |
| 修改目的 | 与 HMI 显示单位修正保持一致，避免 `delta` 在原始能量单位下过小 |
| 主要变更 | PLC 监控仍按 `baseline ± (baseline * ratio + delta)` 计算；由于 PLC 使用原始能量单位，默认和 `prMultiplex_02` 预设改为 `rBrokenDelta=500000`、`rWearDelta=800000` |
| 验证结果 | 文本核对通过；Base=178 显示单位等价于原始 Base=178000 时，Wear H 显示值为 1,031.4 |
| 备注 | HMI 侧仍填写显示单位 `500/800`，内部乘以 1000 后与 PLC 原始单位一致 |

### 2026-05-17

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `00_PLC_RT_FunctionBlock/FB_EnergyCollectorMonitor.st`、`00_PLC_RT_FunctionBlock/prMultiplex_02.st` |
| 修改目的 | 在 HMI 验证 ratio/delta 复合阈值机制后，同步 PLC 功能块默认值和实例预设 |
| 主要变更 | 确认 HMI 与 PLC 均按 `baseline ± (baseline * ratio + delta)` 计算阈值；将 `FB_EnergyCollectorMonitor` 默认 `rBrokenDelta` 调整为 `500.0`、默认 `rWearDelta` 调整为 `800.0`；`prMultiplex_02` 预设保持 `rBrokenRatio=0.7`、`rBrokenDelta=500`、`rWearRatio=0.3`、`rWearDelta=800` |
| 验证结果 | 文本核对通过；未在 IndraWorks 中编译 |
| 备注 | Base=0 时断刀低限夹到 0，磨损高限为 800；HMI `/1000` 整数显示时该差值约显示为 `+1` |

### 2026-05-15

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `00_PLC_RT_FunctionBlock/prMultiplex_02.st` |
| 修改目的 | 调整断刀/磨损监控绝对阈值 |
| 主要变更 | 将 `rBrokenDelta` 从 200 调整为 500；将 `rWearDelta` 从 100 调整为 800 |
| 验证结果 | 文本检查通过，未在 IndraWorks 中编译 |
| 备注 | HMI 常量已同步调整为 `BrokenMonitorDelta=500`、`WearMonitorDelta=800` |

### 2026-05-15

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `00_PLC_RT_FunctionBlock/FB_EnergyCollectorMonitor.st`、`00_PLC_RT_FunctionBlock/海天冲压程序拆解.md` |
| 修改目的 | 按偏差方向区分监控报警语义 |
| 主要变更 | 将低于 baseline 下限的异常用于断刀/缺切报警；将高于 baseline 上限的异常用于磨损/过载预警；保留上下限阈值输出用于 HMI 显示 |
| 验证结果 | 文本结构检查通过，未在 IndraWorks 中编译 |
| 备注 | HMI 监控区显示仍可保留上下限，PLC 报警方向以低侧断刀、高侧磨损为准 |

### 2026-05-10

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `RT_FunctionBlock/ChangeLog_ST.md` |
| 修改目的 | 初始化 ST 程序块 AI 修改记录文档 |
| 主要变更 | 创建变更记录模板，约定后续 AI 修改记录格式 |
| 验证结果 | 文档结构检查通过 |
| 备注 | 后续修改 ST 程序块时，在本节顶部追加新记录 |

## 记录模板

```markdown
### YYYY-MM-DD

| 字段 | 内容 |
| --- | --- |
| 修改人 | Codex |
| 关联文件 | `RT_FunctionBlock/xxx.st` |
| 修改目的 |  |
| 主要变更 |  |
| 验证结果 |  |
| 备注 |  |
```
