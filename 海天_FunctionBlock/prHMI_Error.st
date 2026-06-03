(*
=====================================================
程序名称：prHMI_Error
功能描述：
    报警处理程序。将驱动器报警码和 PLC 内部报警统一收集，
    通过查表法映射为 HMI 报警位，写入 Modbus 地址区供 HMI 显示。
    同时输出综合性报警标志给数控系统。

主要逻辑：
    1. 每周期先清除所有 100 个报警位（清零再置位，防止残留）。
    2. 遍历查表数组 DrvAlarmMap，如果驱动器报警码匹配，则置位
       对应的 AlarmBits[i]，其中 i 映射到 HMI 错误号 Er034~Er160。
    3. 处理 PLC 内部报警：超温、急停、调试异常等，直接置位固定编号。
    4. 将 BOOL 数组 AlarmBits 转写到 WORD 数组 HmiAlarm（HMI 通过
       Modbus 地址 %MW1400~%MW1499 直接读取）。
    5. 根据 DrvAlarmCode 是否非零，输出 bDriveError 给数控系统。

新颖之处（查表法报警映射）：
    - 传统写法：对每个报警码逐一 IF 判断
      IF DrvAlarmCode = 34 THEN AlarmBits[0] := TRUE; END_IF
      IF DrvAlarmCode = 35 THEN AlarmBits[1] := TRUE; END_IF
      ...（需要写 37 条）
    - 本程序写法：将 37 个报警码存入 DrvAlarmMap 数组，一个 FOR 循环
      完成全部匹配。新增报警码只需在数组中追加一行，无需改动逻辑。
    - DrvAlarmMap 放在独立的第二个 VAR 块中，与运行时变量分离，
      结构清晰，方便维护时定位配置数据。

维护注意：
    - DrvAlarmMap 数组索引 i 直接对应 HMI 报警号位置：
      i=0 → Er034, i=1 → Er035, ..., i=36 → Er160
    - HmiAlarm 映射到 %MW1400~%MW1499，共 100 个 WORD，HMI 侧
      需保证地址范围一致。
    - DrvAlarmCode 来自 %IW16（驱动器 PDO 输入），仅低 8 位有效。
    - bDriveError 是综合性报警标志，可在其他地方用于急停或报警灯。
    - 修改本程序时，请在下方"历史修改记录"追加记录。

历史修改记录：
    版本        日期            修改人        修改内容
    V1.0        2026-06-03      Codex         从 DEMO.export 摘抄并按工程规则整理为独立 POU 文件
=====================================================
*)

PROGRAM prHMI_Error
VAR
    (* 驱动器报警输入字 *)
    DrvAlarmCode    AT %IW16    : UINT;                     // 真实 Errorcode，取 PDO 参数低 8 位

    (* PLC 内部报警 *)
    PlcAlarm_OverTemp           : BOOL;                     // 超温报警
    PlcAlarm_EStop              : BOOL;                     // 急停报警

    (* 最终报警数组，对应 HMI 1400~1500 地址 *)
    HmiAlarm        AT %MW1400  : ARRAY [0..99] OF WORD;   // HMI Modbus 报警区
    AlarmBits                   : ARRAY[0..99] OF BOOL;    // 内部 BOOL 报警位

    i                           : INT;                      // 循环索引
END_VAR

(* 报警号映射表，对应 Er034 ~ Er160 *)
VAR
    DrvAlarmMap : ARRAY[0..36] OF BYTE := [
        34, 35, 49, 50, 51, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 66, 67, 68,
        69, 70, 81, 82, 83, 84, 89, 90, 109, 110, 111, 122, 132, 144, 145, 146, 147, 160
    ];
END_VAR


(* 1. 清除所有报警位 *)
FOR i := 0 TO 99 DO
    AlarmBits[i] := FALSE;
END_FOR

(* 2. 判断驱动器报警码 —— 查表法，遍历匹配 *)
FOR i := 0 TO 36 DO
    IF DrvAlarmCode = DrvAlarmMap[i] THEN
        AlarmBits[i] := TRUE;       (* i=0 → Er034, i=1 → Er035, ... *)
    END_IF
END_FOR

(* 3. PLC 内部报警 —— 固定编号直接置位 *)
// AlarmBits[40] := TCP.bError;     // 预留：Modbus 通信异常
AlarmBits[41] := PlcAlarm_OverTemp;
AlarmBits[42] := PlcAlarm_EStop;
AlarmBits[51] := bDebug_AFErr;
AlarmBits[52] := bDebug_MoveErr;
AlarmBits[53] := bDebug_SetHomeErr;

(* 4. 写入到 HMI Modbus 地址区 —— BOOL 数组 → WORD 数组 *)
FOR i := 0 TO 99 DO
    IF AlarmBits[i] THEN
        HmiAlarm[i] := 1;
    ELSE
        HmiAlarm[i] := 0;
    END_IF
END_FOR

(* 给数控系统报警 —— 综合性标志 *)
IF DrvAlarmCode <> 0 THEN
    bDriveError := TRUE;
ELSE
    bDriveError := FALSE;
END_IF
