// Ported from: Assets/Scripts/Logic/Level/LogicLevelProps.cs
package mvz2logic.level;

import mvz2logic.helditems.LogicHeldTypes;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.level.LevelEngine;
import pvzengine.level.StageDefinition;
import tools.RandomGenerator;
import unity.Color;
import unity.Mathf;
import unity.Vector3;

@:propertyRegistryRegion(PropertyRegions.level)
class LogicLevelProps
{
	static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	//region 屏幕覆盖
	public static var SCREEN_COVER:PropertyMeta<Color> = Get("screenCover", new Color(0, 0, 0, 0));
	public static function GetScreenCover(level:LevelEngine):Color
	{
		return level.GetProperty(SCREEN_COVER);
	}
	public static function SetScreenCover(level:LevelEngine, value:Color):Void
	{
		level.SetProperty(SCREEN_COVER, value);
	}
	//endregion

	//region 禁止暂停
	public static var PAUSE_DISABLED:PropertyMeta<Bool> = Get("pause_disabled", false);
	public static function IsPauseDisabled(level:LevelEngine):Bool
	{
		return level.GetProperty(PAUSE_DISABLED);
	}
	public static function SetPauseDisabled(level:LevelEngine, value:Bool):Void
	{
		level.SetProperty(PAUSE_DISABLED, value);
	}
	//endregion

	//region 镜头旋转
	public static var CAMERA_ROTATION:PropertyMeta<Float> = Get("cameraRotation", 0.0);
	public static function GetCameraRotation(level:LevelEngine):Float
	{
		return level.GetProperty(CAMERA_ROTATION);
	}
	public static function SetCameraRotation(level:LevelEngine, value:Float):Void
	{
		level.SetProperty(CAMERA_ROTATION, value);
	}
	//endregion

	//region 低质音乐
	public static var MUSIC_LOW_QUALITY:PropertyMeta<Bool> = Get("musicLowQuality", false);
	public static function IsMusicLowQuality(level:LevelEngine):Bool
	{
		return level.GetProperty(MUSIC_LOW_QUALITY);
	}
	//endregion

	//region 画面降级
	public static var GRAPHICS_DOWNGRADE:PropertyMeta<Bool> = Get("graphicsDowngrade", false);
	public static function AreGraphicsDowngrade(level:LevelEngine):Bool
	{
		return level.GetProperty(GRAPHICS_DOWNGRADE);
	}
	//endregion

	//region RNG
	public static var ARTIFACT_RNG:PropertyMeta<RandomGenerator> = Get("artifactRNG");
	public static function GetArtifactRNG(level:LevelEngine):RandomGenerator
	{
		var rng = level.GetProperty(ARTIFACT_RNG);
		if (rng == null)
		{
			rng = level.CreateRNG();
			SetArtifactRNG(level, rng);
		}
		return rng;
	}
	public static function SetArtifactRNG(level:LevelEngine, value:RandomGenerator):Void
	{
		level.SetProperty(ARTIFACT_RNG, value);
	}
	//endregion

	//region 器械随机池
	public static var RANDOM_CONTRAPTION_POOL:PropertyMeta<Array<NamespaceID>> = Get("random_contraption_pool");
	public static function GetRandomContraptionPool(level:LevelEngine):Null<Array<NamespaceID>>
	{
		return level.GetProperty(RANDOM_CONTRAPTION_POOL);
	}
	public static function SetRandomContraptionPool(level:LevelEngine, pool:Null<Array<NamespaceID>>):Void
	{
		level.SetProperty(RANDOM_CONTRAPTION_POOL, pool);
	}
	//endregion

	//region 星之碎片
	public static var STARSHARD_COUNT:PropertyMeta<Int> = Get("starshardCount", 0);
	public static var STARSHARD_SLOT_COUNT:PropertyMeta<Int> = Get("starshardSlotCount", 0);
	public static var STARSHARD_DISABLE_ID:PropertyMeta<NamespaceID> = Get("starshardDisableID");
	public static var STARSHARD_DISABLE_ICON:PropertyMeta<Bool> = Get("starshardDisableIcon", false);
	public static function GetStarshardSlotCount(game:LevelEngine):Int
	{
		return game.GetProperty(STARSHARD_SLOT_COUNT);
	}
	public static function SetStarshardSlotCount(game:LevelEngine, value:Int):Void
	{
		game.SetProperty(STARSHARD_SLOT_COUNT, value);
	}
	public static function IsStarshardDisabled(level:LevelEngine):Bool
	{
		return NamespaceID.IsValid(GetStarshardDisableID(level));
	}
	public static function GetStarshardDisableID(level:LevelEngine):Null<NamespaceID>
	{
		return level.GetProperty(STARSHARD_DISABLE_ID);
	}
	public static function ShouldShowStarshardDisableIcon(level:LevelEngine):Bool
	{
		return level.GetProperty(STARSHARD_DISABLE_ICON);
	}
	public static function CanUseStarshard(level:LevelEngine):Bool
	{
		if (!LogicLevelExt.IsStarshardActive(level))
			return false;
		if (IsStarshardDisabled(level))
			return false;
		if (GetStarshardCount(level) <= 0)
			return false;
		return true;
	}
	public static function GetStarshardCount(game:LevelEngine):Int
	{
		return game.GetProperty(STARSHARD_COUNT);
	}
	public static function SetStarshardCount(game:LevelEngine, value:Int):Void
	{
		value = Mathf.ClampInt(value, 0, GetStarshardSlotCount(game));
		game.SetProperty(STARSHARD_COUNT, value);
	}
	public static function AddStarshardCount(game:LevelEngine, value:Int):Void
	{
		SetStarshardCount(game, GetStarshardCount(game) + value);
	}
	//endregion

	//region 铁镐
	public static var PICKAXE_DISABLE_ID:PropertyMeta<NamespaceID> = Get("pickaxeDisableID");
	public static var PICKAXE_DISABLE_ICON:PropertyMeta<Bool> = Get("pickaxeDisableIcon", false);
	public static var PICKAXE_REMAIN_COUNT:PropertyMeta<Int> = Get("pickaxeRemainCount", 0);
	public static var PICKAXE_COUNT_LIMIT:PropertyMeta<Int> = Get("pickaxeCountLimit", 0);
	public static function IsPickaxeDisabled(level:LevelEngine):Bool
	{
		return NamespaceID.IsValid(GetPickaxeDisableID(level));
	}
	public static function GetPickaxeDisableID(level:LevelEngine):Null<NamespaceID>
	{
		return level.GetProperty(PICKAXE_DISABLE_ID);
	}
	public static function CanUsePickaxe(level:LevelEngine):Bool
	{
		if (!LogicLevelExt.IsPickaxeActive(level))
			return false;
		if (IsPickaxeDisabled(level))
			return false;
		if (IsPickaxeCountLimited(level) && GetPickaxeRemainCount(level) <= 0)
			return false;
		return true;
	}
	public static function ShouldShowPickaxeDisableIcon(level:LevelEngine):Bool
	{
		return level.GetProperty(PICKAXE_DISABLE_ICON);
	}
	public static function GetPickaxeRemainCount(level:LevelEngine):Int
	{
		return level.GetProperty(PICKAXE_REMAIN_COUNT);
	}
	public static function SetPickaxeRemainCount(level:LevelEngine, value:Int):Void
	{
		level.SetProperty(PICKAXE_REMAIN_COUNT, value);
	}
	public static function AddPickaxeRemainCount(level:LevelEngine, value:Int):Void
	{
		SetPickaxeRemainCount(level, GetPickaxeRemainCount(level) + value);
	}
	public static function IsPickaxeCountLimited(level:LevelEngine):Bool
	{
		return GetPickaxeCountLimit(level) > 0;
	}
	public static function GetPickaxeCountLimit(level:LevelEngine):Int
	{
		return level.GetProperty(PICKAXE_COUNT_LIMIT);
	}
	public static function SetPickaxeCountLimit(level:LevelEngine, value:Int):Void
	{
		level.SetProperty(PICKAXE_COUNT_LIMIT, value);
	}
	// TODO-PORT: C# 重载 SetPickaxeCountLimit(this StageDefinition level, int value)，Haxe 不支持重载，重命名为 SetStagePickaxeCountLimit
	public static function SetStagePickaxeCountLimit(level:StageDefinition, value:Int):Void
	{
		level.SetProperty(PICKAXE_COUNT_LIMIT, value);
	}
	//endregion

	//region 触发器
	public static var TRIGGER_DISABLE_ID:PropertyMeta<NamespaceID> = Get("triggerDisableID");
	public static function CanUseTrigger(level:LevelEngine):Bool
	{
		if (!LogicLevelExt.IsTriggerActive(level))
			return false;
		if (IsTriggerDisabled(level))
			return false;
		return true;
	}
	public static function IsTriggerDisabled(level:LevelEngine):Bool
	{
		return NamespaceID.IsValid(GetTriggerDisableID(level));
	}
	public static function GetTriggerDisableID(level:LevelEngine):Null<NamespaceID>
	{
		return level.GetProperty(TRIGGER_DISABLE_ID);
	}
	//endregion

	//region 最后敌人位置
	public static var LAST_ENEMY_POSITION:PropertyMeta<Vector3> = Get("lastEnemyPosition", new Vector3(0, 0, 0));
	public static function GetLastEnemyPosition(game:LevelEngine):Vector3
	{
		return game.GetProperty(LAST_ENEMY_POSITION);
	}
	public static function SetLastEnemyPosition(game:LevelEngine, value:Vector3):Void
	{
		game.SetProperty(LAST_ENEMY_POSITION, value);
	}
	//endregion

	//region 让手持物品保持在屏幕内
	public static var KEEP_HELD_ITEM_IN_SCREEN:PropertyMeta<Bool> = Get("keepHeldItemInScreen", false);
	public static function KeepHeldItemInScreen(level:LevelEngine):Bool
	{
		return level.GetProperty(KEEP_HELD_ITEM_IN_SCREEN);
	}
	//endregion

	//region 星之碎片手持物品类型
	public static var STARSHARD_HELD_TYPE:PropertyMeta<NamespaceID> = Get("starshard_held_type", LogicHeldTypes.starshard);
	public static function GetStarshardHeldType(game:LevelEngine):Null<NamespaceID>
	{
		return game.GetProperty(STARSHARD_HELD_TYPE);
	}
	//endregion

	//region 出怪点数
	public static var SPAWN_POINTS_POWER:PropertyMeta<Float> = Get("spawnPointsPower", 0.0);
	public static var SPAWN_POINTS_MUTLIPLIER:PropertyMeta<Float> = Get("spawnPointsMultiplier", 0.0);
	public static var SPAWN_POINTS_ADDITION:PropertyMeta<Float> = Get("spawnPointsAddition", 0.0);
	public static var BOSS_SPAWN_POINTS_MULTIPLIER:PropertyMeta<Float> = Get("boss_spawn_points_multiplier", 1.0);
	public static function GetSpawnPointPower(level:LevelEngine):Float
	{
		return level.GetProperty(SPAWN_POINTS_POWER);
	}
	public static function SetSpawnPointPower(stageDef:StageDefinition, value:Float):Void
	{
		stageDef.SetProperty(SPAWN_POINTS_POWER, value);
	}
	public static function GetSpawnPointMultiplier(level:LevelEngine):Float
	{
		return level.GetProperty(SPAWN_POINTS_MUTLIPLIER);
	}
	public static function SetSpawnPointMultiplier(stageDef:StageDefinition, value:Float):Void
	{
		stageDef.SetProperty(SPAWN_POINTS_MUTLIPLIER, value);
	}
	public static function GetSpawnPointAddition(level:LevelEngine):Float
	{
		return level.GetProperty(SPAWN_POINTS_ADDITION);
	}
	public static function SetSpawnPointAddition(stageDef:StageDefinition, value:Float):Void
	{
		stageDef.SetProperty(SPAWN_POINTS_ADDITION, value);
	}
	public static function GetBossSpawnPointMultiplierOfDefinition(entityDef:StageDefinition):Float
	{
		return entityDef.GetProperty(BOSS_SPAWN_POINTS_MULTIPLIER);
	}
	public static function GetBossSpawnPointMultiplier(level:LevelEngine):Float
	{
		return level.GetProperty(BOSS_SPAWN_POINTS_MULTIPLIER);
	}
	//endregion

	//region 昼夜循环覆盖
	public static var DAY_NIGHT_CYCLE_OVERRIDE:PropertyMeta<Int> = Get("day_night_cycle_override", 0);
	public static function GetDayNightCycleOverride(game:LevelEngine):Int
	{
		return game.GetProperty(DAY_NIGHT_CYCLE_OVERRIDE);
	}
	//endregion

	//region 假定存在敌人
	public static var ASSUME_HAS_ENEMIES:PropertyMeta<Bool> = Get("assume_has_enemies", false);
	public static function AssumeHasEnemies(game:LevelEngine):Bool
	{
		return game.GetProperty(ASSUME_HAS_ENEMIES);
	}
	//endregion

	//region 所有怪物被清理
	public static var ALL_ENEMIES_CLEARED:PropertyMeta<Bool> = Get("allEnemiesCleared", false);
	public static function IsAllEnemiesCleared(level:LevelEngine):Bool
	{
		return level.GetProperty(ALL_ENEMIES_CLEARED);
	}
	public static function SetAllEnemiesCleared(level:LevelEngine, value:Bool):Void
	{
		level.SetProperty(ALL_ENEMIES_CLEARED, value);
	}
	//endregion

	//region 忽略一大波事件
	public static var IGNORE_HUGE_WAVE_EVENT:PropertyMeta<Bool> = Get("ignoreHugeWaveEvent", false);
	public static function IgnoreHugeWaveEvent(level:LevelEngine):Bool
	{
		return level.GetProperty(IGNORE_HUGE_WAVE_EVENT);
	}
	public static function SetIgnoreHugeWaveEvent(level:LevelEngine, value:Bool):Void
	{
		level.SetProperty(IGNORE_HUGE_WAVE_EVENT, value);
	}
	//endregion

	//region 无推车
	public static var NO_CARTS:PropertyMeta<Bool> = Get("noCarts", false);
	public static function HasNoCarts(level:LevelEngine):Bool
	{
		return level.GetProperty(NO_CARTS);
	}
	public static function SetNoCarts(level:LevelEngine, value:Bool):Void
	{
		level.SetProperty(NO_CARTS, value);
	}
	//endregion

	//region 上帝模式
	public static var GODMODE:PropertyMeta<Bool> = Get("godmode", false);
	public static function IsGodMode(level:LevelEngine):Bool
	{
		return level.GetProperty(GODMODE);
	}
	public static function SetGodMode(level:LevelEngine, value:Bool):Void
	{
		level.SetProperty(GODMODE, value);
	}
	//endregion

	private function new() {}
}
