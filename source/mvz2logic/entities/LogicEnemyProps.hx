// Ported from: Assets/Scripts/Logic/Entities/LogicEnemyProps.cs
package mvz2logic.entities;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityDefinition;
import unity.Vector3;

@:propertyRegistryRegion(PropertyRegions.entity)
class LogicEnemyProps
{
	static function Get<T>(name:String, ?defaultValue:T, ?obsoleteNames:Array<String>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue, obsoleteNames);
	}
	//region 叫声
	public static var CRY_SOUND:PropertyMeta<NamespaceID> = Get("crySound");
	public static function GetCrySound(enemy:Entity):Null<NamespaceID>
	{
		return enemy.GetProperty(CRY_SOUND);
	}
	//endregion

	//region 叫声音调
	public static var CRY_PITCH:PropertyMeta<Float> = Get("cryPitch", 0.0);
	public static function GetCryPitch(entity:Entity):Float
	{
		return entity.GetProperty(CRY_PITCH);
	}
	//endregion

	//region 乘客位置
	public static var PASSENGER_OFFSET:PropertyMeta<Vector3> = Get("passengerOffset", new Vector3(0, 0, 0));
	public static function GetPassengerOffset(enemy:Entity):Vector3
	{
		return enemy.GetProperty(PASSENGER_OFFSET);
	}
	//endregion

	//region 预览敌人
	public static var PREVIEW_ENEMY:PropertyMeta<Bool> = Get("previewEnemy", false);
	public static function SetPreviewEnemy(enemy:Entity, value:Bool):Void
	{
		enemy.SetProperty(PREVIEW_ENEMY, value);
	}
	public static function IsPreviewEnemy(enemy:Entity):Bool
	{
		return enemy.GetProperty(PREVIEW_ENEMY);
	}
	//endregion

	//region 假定存活

	public static var ASSUME_ALIVE:PropertyMeta<Bool> = Get("assume_alive", false);
	public static function AssumeAlive(enemy:Entity):Bool
	{
		return enemy.GetProperty(ASSUME_ALIVE);
	}
	//endregion

	//region 有效敌人
	public static var NOT_ACTIVE_ENEMY:PropertyMeta<Bool> = Get("notActiveEnemy", false);
	// TODO-PORT: C# 重载 IsNotActiveEnemy(this EntityDefinition)，Haxe 不支持重载，重命名为 IsNotActiveEnemyOfDefinition
	public static function IsNotActiveEnemyOfDefinition(enemy:EntityDefinition):Bool
	{
		return enemy.GetProperty(NOT_ACTIVE_ENEMY);
	}
	public static function IsNotActiveEnemy(enemy:Entity):Bool
	{
		return enemy.GetProperty(NOT_ACTIVE_ENEMY);
	}
	//endregion

	//region 克制
	public static var COUNTER_TAGS:PropertyMeta<Array<NamespaceID>> = Get("counter_tags", null, ["attackerTags"]);
	public static function GetCounterTags(enemy:EntityDefinition):Null<Array<NamespaceID>>
	{
		return enemy.GetProperty(COUNTER_TAGS);
	}
	//endregion

	//region 无害
	/// <summary>
	/// 无法进屋
	/// </summary>
	public static var HARMLESS:PropertyMeta<Bool> = Get("harmless", false);
	// TODO-PORT: C# 重载 IsHarmless(this EntityDefinition)，Haxe 不支持重载，重命名为 IsHarmlessOfDefinition
	public static function IsHarmlessOfDefinition(enemy:EntityDefinition):Bool
	{
		return enemy.GetProperty(HARMLESS);
	}
	public static function IsHarmless(enemy:Entity):Bool
	{
		return enemy.GetProperty(HARMLESS);
	}
	//endregion

	private function new() {}
}
