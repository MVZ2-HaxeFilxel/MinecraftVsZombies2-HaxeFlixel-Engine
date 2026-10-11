// Ported from: Assets/Scripts/Engine/Level/SeedPacks/EngineSeedProps.cs
// PORT-NOTE: 该 C# 文件的 namespace 为 PVZEngine.Level（文件位于 Level/SeedPacks/ 目录，属 SeedPacks 工作包）。
//   既有上层调用点两种 import 并存：`pvzengine.seedpacks.EngineSeedProps`（7 处）与
//   `pvzengine.level.EngineSeedProps`（6 处）。按「以既有调用点为准」，实现放在多数调用点使用的
//   pvzengine.seedpacks 包，并在 pvzengine.level 下提供同名 typedef 别名（pvzengine/level/EngineSeedProps.hx）。
package pvzengine.seedpacks;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;

@:propertyRegistryRegion(PropertyRegions.seed)
class EngineSeedProps
{
	private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	public static var RECHARGE_ID:PropertyMeta<NamespaceID> = Get("rechargeId");
	public static var COST:PropertyMeta<Float> = Get("cost", 0.0);

	public static var RECHARGE_SPEED:PropertyMeta<Float> = Get("rechargeSpeed", 0.0);
	public static var RECHARGE:PropertyMeta<Float> = Get("recharge", 0.0);
	public static var IS_START_RECHARGE:PropertyMeta<Bool> = Get("isStartRecharge", false);
	public static var DISABLE_ID:PropertyMeta<NamespaceID> = Get("disableID");
	public static function GetRechargeSpeed(seed:SeedPack):Float
	{
		return seed.GetProperty(RECHARGE_SPEED);
	}
	public static function GetRecharge(seed:SeedPack):Float
	{
		return seed.GetProperty(RECHARGE);
	}
	public static function SetRecharge(seed:SeedPack, value:Float):Void
	{
		seed.SetProperty(RECHARGE, value);
	}
	public static function AddRecharge(seed:SeedPack, value:Float):Void
	{
		SetRecharge(seed, GetRecharge(seed) + value);
	}
	public static function GetRechargeID(seed:SeedPack):Null<NamespaceID>
	{
		return seed.GetProperty(RECHARGE_ID);
	}
	// PORT-NOTE: C# 另有重载 GetRechargeID(this SeedDefinition)，Haxe 不支持重载，重命名为 GetRechargeIDOfDefinition
	//   （与 mvz2logic/blueprints/LogicSeedProps.hx 的重载命名约定一致）。
	public static function GetRechargeIDOfDefinition(definition:SeedDefinition):Null<NamespaceID>
	{
		return definition.GetProperty(RECHARGE_ID);
	}
	public static function GetCost(definition:SeedDefinition):Float
	{
		return definition.GetProperty(COST);
	}
	public static function IsStartRecharge(seed:SeedPack):Bool
	{
		return seed.GetProperty(IS_START_RECHARGE);
	}
	/**
	 * 将卡牌的重装载时间设置为初始或已被使用。
	 */
	public static function SetStartRecharge(seed:SeedPack, value:Bool):Void
	{
		seed.SetProperty(IS_START_RECHARGE, value);
	}
	public static function IsDisabled(seed:SeedPack):Bool
	{
		return NamespaceID.IsValid(GetDisableID(seed));
	}
	public static function GetDisableID(seed:SeedPack):Null<NamespaceID>
	{
		return seed.GetProperty(DISABLE_ID);
	}
	public static function FullRecharge(seed:SeedPack):Void
	{
		SetRecharge(seed, GetMaxRecharge(seed));
	}
	public static function IsCharged(seed:SeedPack):Bool
	{
		return GetRecharge(seed) >= GetMaxRecharge(seed);
	}
	public static function ResetRecharge(seed:SeedPack):Void
	{
		SetRecharge(seed, 0);
	}
	public static function GetMaxRecharge(seed:SeedPack):Int
	{
		return IsStartRecharge(seed) ? seed.GetStartMaxRecharge() : seed.GetUsedMaxRecharge();
	}
	// #region 传送带
	public static var DRAWN_CONVEYOR_SEED:PropertyMeta<NamespaceID> = Get("drawnConveyorSeed");
	public static function GetDrawnConveyorSeed(seed:SeedPack):Null<NamespaceID>
	{
		return seed.GetProperty(DRAWN_CONVEYOR_SEED);
	}
	public static function SetDrawnConveyorSeed(seed:SeedPack, value:Null<NamespaceID>):Void
	{
		seed.SetProperty(DRAWN_CONVEYOR_SEED, value);
	}
	// #endregion
}
