(*
=====================================================
程序名称：Modbus_Client_Fanuc
POU 类型：PROGRAM（需在 Task 中调用，每个周期执行一次）
功能定位：只读不写的 Modbus TCP 客户端 —— 从 Fanuc 读数据到 PLC

=====================================================
新手快速上手
=====================================================

一、这个文件干了什么？
    通过网线连上 Fanuc 机器人控制器，周期性地把 Fanuc 里的一串寄存器
    读到 PLC 的 `rdata[0..9]` 数组里。你只需在别的程序里读 `rdata` 就能
    拿到 Fanuc 的数据。**它只读、不写，是最简单的用法。**

二、用到你的项目里，要改哪几个地方？
    1. IP 地址（第 36 行 VAR 声明区）：`ip` 数组改成你 Fanuc 的实际 IP
    2. 寄存器起始地址（第 59 行伪代码区）：`wDataAddress` 改成你要读的第一个寄存器号
    3. 读取数量：如果你需要读 10 个以上，把 `rdata` 数组和 `wNumWords` 同步改大
    4. 轮询间隔（第 44 行）：`RW` 定时器的 `PT` 值，默认建议 T#100ms

三、代码结构三要素（Modbus TCP 通信的通用流程）：
    ① 建立连接 — `Modbus_TCP_Set_0` 功能块负责 TCP 三次握手
    ② 发起读取 — `Modbus_TCP_Read_0` 功能块负责发请求、收数据
    ③ 节拍控制 — `RW` 定时器 + `MB_RW` 旗标，控制"多久读一次"
    这三个要素是所有 Modbus TCP 程序的标配，理解了它们，其他通讯程序
    都是同样的套路。

四、程序执行流程（跟着走一遍就懂了）：
    上电 → 检查 TCP 连上没有？
        → 没连：调用 Modbus_TCP_Set_0，发起连接
        → 连上了：每 100ms（RW 定时器到）置 MB_RW=TRUE
            → MB_RW=TRUE 触发 Modbus_TCP_Read_0 发读取请求
            → 读完：数据自动进 rdata[]，清除 MB_RW
            → 下一个 100ms 到了，再来一次……

五、与 prModusTcp_Fanuc 的区别（选哪个？）：
    | 特性           | Modbus_Client_Fanuc（本文件） | prModusTcp_Fanuc         |
    |----------------|------------------------------|--------------------------|
    | 数据方向       | 只读（Fanuc → PLC）           | 读写双向（Fanuc ↔ PLC）  |
    | 应用转换       | 无，纯通信                    | 内置高度→角度转换、呼吸灯 |
    | 复杂度         | 简单，适合入门                | 较复杂，功能更全          |
    | 推荐场景       | 只需从 Fanuc 读几个寄存器看状态 | 需要改 Fanuc 参数 + 做运动控制 |

    → 简而言之：只想"看"Fanuc 数据用本文件，想"看+改"用 prModusTcp_Fanuc。

=====================================================
变量详解（新手翻译版）
=====================================================
    Modbus_TCP_Set_0  : 连接管家。负责和 Fanuc 建立/维护 TCP 连接。
    ip                : Fanuc 的 IP。4 个 BYTE 就是 IP 的四段，比如 172.16.10.11。
    tcpsocket         : 连接成功后会得到一个"门牌号"（socket handle），读写都要用它。
    Modbus_TCP_Read_0 : 读取器。告诉它"从哪个寄存器开始、读几个"，它帮你把数据取回来。
    rdata             : 数据暂存区。读回来的 10 个 WORD 就放这里，其他程序直接读这个数组。
    busy              : 忙碌指示灯。TRUE = 正在传数据，暂时别发新请求。
    error / errorid   : 报错灯 + 错误类型编号。TRUE 表示这次读取失败了。
    RW                : 节拍器（TON 定时器）。到时间就把 MB_RW 置 TRUE，触发下一次读取。
    MB_RW             : 扳机信号。TRUE = 发起一次读取，读完自动变回 FALSE。
=====================================================

变量依赖链（看一遍就知道谁管谁）：
    ip ────────────────→ Modbus_TCP_Set_0 ──→ tcpsocket ──→ Modbus_TCP_Read_0
                              ↑                                   │
                         (提供连接)                         (用连接读数据)
                                                                  │
                                                                  ↓
    RW 定时器 ──→ MB_RW（扳机）──→ 触发读取 ──→ rdata[]（结果缓存）
                    ↑                               ↓
                (到达间隔)              error/errorid（成功还是失败）

维护注意：
    - 该 POU 只负责 Modbus 通信层，不负责具体 Fanuc 寄存器的语义解析，
      例如 `rdata[0]`、`rdata[1]` 等的真实含义应在调用方中注释清楚。
    - 请务必确认 Fanuc 侧 Modbus 服务器地址、端口、寄存器偏移与当前配置一致。
    - 如果多个 POU 需要访问同一个 Fanuc 设备，请不要让它们共享同一个
      `Modbus_TCP_Set` 实例，否则容易出现 socket 冲突。推荐一个设备对应一个
      独立通信 POU。
    - `error` 和 `errorid` 仅代表本次读取状态，实际应用中应做错误计数、
      告警上报或重连处理。
    - 该程序默认读取 10 个 WORD，若实际量更多或更少，可在 `rdata` 定义处调整。

历史修改记录：
    版本        日期            修改人        修改内容
    V1.0        2026-06-03      Codex         从 DEMO.export 导入并按工程规则生成独立 POU 文件
    V1.1        2026-06-04      Codex         新增"新手快速上手"章节，补充变量依赖链图解
=====================================================
*)

PROGRAM Modbus_Client_Fanuc
VAR
    Modbus_TCP_Set_0    : Modbus_TCP_Set;                             // 管理 Modbus TCP 连接
    ip                  : ARRAY [0..3] OF BYTE := [172,16,10,11];   // Fanuc 目标 IP
    tcpsocket           : BYTE;                                       // 库返回的 socket / 连接标识
    Modbus_TCP_Read_0   : Modbus_TCP_Read;                            // Modbus 读取功能块
    rdata               : ARRAY[0..9] OF WORD;                        // 读取结果缓存
    busy                : BOOL;                                       // 传输中标志
    error               : BOOL;                                       // 错误标志
    errorid             : WORD;                                       // 错误码

    RW                  : TON;                                        // 读请求节拍定时器
    MB_RW               : BOOL := 0;                                  // 读请求触发信号
END_VAR

// 以下为伪代码参考，具体接口字段名称由 Modbus 库定义，请根据库文档补齐实现：
//
// IF NOT Modbus_TCP_Set_0.bConnected THEN
//     Modbus_TCP_Set_0.xEnable := TRUE;
//     Modbus_TCP_Set_0.sServerAddress := ip;
//     Modbus_TCP_Set_0.wServerPort := 502;
//     Modbus_TCP_Set_0();
// ELSIF MB_RW THEN
//     Modbus_TCP_Read_0.xEnable := TRUE;
//     Modbus_TCP_Read_0.xExecute := TRUE;
//     Modbus_TCP_Read_0.hConnection := tcpsocket;
//     Modbus_TCP_Read_0.wDataAddress := 0;  // 起始寄存器地址
//     Modbus_TCP_Read_0.wNumWords := 10;
//     Modbus_TCP_Read_0();
//     IF Modbus_TCP_Read_0.xDone THEN
//         rdata := Modbus_TCP_Read_0.Data;
//         MB_RW := FALSE;
//         error := FALSE;
//     ELSIF Modbus_TCP_Read_0.xError THEN
//         error := TRUE;
//         errorid := Modbus_TCP_Read_0.ErrorId;
//         MB_RW := FALSE;
//     END_IF;
// END_IF;
