(*
=====================================================
程序名称：prHMI
功能描述：
    prHMI 程序用于声明 HMI/PLC 交互所需变量，并包含一个
    `FB_CrankSliderHeight` 功能块实例。该程序从 DEMO.export 中导出，
    当前仅包含变量声明和地址映射，没有可执行的程序体逻辑。

主要逻辑：
    当前无程序体。该 POU 主要作为数据接口层，定义 HMI 与 PLC 之间的
    地址映射和功能块实例，具体运行逻辑由调用方或任务配置负责。

维护注意：
    - `AT %MW...`、`AT %MD...` 地址与 HMI/PLC 数据区紧密绑定，
      修改时务必确认地址不冲突。
    - `FB_CrankSliderHeight_1` 是关键子块，需保证 `FB_CrankSliderHeight.st`
      已存在且类型定义一致。
    - 如果实际逻辑在别处实现，建议在此 POU 注释中注明调用关系。

历史修改记录：
    版本        日期            修改人        修改内容
    V1.0        2026-06-03      Codex         从 DEMO.export 导出 prHMI 程序变量声明，生成独立 POU 文件
=====================================================
*)

PROGRAM prHMI
VAR
    Vel_Gain            AT %MD1000  : REAL;    // 速度增益

    // HMI 交互变量，地址映射至 %MW1200 ~ %MD1234
    iPTE_mm             AT %MW1200  : WORD;    // 压边力
    iPOP_mm             AT %MW1202  : WORD;    // 开口位置
    iPUP_mm             AT %MW1204  : WORD;    // 闭合位置
    iReady_mm           AT %MW1206  : WORD;    // 就绪高度
    iDelayTime_ms       AT %MW1208  : WORD;    // 延时时间
    iPunchSpeed_Max     AT %MW1210  : WORD;    // 最大冲压速度
    iPSP1_mm            AT %MW1212  : WORD;    // 第一变速点
    iPunchSpeed         AT %MW1214  : WORD;    // 冲压速度
    iPSP2_mm            AT %MW1216  : WORD;    // 第二变速点
    wMode_hmi           AT %MW1218  : WORD;    // HMI 模式字
    wActPos             AT %MD1220  : REAL;    // 当前位置
    wPunHeight_mm       AT %MW1224  : WORD;    // 冲压高度
    wStep               AT %MW1226  : WORD;    // 当前步序
    iMotorTemperature   AT %MW1228  : INT;     // 电机温度
    wCommuanomaly       AT %MW1230  : WORD;    // 通信异常标志
    wSetPosExe          AT %MW1232  : WORD;    // 设定位置执行
    wdSetPosValue       AT %MD1234  : REAL;    // 设定位置值

    FB_CrankSliderHeight_1 : FB_CrankSliderHeight;    // 曲柄连杆高度转换实例

    wI0                 AT %MW1500  : BYTE;    // 输入缓存
    wQ20                AT %MW1501  : WORD;    // 输出缓存

    Set_RetaParam       AT %MD3600  : REAL;    // 附加调节参数
END_VAR
