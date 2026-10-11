// Ported from: Assets/Scripts/Engine/Level/Level/EngineStageProps.cs
package pvzengine.level;

import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;

// C#: [PropertyRegistryRegion(PropertyRegions.level)]
@:propertyRegistryRegion(PropertyRegions.level)
class EngineStageProps
{
	private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	public static var TOTAL_FLAGS:PropertyMeta<Int> = Get("totalFlags", 0);
	public static function GetTotalFlags(level:LevelEngine):Int
	{
		return level.GetProperty(TOTAL_FLAGS);
	}

	public static var WAVES_PER_FLAG:PropertyMeta<Int> = Get("wavesPerFlag", 0);
	public static function GetWavesPerFlag(level:LevelEngine):Int
	{
		return level.GetProperty(WAVES_PER_FLAG);
	}

	public static var FIRST_WAVE_TIME:PropertyMeta<Float> = Get("firstWaveTime", 0.0);
	public static function GetFirstWaveTime(level:LevelEngine):Float
	{
		return level.GetProperty(FIRST_WAVE_TIME);
	}

	public static var CONTINUED_FIRST_WAVE_TIME:PropertyMeta<Float> = Get("continuedFirstWaveTime", 0.0);
	// PORT-NOTE: C# 方法名拼写为 GetContinutedFirstWaveTime（原文如此），保留不修改。
	public static function GetContinutedFirstWaveTime(level:LevelEngine):Float
	{
		return level.GetProperty(CONTINUED_FIRST_WAVE_TIME);
	}

	public static function IsHugeWave(level:LevelEngine, wave:Int):Bool
	{
		return wave > 0 && wave % level.GetWavesPerFlag() == 0;
	}

	public static function GetTotalWaveCount(level:LevelEngine):Int
	{
		return level.GetTotalFlags() * level.GetWavesPerFlag();
	}

	public static function IsFinalWave(level:LevelEngine, wave:Int):Bool
	{
		return wave == level.GetTotalWaveCount();
	}
}
