(*
=====================================================
程序名称：Modbus_Client_Fanuc
功能描述：
    这是一个 Modbus TCP 客户端 POU，用于与 Fanuc 控制器建立 TCP 连接，
    读取指定 Modbus 寄存器，并将结果缓存到 PLC 内部数据区 `rdata`。
    该程序只负责 Modbus 通信本身，具体寄存器含义和 HMI 显示由上层逻辑处理。

主要逻辑：
    1. 先检查 `Modbus_TCP_Set_0` 是否已连接，如果未连接则启动连接请求。
    2. 当 `MB_RW` 被置 TRUE 时，发起 `Modbus_TCP_Read_0` 读取操作。
    3. 读取完成后，数据写入 `rdata`，重置 `MB_RW` 避免重复发起请求。
    4. `RW` 定时器控制读请求最小间隔（建议 100ms），避免网络占用过高。
    5. 若读取失败，`error` 置 TRUE，`errorid` 记录错误码。

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
