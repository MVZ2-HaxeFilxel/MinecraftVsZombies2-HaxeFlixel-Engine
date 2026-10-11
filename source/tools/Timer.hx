// Ported from: Assets/Scripts/Engine/Tools/Timer/Timer.cs
package tools;

/**
 * C# 的 `Timer` 为抽象类。Haxe 的 `abstract` 关键字语义不同，故仍写 `class`，
 * 抽象成员以 `throw "abstract"` 占位（PORTING.md §抽象类/方法）。
 */
@:rtti
class Timer
{
	public function new() {}

	// C#: public void Run() / public abstract void Run(float speed)
	// PORT-NOTE: Haxe 无方法重载，两个 Run 合并为带默认参数的 Run(?speed:Float = 1)。
	public function Run(?speed:Float = 1):Void
	{
		throw "abstract";
	}
	public function RunToExpired(?speed:Float = 1):Bool
	{
		Run(speed);
		return Expired;
	}
	public function Stop():Void
	{
		throw "abstract";
	}
	public function Reset():Void
	{
		throw "abstract";
	}
	public function GetPassedPercentage():Float
	{
		return 1 - GetTimeoutPercentage();
	}
	public function GetTimeoutPercentage():Float
	{
		throw "abstract";
	}
	// C#: public abstract bool Expired { get; }
	public var Expired(get, never):Bool;
	public function get_Expired():Bool
	{
		throw "abstract";
	}
}
