// Ported from: Assets/Scripts/Logic/Entities/LogicContraptionProps.cs
package mvz2logic.entities;

import mvz2logic.level.LogicLevelExt;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityDefinition;
import pvzengine.level.LevelEngine;

@:propertyRegistryRegion(PropertyRegions.entity)
class LogicContraptionProps
{
	static function Get<T>(name:String, ?defaultValue:T, ?obsoleteNames:Array<String>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue, obsoleteNames);
	}
	//region 升级蓝图
	public static var UPGRADE_BLUEPRINT:PropertyMeta<Bool> = Get("upgradeBlueprint", false);
	// TODO-PORT: C# 重载 IsUpgradeBlueprint(this EntityDefinition)，Haxe 不支持重载，重命名为 IsUpgradeBlueprintOfDefinition
	public static function IsUpgradeBlueprintOfDefinition(definition:EntityDefinition):Bool
	{
		return definition.GetProperty(UPGRADE_BLUEPRINT);
	}
	public static function IsUpgradeBlueprint(contraption:Entity):Bool
	{
		return contraption.GetProperty(UPGRADE_BLUEPRINT);
	}
	//endregion

	//region 可触发
	public static var TRIGGER_ACTIVE:PropertyMeta<Bool> = Get("triggerActive", false);
	public static function SetTriggerActive(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(TRIGGER_ACTIVE, value);
	}
	// TODO-PORT: C# 重载 IsTriggerActive(this EntityDefinition)，Haxe 不支持重载，重命名为 IsTriggerActiveOfDefinition
	public static function IsTriggerActiveOfDefinition(definition:EntityDefinition):Bool
	{
		return definition.GetProperty(TRIGGER_ACTIVE);
	}
	public static function IsTriggerActive(entity:Entity):Bool
	{
		return entity.GetProperty(TRIGGER_ACTIVE);
	}
	//endregion

	//region 立即触发
	public static var INSTANT_TRIGGER:PropertyMeta<Bool> = Get("instantTrigger", false);
	public static function CanInstantTrigger(definition:EntityDefinition):Bool
	{
		return definition.GetProperty(INSTANT_TRIGGER);
	}
	//endregion

	//region 立即激发
	public static var INSTANT_EVOKE:PropertyMeta<Bool> = Get("instantEvoke", false);
	public static function CanInstantEvoke(definition:EntityDefinition):Bool
	{
		return definition.GetProperty(INSTANT_EVOKE);
	}
	public static function WillInstantEvoke(definition:EntityDefinition, level:LevelEngine):Bool
	{
		if (definition == null)
			return false;
		if (!CanInstantEvoke(definition))
			return false;
		if (LogicLevelExt.IsDay(level) && IsNocturnalOfDefinition(definition))
			return false;
		return true;
	}
	//endregion

	//region 不能激发
	public static var NO_EVOKE:PropertyMeta<Bool> = Get("no_evoke", false);
	public static function NoEvoke(entity:Entity):Bool
	{
		return entity.GetProperty(NO_EVOKE);
	}
	//endregion

	//region 夜用
	public static var NOCTURNAL:PropertyMeta<Bool> = Get("nocturnal", false);
	// TODO-PORT: C# 重载 IsNocturnal(this EntityDefinition)，Haxe 不支持重载，重命名为 IsNocturnalOfDefinition
	public static function IsNocturnalOfDefinition(definition:EntityDefinition):Bool
	{
		return definition.GetProperty(NOCTURNAL);
	}
	public static function IsNocturnal(entity:Entity):Bool
	{
		return entity.GetProperty(NOCTURNAL);
	}
	//endregion

	//region 克制
	public static var COUNTER_TAGS_FOR:PropertyMeta<Array<NamespaceID>> = Get("counter_for", null, ["attackerFor"]);
	public static function GetCounterTagsFor(contraption:EntityDefinition):Null<Array<NamespaceID>>
	{
		return contraption.GetProperty(COUNTER_TAGS_FOR);
	}
	//endregion

	//region 激发
	public static var PROP_EVOKED:PropertyMeta<Bool> = Get("evoked", false);
	public static function IsEvoked(contraption:Entity):Bool
	{
		return contraption.GetProperty(PROP_EVOKED);
	}
	public static function SetEvoked(contraption:Entity, value:Bool):Void
	{
		contraption.SetProperty(PROP_EVOKED, value);
	}
	//endregion

	//region 无法挖掘
	public static var CANNOT_DIG:PropertyMeta<Bool> = Get("cannotDig", false);
	public static function CannotDig(contraption:Entity):Bool
	{
		return contraption.GetProperty(CANNOT_DIG);
	}
	//endregion

	private function new() {}
}
