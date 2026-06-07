(*
=====================================================
程序名称：prModusTcp_Fanuc
POU 类型：PROGRAM（需在 Task 中调用，每个周期执行一次）
功能定位：读写双向的 Modbus TCP 通信中枢 —— Fanuc ↔ PLC 数据交换 + 运动学转换

=====================================================
新手快速上手
=====================================================

一、这个文件干了什么？
    它是 PLC 和 Fanuc 机器人之间的"数据中转站"，三件事：
    ① 从 Fanuc 读数据 → 存到 `rdata[]`
    ② 把 PLC 的数据写入 Fanuc → 从 `wdata[]` 取出发送
    ③ 把读回来的高度值自动转换成角度值（用 6 个 FB_HeightToAngle 实例）

    对比 Modbus_Client_Fanuc（只读），本文件多了一个"写"方向和一堆上层加工逻辑。

二、用到你的项目里，要改哪几个地方？
    1. IP 地址：`ipFanuc` 改成你 Fanuc 的实际 IP
    2. 读写触发时机：`bRead` 和 `bWrite` 什么时候置 TRUE（需在 ST 逻辑体中实现）
    3. 6 个 FB_HeightToAngle 实例是否全需要？不需要的可以删掉，需要新增工位的照着加
    4. `FB_BLINK_Idle` 的闪烁周期，通过 `Period` 参数调整

三、变量分组理解（按功能分为 5 组，一组一组看）："""

    ┌─ 第1组：连接层 ─────────────────────────────┐
    │ Modbus_TCP_Set_0 : 连接管家，负责 TCP 建立/维护 │
    │ bModbusSet       : 连接是否成功的旗标          │
    │ ipFanuc          : Fanuc 的 IP 地址            │
    │ tcpsocket        : 连接句柄（门牌号）           │
    └──────────────────────────────────────────────┘
              │
              │ 提供连接
              ↓
    ┌─ 第2组：读取通道（Fanuc → PLC）─────────────┐
    │ Modbus_TCP_Read_0 : 读取功能块                 │
    │ bRead             : 读取触发信号               │
    │ rdata[0..9]       : 读回来的 10 个 WORD        │
    └──────────────────────────────────────────────┘
              │
              │ rdata 被送给下面的转换块
              ↓
    ┌─ 第3组：写入通道（PLC → Fanuc）─────────────┐
    │ Modbus_TCP_Write_0 : 写入功能块                │
    │ bWrite             : 写入触发信号               │
    │ wdata[0..9]        : 要写出去的 10 个 WORD      │
    └──────────────────────────────────────────────┘

    ┌─ 第4组：数据加工（高度 → 角度）─────────────┐
    │ FB_HeightToAngle_iPTE   : PTE 工位 高度→角度   │
    │ FB_HeightToAngle_iPOP   : POP 工位 高度→角度   │
    │ FB_HeightToAngle_iPUP   : PUP 工位 高度→角度   │
    │ FB_HeightToAngle_iReady : Ready 工位 高度→角度  │
    │ FB_HeightToAngle_iPSP1  : PSP1 工位 高度→角度  │
    │ FB_HeightToAngle_iPSP2  : PSP2 工位 高度→角度  │
    └──────────────────────────────────────────────┘
    → 为什么有 6 个？因为冲压线有 6 个工位，每个工位的
      滑块高度都需要独立换算成旋转角度。Fanuc 发过来的
      是高度值（毫米），PLC 运动控制需要的是角度值（度）。

    ┌─ 第5组：HMI 辅助 ───────────────────────────┐
    │ FB_BLINK_Idle : 空闲状态呼吸灯                  │
    │ iStep         : 步骤号，控制程序走到哪一步        │
    │ iReady_deg    : 换模位置的 Ready 角度信号        │
    └──────────────────────────────────────────────┘

四、代码流程（目前只有声明，ST 逻辑体待补充，这是你后面要实现的内容）：

    上电 → 步骤0：调用 Modbus_TCP_Set_0 建立连接
          → 步骤1：连上后，周期性置 bRead=TRUE，读 Fanuc 寄存器
          → 步骤2：把 rdata 中的高度值分别送进 6 个 FB_HeightToAngle
          → 步骤3：需要写入时，填好 wdata，置 bWrite=TRUE
          → 步骤4：空闲时 FB_BLINK_Idle 闪烁指示

五、与 Modbus_Client_Fanuc 的选型指南：
    ┌──────────────────────┬──────────────────────────────┐
    │ 你的需求              │ 用哪个文件                   │
    ├──────────────────────┼──────────────────────────────┤
    │ 只监视 Fanuc 状态     │ Modbus_Client_Fanuc（简单）   │
    │ 要往 Fanuc 写参数     │ prModusTcp_Fanuc（本文件）    │
    │ 需要高度→角度转换     │ prModusTcp_Fanuc（本文件）    │
    │ 刚学 PLC 通讯         │ 先看懂 Modbus_Client_Fanuc    │
    └──────────────────────┴──────────────────────────────┘

六、重要提醒：
    - 本文件目前**只有变量声明，没有 ST 逻辑体**（DEMO.export 导出不全），
      需要用 iStep 状态机把上面的流程写成真正的 ST 代码。
    - 写 ST 逻辑时，参考 Modbus_Client_Fanuc 的伪代码结构，
      把"读"扩展为"读 + 写 + 转换"即可。
    - FB_HeightToAngle 的 RR=16.0、L=220.0 是曲柄连杆机构的机械参数，
      换设备时要重新测量确认。

=====================================================
维护注意（补充）
=====================================================
    - 本 POU 在 DEMO.export 中仅有 VAR 声明块，无 ST 逻辑体。
      逻辑体可能在其他 action 或未导出，需现场补充。
    - ipFanuc 默认指向 172.16.10.11，修改时需确认 Fanuc 实际 IP。
    - rdata/wdata 数组各 10 个 WORD，具体寄存器映射见调用方注释。
    - FB_HeightToAngle 将高度值转换为旋转角度，供运动控制使用。
    - FB_BLINK 实现呼吸灯效果，用于 HMI 状态指示。

历史修改记录：
    版本        日期            修改人        修改内容
    V1.0        2026-06-04      Codex         从 DEMO.export 摘抄并按工程规则整理为独立 POU 文件
    V1.1        2026-06-04      Codex         新增"新手快速上手"章节，补充五组变量分层图解
=====================================================
*)

PROGRAM prModusTcp_Fanuc
VAR
    iStep                       : INT;                          // 步骤号
    Modbus_TCP_Set_0            : Modbus_TCP_Set;               // Modbus TCP 连接管理
    bModbusSet                  : BOOL;                         // 连接建立标志
    Modbus_TCP_Read_0           : Modbus_TCP_Read;              // Modbus 读取功能块
    ipFanuc                     : ARRAY [0..3] OF BYTE := [172,16,10,11];  // Fanuc 目标 IP
    iCounter                    : INT;                          // 计数器
    bRead                       : BOOL;                         // 读取触发
    tcpsocket                   : BYTE;                         // socket 标识
    rdata                       : ARRAY[0..9] OF WORD;          // 读取数据缓存
    // bModbusSet_Error          : BOOL;
    // bModbusRead_Error         : BOOL;
    // bModbusWrite_Error        : BOOL;
    Modbus_TCP_Write_0          : Modbus_TCP_Write;             // Modbus 写入功能块
    bWrite                      : BOOL;                         // 写入触发
    wdata                       : ARRAY[0..9] OF WORD;          // 写入数据缓存
    // bIdle                     : BOOL;
    iReady_deg                  : REAL;                         // Data_4 换模位置 ready 信号区域

    FB_HeightToAngle_iPTE       : FB_HeightToAngle;             // PTE 工位高度→角度
    FB_HeightToAngle_iPOP       : FB_HeightToAngle;             // POP 工位高度→角度
    FB_HeightToAngle_iPUP       : FB_HeightToAngle;             // PUP 工位高度→角度
    FB_HeightToAngle_iReady     : FB_HeightToAngle;             // Ready 工位高度→角度
    FB_HeightToAngle_iPSP1      : FB_HeightToAngle;             // PSP1 工位高度→角度
    FB_HeightToAngle_iPSP2      : FB_HeightToAngle;             // PSP2 工位高度→角度
    FB_BLINK_Idle               : FB_BLINK;                     // 空闲呼吸灯
END_VAR

(*
    TODO: DEMO.export 中本 POU 仅包含 VAR 声明块，ST 逻辑体缺失。
    需要根据现场实际需求补充以下逻辑：
    1. Modbus TCP 连接建立（bModbusSet ← Modbus_TCP_Set_0 状态）
    2. 周期读取 Fanuc 寄存器（Modbus_TCP_Read_0 触发与时序）
    3. 数据写入 Fanuc 寄存器（Modbus_TCP_Write_0 触发与时序）
    4. 使用 FB_HeightToAngle 实例将 rdata 中高度值转换为角度
    5. FB_BLINK_Idle 呼吸灯控制
*)
