FUNCTION_BLOCK FB_BLINK
(*
=====================================================
功能块名称：FB_BLINK
功能描述：
    基于 TON 定时器的闪烁信号发生器。使能时输出周期性翻转的
    方波信号，亮暗各占半个周期。

主要逻辑：
    1. Enable 为 FALSE 时，输出 Q 复位为 FALSE，定时器和内部
       状态均清零。
    2. Enable 为 TRUE 时，启动 TON 定时器，定时时间为 Period/2，
       即半个周期。
    3. 定时器到达后，翻转内部状态 State，并复位定时器重新计时，
       实现占空比 50% 的方波输出。
    4. 输出 Q 跟随内部状态 State。

维护注意：
    - 占空比固定为 50%，若需可调占空比需增加 ON_TIME/OFF_TIME
      两个输入参数。
    - 定时器精度取决于 PLC 任务周期，高频闪烁时需确保任务周期
      远小于 Period/2。
    - 修改本功能块时，请在下方"历史修改记录"追加记录。

历史修改记录：
    版本        日期            修改人        修改内容
    V1.0        2026-05-31      Codex         从 AP 工程导出并整理，新增功能描述及维护记录模板
=====================================================
*)
VAR_INPUT
    // 使能信号：TRUE 时启动闪烁，FALSE 时输出复位
    Enable              : BOOL;

    // 闪烁周期：亮暗各占一半，例如 T#1s 表示 0.5s 亮 + 0.5s 暗
    Period              : TIME;
END_VAR

VAR_OUTPUT
    // 闪烁输出信号，周期性翻转
    Q                   : BOOL;
END_VAR

VAR
    // TON 定时器，用于半个周期计时
    Timer               : TON;

    // 内部闪烁状态，初始为 FALSE
    State               : BOOL := FALSE;
END_VAR


// =====================================================
// 1. 使能时启动定时器，未使能时清零
// =====================================================
IF Enable THEN

    // 定时器以 Period/2 为周期自复位，产生 50% 占空比方波
    Timer(IN := NOT Timer.Q, PT := Period / 2);

    // 定时到达后翻转输出状态并复位定时器
    IF Timer.Q THEN
        State := NOT State;
        Timer(IN := FALSE);
    END_IF;

    Q := State;

ELSE
    Q := FALSE;
    Timer(IN := FALSE);
    State := FALSE;
END_IF;
