// Ported from: Assets/Scripts/Engine/Tools/Timer/FrameTimer.cs
package tools;

import pvzengine.Ticks;
import unity.Mathf;

/**
 * 帧计时器：Frame 表示「剩余帧数」，Expired 为 Frame <= 0。
 */
@:rtti
class FrameTimer extends Timer
{
	// C#: public FrameTimer() : this(0)
	//     public FrameTimer(int time) : this(time, DEFAULT_PRECISION)
	//     public FrameTimer(int time, int precision)
	// PORT-NOTE: Haxe 无构造函数重载，三者合并为 new(?time, ?precision)。
	// 注意 C# 的 (int time, int precision) 构造函数只设置 Precision（MaxFrame/Frame 保持 0）、
	// 由 (int time) 的构造函数体再补设 MaxFrame/Frame/...；合并后统一按 (int time) 的语义初始化。
	public function new(?time:Int = 0, ?precision:Int = DEFAULT_PRECISION)
	{
		super();
		Precision = precision;
		MaxFrame = time;
		Frame = time;
		FrameFraction = 0;
		LastFrame = time;
		LastFrameFraction = FrameFraction;
	}
	public override function Run(?speed:Float = 1):Void
	{
		LastFrame = Frame;
		LastFrameFraction = FrameFraction;
		if (Expired)
			return;
		var integer = Std.int(speed);
		var modular = speed - integer;
		Frame -= integer;

		if (modular > 0)
		{
			FrameFraction += Mathf.FloorToInt(modular * Precision);
			if (FrameFraction >= Precision)
			{
				FrameFraction -= Precision;
				Frame--;
			}
		}
	}
	public function PassedFrameFromMax(frame:Int):Bool
	{
		return PassedFrame(MaxFrame - frame);
	}
	public function PassedFrame(frame:Int):Bool
	{
		return LastFrame > frame && Frame <= frame;
	}
	public function PassedInterval(interval:Int):Bool
	{
		return PassedIntervalCount(interval) != 0;
	}
	public function PassedIntervalCount(interval:Int):Int
	{
		// C#: Mathf.CeilToInt(LastFrame / interval) - Mathf.CeilToInt(Frame / interval)
		// PORT-NOTE: C# 此处是 int 整除（向零截断）；Haxe 的 `/` 是浮点除法，
		// 故先用 Std.int 还原整除语义再取 CeilToInt。
		return Mathf.CeilToInt(Std.int(LastFrame / interval)) - Mathf.CeilToInt(Std.int(Frame / interval));
	}
	public override function GetTimeoutPercentage():Float
	{
		return (Frame + FrameFraction / Precision) / MaxFrame;
	}
	public override function Stop():Void
	{
		Frame = 0;
		FrameFraction = 0;
		LastFrame = 0;
		LastFrameFraction = 0;
	}
	public override function Reset():Void
	{
		Frame = MaxFrame;
		FrameFraction = 0;
		LastFrame = MaxFrame;
		LastFrameFraction = 0;
	}
	public function ResetTime(time:Int):Void
	{
		MaxFrame = time;
		Reset();
	}
	public override function get_Expired():Bool
	{
		return Frame <= 0;
	}
	@:bsonElement("maxFrame")
	public var MaxFrame:Int;
	@:bsonElement("lastFrame")
	public var LastFrame:Int;
	@:bsonElement("lastFrameFraction")
	public var LastFrameFraction:Int;
	@:bsonElement("frame")
	public var Frame:Int;
	@:bsonElement("frameFraction")
	public var FrameFraction:Int;
	@:bsonElement("precision")
	public var Precision(default, null):Int;

	public static inline var DEFAULT_PRECISION:Int = 2048;

	// ======================================================================
	// PORT-NOTE: 以下成员在 C# 中属于 `PVZEngine.TimerHelper` 的扩展方法
	// （TimerHelper.cs），但既有上层调用点全部以「实例方法」形式调用且未 `using`
	// 对应的扩展类（例如 `timer.ResetSeconds(1)`、`timer.RunToExpiredOrNull()`），
	// 故在此内联为实例方法，语义与 C# 扩展方法完全一致。
	// ======================================================================

	// C#: public static IEnumerable<float> IteratePassedFrames(this FrameTimer timer, float interval)
	public function IteratePassedFrames(interval:Float):Array<Float>
	{
		var lastFrame = LastFrame + LastFrameFraction / Precision;
		var currentFrame = Frame + FrameFraction / Precision;
		var start:Float = Mathf.CeilToInt(lastFrame / interval);
		var end:Float = Mathf.CeilToInt(currentFrame / interval);
		end = Mathf.Max(0, end);
		var result:Array<Float> = [];
		var t = start;
		while (t > end)
		{
			result.push((t - 1) * interval);
			t--;
		}
		return result;
	}
	// C#: public static float GetMaxSeconds(this FrameTimer timer)
	public function GetMaxSeconds():Float
	{
		return Ticks.ToSeconds(MaxFrame);
	}
	// C#: public static void SetSeconds(this FrameTimer timer, float seconds)
	public function SetSeconds(seconds:Float):Void
	{
		var frames = seconds * Ticks.GetTPS();
		Frame = Mathf.FloorToInt(frames);
		FrameFraction = Mathf.FloorToInt((frames % 1) * Precision);
	}
	// C#: public static void ResetSeconds(this FrameTimer timer, float seconds)
	public function ResetSeconds(seconds:Float):Void
	{
		ResetTime(Ticks.FromSeconds(seconds));
	}
	// C#: public static bool PassedSeconds(this FrameTimer timer, float seconds)
	public function PassedSeconds(seconds:Float):Bool
	{
		return PassedFrame(Ticks.FromSeconds(seconds));
	}
	// C#: public static bool PassedSecondsFromMax(this FrameTimer timer, float seconds)
	public function PassedSecondsFromMax(seconds:Float):Bool
	{
		return PassedFrameFromMax(Ticks.FromSeconds(seconds));
	}
	// C#: public static bool PassedIntervalSeconds(this FrameTimer timer, float seconds)
	public function PassedIntervalSeconds(seconds:Float):Bool
	{
		return PassedInterval(Ticks.FromSeconds(seconds));
	}
	// C#: public static bool RunToExpiredOrNull([NotNullWhen(false)] this FrameTimer? timer, float speed = 1)
	// PORT-NOTE: C# 中接收者可空（null 视为已过期）且以扩展方法形式调用。
	// Haxe 无法在 null 上调用实例方法，保留 `this == null` 早退分支以尽量维持原语义。
	public function RunToExpiredOrNull(?speed:Float = 1):Bool
	{
		if (this == null)
			return true;
		return RunToExpired(speed);
	}
	// C#: public static bool RunToExpiredAndNotNull([NotNullWhen(true)] this FrameTimer? timer, float speed = 1)
	// PORT-NOTE: 同上；null 视为未过期。
	public function RunToExpiredAndNotNull(?speed:Float = 1):Bool
	{
		if (this == null)
			return false;
		return RunToExpired(speed);
	}
}
