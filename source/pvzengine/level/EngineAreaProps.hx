// Ported from: Assets/Scripts/Engine/Level/Level/EngineAreaProps.cs
package pvzengine.level;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;

// C#: [PropertyRegistryRegion(PropertyRegions.level)]
@:propertyRegistryRegion(PropertyRegions.level)
class EngineAreaProps
{
	private static function Get<T>(name:String, ?defaultValue:Null<T>):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	public static var GRID_WIDTH:PropertyMeta<Float> = Get("GridWidth", 0.0);
	public static var GRID_HEIGHT:PropertyMeta<Float> = Get("GridHeight", 0.0);
	public static var GRID_LEFT_X:PropertyMeta<Float> = Get("GridLeftX", 0.0);
	public static var GRID_BOTTOM_Z:PropertyMeta<Float> = Get("GridBottomZ", 0.0);
	public static var ENEMY_SPAWN_X:PropertyMeta<Float> = Get("enemySpawnX", 0.0);
	public static var ENTITY_LANE_Z_OFFSET:PropertyMeta<Float> = Get("EntityLawnZOffset", 0.0);
	public static var MAX_LANE_COUNT:PropertyMeta<Int> = Get("MaxLaneCount", 0);
	public static var MAX_COLUMN_COUNT:PropertyMeta<Int> = Get("MaxColumnCount", 0);
	public static var CART_REFERENCE:PropertyMeta<NamespaceID> = Get("cartReference");
	public static var AREA_TAGS:PropertyMeta<Array<NamespaceID>> = Get("areaTags");

	// PORT-NOTE: C# 的两个 GetAreaTags 重载（AreaDefinition / LevelEngine）在 Haxe 中合并为
	// Dynamic 形参 + 运行期分派（同 pvzengine.buffs.BuffTargetExt 的既有做法）。
	// 既有调用点：`level.GetAreaTags()`（LogicLevelExt.hx:647）、`areaDef.GetAreaTags()`（SpawnEndlessBehaviour.hx:21）。
	public static function GetAreaTags(target:Dynamic):Array<NamespaceID>
	{
		if (Std.isOfType(target, AreaDefinition))
			return (cast target:AreaDefinition).GetProperty(AREA_TAGS);
		return (cast target:LevelEngine).GetProperty(AREA_TAGS);
	}
	public static function GetEnemySpawnX(level:LevelEngine):Float
	{
		return level.GetProperty(ENEMY_SPAWN_X);
	}
	public static function GetCartReference(level:LevelEngine):Null<NamespaceID>
	{
		return level.GetProperty(CART_REFERENCE);
	}
}
