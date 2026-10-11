// Ported from: Assets/Scripts/Logic/Level/LogicStageProps.cs
package mvz2logic.level;

import Lambda;
import mvz2logic.conditions.IConditionList;
import mvz2logic.level.IStageMeta.IStageTalkMeta;
import mvz2logic.level.LevelCameraPosition;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.level.IConveyorPoolEntry;
import pvzengine.level.LevelEngine;
import pvzengine.level.StageDefinition;

@:propertyRegistryRegion(PropertyRegions.level)
class LogicStageProps
{
	static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	//region 模型预设
	public static var MODEL_PRESET:PropertyMeta<String> = Get("model_preset");
	public static function GetModelPreset(stage:StageDefinition):Null<String>
	{
		return stage.GetProperty(MODEL_PRESET);
	}
	public static function SetModelPreset(stage:StageDefinition, value:String):Void
	{
		stage.SetProperty(MODEL_PRESET, value);
	}
	//endregion

	//region 关卡类型
	public static var STAGE_TYPE:PropertyMeta<String> = Get("stage_type");
	public static function GetStageType(stage:StageDefinition):Null<String>
	{
		return stage.GetProperty(STAGE_TYPE);
	}
	public static function SetStageType(stage:StageDefinition, value:String):Void
	{
		stage.SetProperty(STAGE_TYPE, value);
	}
	//endregion

	//region 解锁条件
	public static var UNLOCK_CONDITIONS:PropertyMeta<IConditionList> = Get("unlock_conditions");
	public static function GetUnlockConditions(stage:StageDefinition):Null<IConditionList>
	{
		return stage.GetProperty(UNLOCK_CONDITIONS);
	}
	public static function SetUnlockConditions(stage:StageDefinition, value:IConditionList):Void
	{
		stage.SetProperty(UNLOCK_CONDITIONS, value);
	}
	//endregion

	//region 传送带卡池
	public static var CONVEYOR_POOL:PropertyMeta<Array<IConveyorPoolEntry>> = Get("conveyorPool");
	public static function GetConveyorPool(game:LevelEngine):Null<Array<IConveyorPoolEntry>>
	{
		return game.GetProperty(CONVEYOR_POOL);
	}
	//endregion

	//region 传送带速度
	public static var CONVEY_SPEED:PropertyMeta<Float> = Get("conveySpeed", 1.0);
	public static function GetConveySpeed(game:LevelEngine):Float
	{
		return game.GetProperty(CONVEY_SPEED);
	}
	//endregion

	//region 对话
	public static var TALKS:PropertyMeta<Array<IStageTalkMeta>> = Get("talks");
	public static function GetTalks(game:LevelEngine):Null<Array<IStageTalkMeta>>
	{
		return game.GetProperty(TALKS);
	}
	public static function GetTalksOfType(game:LevelEngine, type:String):Array<IStageTalkMeta>
	{
		var talks = GetTalks(game);
		if (talks == null)
			return [];
		return Lambda.filter(talks, (t:IStageTalkMeta) -> t.Type == type);
	}
	//endregion

	//region 无尽模式
	public static var ENDLESS:PropertyMeta<Bool> = Get("endless", false);
	public static function IsEndlessOfStage(stage:StageDefinition):Bool
	{
		return stage.GetProperty(ENDLESS);
	}
	public static function IsEndless(level:LevelEngine):Bool
	{
		return level.GetProperty(ENDLESS);
	}
	//endregion

	//region 我是僵尸模式
	public static var I_ZOMBIE:PropertyMeta<Bool> = Get("iZombie", false);
	public static function IsIZombieOfStage(stage:StageDefinition):Bool
	{
		return stage.GetProperty(I_ZOMBIE);
	}
	public static function IsIZombie(level:LevelEngine):Bool
	{
		return level.GetProperty(I_ZOMBIE);
	}
	public static function SetIZombie(stage:StageDefinition, value:Bool):Void
	{
		stage.SetProperty(I_ZOMBIE, value);
	}
	//endregion

	//region 冒险模式
	public static var ADVENTURE:PropertyMeta<Bool> = Get("adventure", false);
	public static function IsAdventure(level:LevelEngine):Bool
	{
		return level.GetProperty(ADVENTURE);
	}
	public static function SetAdventure(level:LevelEngine, value:Bool):Void
	{
		level.SetProperty(ADVENTURE, value);
	}
	//endregion

	//region Boss复仇模式
	public static var BOSS_REVENGE:PropertyMeta<Bool> = Get("boss_revenge", false);
	public static function IsBossRevenge(level:LevelEngine):Bool
	{
		return level.GetProperty(BOSS_REVENGE);
	}
	public static function SetBossRevenge(level:LevelEngine, value:Bool):Void
	{
		level.SetProperty(BOSS_REVENGE, value);
	}
	//endregion

	//region 关卡天数
	public static var DAY_NUMBER:PropertyMeta<Int> = Get("dayNumber", 0);
	public static function GetDayNumber(level:LevelEngine):Int
	{
		return level.GetProperty(DAY_NUMBER);
	}
	public static function GetDayNumberOfStage(stage:StageDefinition):Int
	{
		return stage.GetProperty(DAY_NUMBER);
	}
	public static function SetDayNumber(stage:StageDefinition, number:Int):Void
	{
		stage.SetProperty(DAY_NUMBER, number);
	}
	//endregion

	//region 关卡名
	public static var LEVEL_NAME:PropertyMeta<String> = Get("levelName");
	public static function GetLevelName(level:LevelEngine):Null<String>
	{
		return level.GetProperty(LEVEL_NAME);
	}
	public static function GetLevelNameOfStage(stage:StageDefinition):Null<String>
	{
		return stage.GetProperty(LEVEL_NAME);
	}
	public static function SetLevelName(stage:StageDefinition, name:String):Void
	{
		stage.SetProperty(LEVEL_NAME, name);
	}
	//endregion

	//region 结束笔记ID
	public static var END_NOTE_ID:PropertyMeta<NamespaceID> = Get("endNoteId");
	public static function GetEndNoteID(game:LevelEngine):Null<NamespaceID>
	{
		return game.GetProperty(END_NOTE_ID);
	}
	//endregion

	//region 音乐ID
	public static var MUSIC_ID:PropertyMeta<NamespaceID> = Get("musicId");
	public static function GetMusicID(game:LevelEngine):Null<NamespaceID>
	{
		return game.GetProperty(MUSIC_ID);
	}
	public static function SetMusicID(game:LevelEngine, value:NamespaceID):Void
	{
		game.SetProperty(MUSIC_ID, value);
	}
	//endregion

	//region 需要选卡

	public static var NEED_BLUEPRINTS:PropertyMeta<Bool> = Get("needBlueprints", false);
	public static function SetNeedBlueprints(stage:StageDefinition, value:Bool):Void
	{
		stage.SetProperty(NEED_BLUEPRINTS, value);
	}
	public static function NeedBlueprints(level:LevelEngine):Bool
	{
		return level.GetProperty(NEED_BLUEPRINTS);
	}
	//endregion

	//region 无开场对话音乐
	public static var NO_START_TALK_MUSIC:PropertyMeta<Bool> = Get("noStartTalkMusic", false);
	public static function NoStartTalkMusic(game:LevelEngine):Bool
	{
		return game.GetProperty(NO_START_TALK_MUSIC);
	}
	//endregion

	//region 出怪池

	public static var ENEMY_POOL:PropertyMeta<Array<NamespaceID>> = Get("enemyPool");
	public static function GetEnemyPool(game:LevelEngine):Null<Array<NamespaceID>>
	{
		return game.GetProperty(ENEMY_POOL);
	}
	public static function SetEnemyPool(game:LevelEngine, value:Array<NamespaceID>):Void
	{
		game.SetProperty(ENEMY_POOL, value);
	}
	//endregion

	//region 波次
	public static var WAVE_MAX_TIME:PropertyMeta<Float> = Get("waveMaxTime", 0.0);
	public static var WAVE_ADVANCE_TIME:PropertyMeta<Float> = Get("waveAdvanceTime", 0.0);
	public static var WAVE_ADVANCE_HEALTH_PERCENT:PropertyMeta<Float> = Get("waveAdvanceHealthPercent", 0.0);
	public static function GetWaveMaxSeconds(level:LevelEngine):Float
	{
		return level.GetProperty(WAVE_MAX_TIME);
	}
	public static function GetWaveAdvanceSeconds(level:LevelEngine):Float
	{
		return level.GetProperty(WAVE_ADVANCE_TIME);
	}
	public static function GetWaveAdvanceHealthPercent(level:LevelEngine):Float
	{
		return level.GetProperty(WAVE_ADVANCE_HEALTH_PERCENT);
	}
	//endregion

	//region 无能量
	public static var NO_ENERGY:PropertyMeta<Bool> = Get("noEnergy", false);
	public static function IsNoEnergy(game:LevelEngine):Bool
	{
		return game.GetProperty(NO_ENERGY);
	}
	public static function SetNoEnergy(game:LevelEngine, value:Bool):Void
	{
		game.SetProperty(NO_ENERGY, value);
	}
	//endregion

	//region 自动收集
	public static var AUTO_COLLECT_ALL:PropertyMeta<Bool> = Get("autoCollectAll", false);
	public static var AUTO_COLLECT_ENERGY:PropertyMeta<Bool> = Get("autoCollectEnergy", false);
	public static var AUTO_COLLECT_MONEY:PropertyMeta<Bool> = Get("autoCollectMoney", false);
	public static var AUTO_COLLECT_STARSHARD:PropertyMeta<Bool> = Get("autoCollectStarshard", false);
	public static function IsAutoCollectAll(game:LevelEngine):Bool
	{
		return game.GetProperty(AUTO_COLLECT_ALL);
	}
	public static function IsAutoCollectEnergy(game:LevelEngine):Bool
	{
		return game.GetProperty(AUTO_COLLECT_ENERGY);
	}
	public static function IsAutoCollectMoney(game:LevelEngine):Bool
	{
		return game.GetProperty(AUTO_COLLECT_MONEY);
	}
	public static function IsAutoCollectStarshard(game:LevelEngine):Bool
	{
		return game.GetProperty(AUTO_COLLECT_STARSHARD);
	}
	//endregion

	//region 开局位置
	public static var START_TRANSITION:PropertyMeta<String> = Get("startTransition");
	public static var START_CAMERA_POSITION:PropertyMeta<Int> = Get("startCameraPosition", 0);
	public static function GetStartTransition(stage:StageDefinition):Null<String>
	{
		return stage.GetProperty(START_TRANSITION);
	}
	public static function GetStartCameraPosition(stage:StageDefinition):LevelCameraPosition
	{
		return cast stage.GetProperty(START_CAMERA_POSITION);
	}
	//endregion

	//region 通关掉落
	public static var CLEAR_PICKUP_MODEL:PropertyMeta<NamespaceID> = Get("clearPickupModel");
	public static var CLEAR_PICKUP_CONTENT_ID:PropertyMeta<NamespaceID> = Get("clear_pickup_content_id");
	public static var CLEAR_SOUND:PropertyMeta<NamespaceID> = Get("clearSound");
	public static var DROPS_TROPHY:PropertyMeta<Bool> = Get("dropsTrophy", false);
	public static function GetClearPickupModel(level:LevelEngine):Null<NamespaceID>
	{
		return level.GetProperty(CLEAR_PICKUP_MODEL);
	}
	public static function GetClearPickupContentID(level:LevelEngine):Null<NamespaceID>
	{
		return level.GetProperty(CLEAR_PICKUP_CONTENT_ID);
	}
	public static function DropsTrophy(level:LevelEngine):Bool
	{
		return level.GetProperty(DROPS_TROPHY);
	}
	public static function SetClearSound(stage:StageDefinition, value:NamespaceID):Void
	{
		stage.SetProperty(CLEAR_SOUND, value);
	}
	public static function GetClearSound(level:LevelEngine):Null<NamespaceID>
	{
		return level.GetProperty(CLEAR_SOUND);
	}
	//endregion

	//region 统计
	public static var HIDE_IN_STATS:PropertyMeta<Bool> = Get("hide_in_stats", false);
	public static function HideInStats(entityDef:StageDefinition):Bool
	{
		return entityDef.GetProperty(HIDE_IN_STATS);
	}
	//endregion

	private function new() {}
}
