// Ported from: Assets/Scripts/Logic/Blueprints/LogicSeedProps.cs
package mvz2logic.blueprints;

import mvz2logic.resources.SpriteReference;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.seedpacks.SeedDefinition;
import pvzengine.seedpacks.SeedPack;

@:propertyRegistryRegion(PropertyRegions.seed)
class LogicSeedProps
{
	static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	//region 图标
	public static var ICON:PropertyMeta<SpriteReference> = Get("icon");
	public static function GetIcon(seed:SeedDefinition):Null<SpriteReference>
	{
		return seed.GetProperty(ICON);
	}
	// TODO-PORT: C# 重载 GetIcon(this SeedPack)，Haxe 不支持重载，重命名为 GetIconOfPack
	public static function GetIconOfPack(seed:SeedPack):Null<SpriteReference>
	{
		return seed.GetProperty(ICON);
	}
	public static function SetIcon(seed:SeedDefinition, value:Null<SpriteReference>):Void
	{
		seed.SetProperty(ICON, value);
	}
	//endregion

	//region 移动端图标
	public static var MOBILE_ICON:PropertyMeta<SpriteReference> = Get("mobile_icon");
	public static function GetMobileIcon(seed:SeedDefinition):Null<SpriteReference>
	{
		return seed.GetProperty(MOBILE_ICON);
	}
	// TODO-PORT: C# 重载 GetMobileIcon(this SeedPack)，Haxe 不支持重载，重命名为 GetMobileIconOfPack
	public static function GetMobileIconOfPack(seed:SeedPack):Null<SpriteReference>
	{
		return seed.GetProperty(MOBILE_ICON);
	}
	public static function SetMobileIcon(seed:SeedDefinition, value:Null<SpriteReference>):Void
	{
		seed.SetProperty(MOBILE_ICON, value);
	}
	//endregion

	//region 模型ID
	public static var MODEL_ID:PropertyMeta<NamespaceID> = Get("model_id");
	public static function GetModelID(seed:SeedDefinition):Null<NamespaceID>
	{
		return seed.GetProperty(MODEL_ID);
	}
	// TODO-PORT: C# 重载 GetModelID(this SeedPack)，Haxe 不支持重载，重命名为 GetModelIDOfPack
	public static function GetModelIDOfPack(seed:SeedPack):Null<NamespaceID>
	{
		return seed.GetProperty(MODEL_ID);
	}
	public static function SetModelID(seed:SeedDefinition, value:Null<NamespaceID>):Void
	{
		seed.SetProperty(MODEL_ID, value);
	}
	//endregion

	//region 实体变种
	public static var VARIANT:PropertyMeta<Int> = Get("variant", 0);
	public static function GetVariant(seed:SeedDefinition):Int
	{
		return seed.GetProperty(VARIANT);
	}
	// TODO-PORT: C# 重载 GetVariant(this SeedPack)，Haxe 不支持重载，重命名为 GetVariantOfPack
	public static function GetVariantOfPack(seed:SeedPack):Int
	{
		return seed.GetProperty(VARIANT);
	}
	public static function SetVariant(seed:SeedDefinition, value:Int):Void
	{
		seed.SetProperty(VARIANT, value);
	}
	//endregion

	//region 升级器械蓝图
	public static var UPGRADE_BLUEPRINT:PropertyMeta<Bool> = Get("upgradeBlueprint", false);
	// TODO-PORT: C# 重载 IsUpgradeBlueprint(this SeedPack)，Haxe 不支持重载，重命名为 IsUpgradeBlueprintOfPack
	public static function IsUpgradeBlueprintOfPack(seed:SeedPack):Bool
	{
		return seed.GetProperty(UPGRADE_BLUEPRINT);
	}
	public static function IsUpgradeBlueprint(definition:SeedDefinition):Bool
	{
		return definition.GetProperty(UPGRADE_BLUEPRINT);
	}
	//endregion

	//region 蓝图类型
	public static var SEED_TYPE:PropertyMeta<Int> = Get("seedType", 0);
	public static function GetSeedType(definition:SeedDefinition):Int
	{
		return definition.GetProperty(SEED_TYPE);
	}
	// TODO-PORT: C# 重载 GetSeedType(this SeedPack)，Haxe 不支持重载，重命名为 GetSeedTypeOfPack
	public static function GetSeedTypeOfPack(seedPack:SeedPack):Int
	{
		return seedPack.GetProperty(SEED_TYPE);
	}
	//endregion

	//region 蓝图实体ID
	public static var SEED_ENTITY_ID:PropertyMeta<NamespaceID> = Get("seedEntityId");
	public static function GetSeedEntityID(definition:SeedDefinition):Null<NamespaceID>
	{
		return definition.GetProperty(SEED_ENTITY_ID);
	}
	// TODO-PORT: C# 重载 GetSeedEntityID(this SeedPack)，Haxe 不支持重载，重命名为 GetSeedEntityIDOfPack
	public static function GetSeedEntityIDOfPack(seedPack:SeedPack):Null<NamespaceID>
	{
		return seedPack.GetProperty(SEED_ENTITY_ID);
	}
	//endregion

	//region 蓝图选项ID
	public static var SEED_OPTION_ID:PropertyMeta<NamespaceID> = Get("seedOptionId");
	public static function GetSeedOptionID(definition:SeedDefinition):Null<NamespaceID>
	{
		return definition.GetProperty(SEED_OPTION_ID);
	}
	// TODO-PORT: C# 重载 GetSeedOptionID(this SeedPack)，Haxe 不支持重载，重命名为 GetSeedOptionIDOfPack
	public static function GetSeedOptionIDOfPack(seedPack:SeedPack):Null<NamespaceID>
	{
		return seedPack.GetProperty(SEED_OPTION_ID);
	}
	//endregion

	//region 可触发
	public static var TRIGGER_ACTIVE:PropertyMeta<Bool> = Get("triggerActive", false);
	public static function IsTriggerActive(definition:SeedDefinition):Bool
	{
		return definition.GetProperty(TRIGGER_ACTIVE);
	}
	// TODO-PORT: C# 重载 IsTriggerActive(this SeedPack)，Haxe 不支持重载，重命名为 IsTriggerActiveOfPack
	public static function IsTriggerActiveOfPack(seedPack:SeedPack):Bool
	{
		return seedPack.GetProperty(TRIGGER_ACTIVE);
	}
	//endregion

	//region 可立即触发
	public static var CAN_INSTANT_TRIGGER:PropertyMeta<Bool> = Get("canInstantTrigger", false);
	public static function CanInstantTrigger(definition:SeedDefinition):Bool
	{
		return definition.GetProperty(CAN_INSTANT_TRIGGER);
	}
	//endregion

	//region 可立即激发
	public static var CAN_INSTANT_EVOKE:PropertyMeta<Bool> = Get("canInstantEvoke", false);
	public static function CanInstantEvoke(definition:SeedDefinition):Bool
	{
		return definition.GetProperty(CAN_INSTANT_EVOKE);
	}
	//endregion

	//region 闪烁
	public static var TWINKLING:PropertyMeta<Bool> = Get("twinkling", false);
	public static function IsTwinkling(seed:SeedPack):Bool
	{
		return seed.GetProperty(TWINKLING);
	}
	public static function SetTwinkling(seed:SeedPack, value:Bool):Void
	{
		seed.SetProperty(TWINKLING, value);
	}
	//endregion

	//region 命令方块
	public static var COMMAND_BLOCK:PropertyMeta<Bool> = Get("command_block", false);
	// TODO-PORT: C# 方法名为 IsCommandBlock(this SeedPack)，与 SeedPack 引擎方法同名，为便于静态调用加 OfPack 后缀
	public static function IsCommandBlockOfPack(seed:SeedPack):Bool
	{
		return seed.GetProperty(COMMAND_BLOCK);
	}
	// TODO-PORT: C# 方法名为 SetCommandBlock(this SeedPack, bool)，为便于静态调用加 OfPack 后缀
	public static function SetCommandBlockOfPack(seed:SeedPack, value:Bool):Void
	{
		seed.SetProperty(COMMAND_BLOCK, value);
	}
	//endregion

	private function new() {}
}
