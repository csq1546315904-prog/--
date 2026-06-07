# 海天冲压程序拆解

本文档用于记录从海天冲压机 PLC 工程中拆解提取的 ST 功能块，说明各功能块的用途、核心逻辑和调用关系，方便后续理解、复用或移植到其他 PLC 程序中。

## 1. 功能块清单

### `FB_HeightToAngle`

文件：`FB_HeightToAngle.st`

用于将曲柄连杆机构中滑块的直线位移（高度 mm）转换为曲柄转角（角度 °），属于运动学逆解计算。

核心思路：
1. 对输入高度 `HeightMM` 做钳位，限制在 `[0, 2*RR]` 即机构物理行程范围内。
2. 以曲柄最低点（180°）为基准，计算滑块相对曲柄旋转中心的绝对位置 `xll = HeightMM + y_min`，其中 `y_min = -RR + L`。
3. 利用余弦定理求解曲柄角：
   ```
   L² = RR² + xll² - 2·RR·xll·cos(θ)
   cos(θ) = (xll² + RR² - L²) / (2·RR·xll)
   ```
4. 对 `cos(θ)` 钳位至 `[-1, 1]`，防止浮点误差导致 ACOS 越界。
5. 通过 `ACOS(k)` 计算弧度角并转换为度数输出。

机构参数：
| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `RR` | 16.0 mm | 曲柄半径 |
| `L` | 220.0 mm | 连杆长度 |

输入输出：
| 信号 | 类型 | 说明 |
| --- | --- | --- |
| `HeightMM` (IN) | REAL | 滑块高度，范围 0 ~ 2*RR（即 0 ~ 32 mm） |
| `AngleDeg` (OUT) | REAL | 曲柄角度，范围 0 ~ 180°（0° 上死点，180° 下死点） |

### `FB_CrankSliderHeight`

文件：`FB_CrankSliderHeight.st`

用于将曲柄转角（角度 °）转换为滑块直线位移（高度 mm），属于曲柄连杆机构运动学正解，与 `FB_HeightToAngle` 互为逆运算。

核心思路：
1. 将输入角度 `AngleDeg` 由度数转换为弧度。
2. 使用正解公式计算滑块高度：
   ```
   HeightMM = RR + RR·cos(θ) + √(L² - (RR·sin(θ))²) - L
   ```
3. 0°（上死点）对应 32 mm，180°（下死点）对应 0 mm。

机构参数（需与 `FB_HeightToAngle` 保持一致）：
| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `RR` | 16.0 mm | 曲柄半径 |
| `L` | 220.0 mm | 连杆长度 |

输入输出：
| 信号 | 类型 | 说明 |
| --- | --- | --- |
| `AngleDeg` (IN) | REAL | 曲柄角度，范围 0 ~ 180° |
| `HeightMM` (OUT) | REAL | 滑块高度，范围 0 ~ 32 mm |

### `FB_Toggle`

文件：`FB_Toggle.st`

带置位/复位优先的按键翻转功能块，用于 HMI 按钮或物理按键的状态切换。

核心思路：
1. 优先级链：`Set`（最高）> `Reset`（次之）> `Key` 上升沿翻转（最低）。
2. Set 为 TRUE 时直接置位 `Out`。
3. Reset 为 TRUE 且 Set 为 FALSE 时复位 `Out`。
4. 无 Set/Reset 时，检测 `Key` 上升沿（`Key AND NOT prevKey`），翻转 `Out`。
5. 每周期更新 `prevKey` 用于下一周期上升沿判断。

主要输入输出：
| 信号 | 类型 | 说明 |
| --- | --- | --- |
| `Set` (IN) | BOOL | 强制置位，优先级最高 |
| `Reset` (IN) | BOOL | 强制复位，优先级次于 Set |
| `Key` (IN) | BOOL | 按键输入，上升沿翻转输出 |
| `Out` (OUT) | BOOL | 翻转后的输出状态 |

### `FB_BLINK`

文件：`FB_BLINK.st`

基于 TON 定时器的闪烁信号发生器，使能时输出占空比 50% 的周期性方波信号。

核心思路：
1. `Enable = FALSE` 时，输出 `Q` 复位，定时器和内部状态均清零。
2. `Enable = TRUE` 时，启动 TON 定时器，定时时间为 `Period / 2`（半个周期）。
3. 定时器到达后翻转内部状态 `State`，并复位定时器重新计时，形成自循环。
4. 输出 `Q` 跟随内部状态，产生亮暗各半的方波。

主要输入输出：
| 信号 | 类型 | 说明 |
| --- | --- | --- |
| `Enable` (IN) | BOOL | 使能信号，TRUE 启动闪烁 |
| `Period` (IN) | TIME | 闪烁周期，亮暗各占一半（如 T#1s = 0.5s 亮 + 0.5s 暗） |
| `Q` (OUT) | BOOL | 闪烁方波输出 |

### `Modbus_Client_Fanuc`

文件：`Modbus_Client_Fanuc.st`

Modbus TCP 客户端程序，用于与 Fanuc 控制器建立 TCP 连接，轮询读取指定 Modbus 寄存器并将数据缓存到 PLC 内部变量。

核心思路：
1. 检查 `Modbus_TCP_Set_0` 是否已连接，未连接则发起 TCP 连接。
2. 连接成功后，通过 `MB_RW` 触发信号发起 `Modbus_TCP_Read_0` 读取操作。
3. 读取完成后将数据写入 `rdata[0..9]` 缓存，同时清除 `MB_RW`。
4. `RW` 定时器控制轮询间隔（建议 100ms），避免网络过载。
5. 读取失败时 `error` 置 TRUE 并记录 `errorid` 错误码。

主要输入输出：
| 信号 | 类型 | 说明 |
| --- | --- | --- |
| `ip` | ARRAY[0..3] OF BYTE | Fanuc 目标 IP，默认 172.16.10.11 |
| `MB_RW` | BOOL | 读请求触发信号 |
| `rdata` | ARRAY[0..9] OF WORD | 读取结果缓存 |
| `busy` | BOOL | 传输中标志 |
| `error` | BOOL | 错误标志 |
| `errorid` | WORD | 错误码 |

### `prHMI`

文件：`prHMI.st`

HMI/PLC 数据接口程序，定义 HMI 交互变量和内存地址映射，包含一个 `FB_CrankSliderHeight` 功能块实例。当前仅有变量声明，无程序体逻辑。

核心思路：
1. 通过 `AT %MW...` / `AT %MD...` 语法将内部变量映射到 PLC 内存地址。
2. HMI 通过对应地址读写这些变量，实现数据交换。
3. `FB_CrankSliderHeight_1` 实例将 HMI 输入的高度转换为曲柄角度。

主要输入输出：
| 信号 | 类型 | 地址 | 说明 |
| --- | --- | --- | --- |
| `Vel_Gain` | REAL | %MD1000 | 速度增益 |
| `iPunchSpeed` | WORD | %MW1214 | 冲压速度 |
| `wActPos` | REAL | %MD1220 | 当前位置 |
| `wPunHeight_mm` | WORD | %MW1224 | 冲压高度 |
| `FB_CrankSliderHeight_1` | FB 实例 | — | 曲柄连杆高度转换 |

### `prHMI_Error`

文件：`prHMI_Error.st`

报警处理程序。把驱动器报警码和 PLC 内部报警统一收拢，转为 HMI 能直接显示的报警位。

**新手先看这里——这个程序特别在哪？**

传统的报警处理，每种报警码写一条判断：

```
IF DrvAlarmCode = 34 THEN AlarmBits[0] := TRUE; END_IF
IF DrvAlarmCode = 35 THEN AlarmBits[1] := TRUE; END_IF
...（有 37 种报警就要写 37 条）
```

这个程序用了 **查表法**：把 37 个报警码预先存进一个数组 `DrvAlarmMap`，然后用一个 FOR 循环遍历匹配。以后要增删报警码，只改数组、不改逻辑。数组还单独放在第二个 VAR 块里，一眼就能区分"配置数据"和"运行时变量"。

**核心思路（4 步走）：**

1. **清零** — 每周期先把 100 个 `AlarmBits[*]` 全清 FALSE。这步很关键：如果上一周期的报警消失了，不清零的话 HMI 上会一直残留显示。
2. **查表匹配** — 遍历 `DrvAlarmMap` 数组，如果 `DrvAlarmCode` 匹配到某个值，就置位对应下标的 `AlarmBits[i]`。下标 i 和 HMI 错误号一一对应：`i=0 → Er034, i=1 → Er035, ..., i=36 → Er160`。
3. **内部报警** — 超温、急停等 PLC 自己判断的报警，直接写到固定编号的位上（如 `AlarmBits[41]` = 超温）。
4. **输出到 HMI** — 把 BOOL 数组转写到 `HmiAlarm`（WORD 数组，映射在 `%MW1400~%MW1499`）。HMI 通过 Modbus 读这片地址，哪个 WORD 是 1 就亮对应的报警灯。

**变量速查：**

| 变量 | 类型 | 地址 | 作用 |
| --- | --- | --- | --- |
| `DrvAlarmCode` | UINT | %IW16 | 驱动器通过 PDO 传来的报警码，只看低 8 位 |
| `DrvAlarmMap` | ARRAY[0..36] OF BYTE | — | 查表用的报警码清单，下标对应 Er034~Er160 |
| `AlarmBits` | ARRAY[0..99] OF BOOL | — | 内部报警位（PLC 逻辑用 BOOL 更方便） |
| `HmiAlarm` | ARRAY[0..99] OF WORD | %MW1400 | 输出给 HMI 的报警区（HMI 只能读 WORD） |
| `bDriveError` | BOOL | — | 综合报警标志，任意报警时置 TRUE，可接报警灯 |

**关键概念解释：**

- **`AT %IW16`**：把变量直接"贴"到 PLC 的物理输入地址上。`%I` 表示输入区，`W` 表示 WORD，`16` 是偏移。驱动器发来的报警码不用写任何通信代码，PLC 硬件层自动刷新到这个地址。
- **`AT %MW1400`**：同理，把数组"贴"到 Modbus 保持寄存器区。HMI 读 `%MW1400` 就是读 `HmiAlarm[0]`，PLC 这边改了数组值，HMI 刷新时自动看到。
- **为什么用两个 VAR 块？**：IEC 61131-3 允许一个 POU 里写多个 VAR 块。第一个放"每周期会变的运行时变量"，第二个放"固定不变的配置表"。打开文件时配置数据位置固定、不会淹没在业务变量里。

### `prModusTcp_Fanuc`

文件：`prModusTcp_Fanuc.st`

与 Fanuc 机器人控制器的 Modbus TCP 通信 POU，负责 TCP 连接管理、寄存器读写，并集成高度→角度转换和呼吸灯功能。

核心思路：
1. 通过 `Modbus_TCP_Set_0` 管理 TCP 连接状态。
2. 通过 `Modbus_TCP_Read_0` 读取 Fanuc 寄存器数据到 `rdata[0..9]`。
3. 通过 `Modbus_TCP_Write_0` 将 `wdata[0..9]` 写入 Fanuc 寄存器。
4. 6 个 `FB_HeightToAngle` 实例分别对应 iPTE/iPOP/iPUP/iReady/iPSP1/iPSP2 工位，将 Fanuc 发来的高度值转换为旋转角度。
5. `FB_BLINK_Idle` 用于空闲状态呼吸灯指示。

主要输入输出：
| 信号 | 类型 | 说明 |
| --- | --- | --- |
| `ipFanuc` | ARRAY[0..3] OF BYTE | Fanuc 目标 IP，默认 172.16.10.11 |
| `rdata` | ARRAY[0..9] OF WORD | 读取 Fanuc 寄存器缓存 |
| `wdata` | ARRAY[0..9] OF WORD | 待写入 Fanuc 寄存器的数据 |
| `bRead` / `bWrite` | BOOL | 读/写触发信号 |
| `iReady_deg` | REAL | 换模位置 ready 信号角度 |

> 注意：DEMO.export 中该 POU 仅有 VAR 声明块，ST 逻辑体需现场补充。

## 2. 新手导读：两个通讯文件该怎么用？

如果你刚接触 PLC 通讯，面对 `Modbus_Client_Fanuc` 和 `prModusTcp_Fanuc` 两个文件，按下面三步走：

### 第一步：先搞清楚两个文件的区别

| 对比维度 | Modbus_Client_Fanuc | prModusTcp_Fanuc |
| --- | --- | --- |
| 数据方向 | **只读**（Fanuc → PLC） | **读写双向**（Fanuc ↔ PLC） |
| 核心功能 | 建立连接 + 周期读取寄存器 | 建立连接 + 读取 + 写入 + 数据加工 |
| 附带功能 | 无 | 6 个高度→角度转换 + 呼吸灯 |
| 代码完整度 | 有伪代码骨架，可直接补全 | 仅 VAR 声明，需从零写 ST 逻辑 |
| 适合谁 | 新手入门、只需监视数据 | 需要双向控制、做运动学转换 |
| 学习建议 | **先看这个**，搞懂再碰另一个 | 看懂第一个后再来，你会发现只是多了"写" |

### 第二步：搞清楚 Modbus TCP 通讯的通用流程

不管哪个文件，Modbus TCP 通讯就是三步循环：

```
① 建立 TCP 连接 ──→ ② 发请求/收数据 ──→ ③ 等一段时间再发下一次
     ↑                                        │
     └──────────── 断了就重连 ←────────────────┘
```

| 步骤 | 用的功能块 | 只做一次还是反复做 |
| --- | --- | --- |
| 建立连接 | `Modbus_TCP_Set` | 连上之后就不用再调了（除非断线） |
| 读取数据 | `Modbus_TCP_Read` | **周期调用**，比如每 100ms 一次 |
| 写入数据 | `Modbus_TCP_Write` | 需要写的时候才调用，不要一直写 |
| 节拍控制 | `TON` 定时器 | 限制请求频率，防止网络拥塞 |

### 第三步：拿到文件后你要做的事

1. **改 IP 地址** — 把 `ip`/`ipFanuc` 改成你实际 Fanuc 的 IP
2. **确认寄存器地址** — 问 Fanuc 那边的人：寄存器从几号开始？要读几个？
3. **补全 ST 逻辑** — 两个文件的程序体现在都还是注释/伪代码状态，需要你参照伪代码写出真正的 ST 程序
4. **在 Task 中调用** — 把 POU 拖到周期任务里（比如 10ms 周期），PLC 才会执行它
5. **编译 + 在线看数据** — 编译通过后下载到 PLC，在线监控 `rdata[]` 看数据有没有进来

### 核心概念速查

| 概念 | 大白话解释 |
| --- | --- |
| Modbus TCP | 通过网线读写对方寄存器的一种工业协议，几乎所有机器人都支持 |
| 寄存器 | 可以理解成 Fanuc 内存里的"小格子"，每个格子存一个 16 位整数（WORD） |
| Socket | TCP 连接的"门牌号"，连上后拿到这个号，后续读写都要用它 |
| `rdata` / `wdata` | 读缓存 / 写缓存，读回来的值放 rdata，要写出去的值先填进 wdata |
| TON 定时器 | 一个倒计时器，到时间自动把输出置 TRUE，用来控制"多久读一次" |

> 看完还是不确定用哪个？**先选 Modbus_Client_Fanuc 试试**。它是纯读的，不会改 Fanuc 的数据，出不了大事。等读通了再考虑用 prModusTcp_Fanuc 加写功能。

## 3. 文件索引

| 文件 | 说明 |
| --- | --- |
| `FB_HeightToAngle.st` | 滑块高度→曲柄角度运动学逆解 |
| `FB_CrankSliderHeight.st` | 曲柄角度→滑块高度运动学正解 |
| `FB_Toggle.st` | 带置位/复位优先的按键翻转功能块 |
| `FB_BLINK.st` | 基于 TON 的闪烁信号发生器 |
| `Modbus_Client_Fanuc.st` | Modbus TCP 客户端 — Fanuc 寄存器读取 |
| `prHMI.st` | HMI 数据接口 — 变量声明与地址映射 |
| `prHMI_Error.st` | 报警处理程序 — 查表法映射驱动器报警码到 HMI |
| `prModusTcp_Fanuc.st` | Modbus TCP 通信 — Fanuc 寄存器读写与高度角度转换 |
| `Readme.md` | 本文档 |
| `ChangeLog_ST.md` | ST 程序块 AI 修改记录 |
