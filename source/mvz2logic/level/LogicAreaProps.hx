// Ported from: Assets/Scripts/Logic/Level/LogicAreaProps.cs
package mvz2logic.level;

import mvz2logic.resources.SpriteReference;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.level.AreaDefinition;
import pvzengine.level.LevelEngine;
import unity.Color;

@:propertyRegistryRegion(PropertyRegions.level)
class LogicAreaProps
{
	static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	//region 模型ID
	public static var MODEL_ID:PropertyMeta<NamespaceID> = Get("modelID");
	public static function GetModelID(game:LevelEngine):Null<NamespaceID>
	{
		return game.GetProperty(MODEL_ID);
	}
	// TODO-PORT: C# 重载 GetModelID(this AreaDefinition definition)，Haxe 不支持重载，重命名为 GetModelIDFromArea
	public static function GetModelIDFromArea(definition:AreaDefinition):Null<NamespaceID>
	{
		return definition.GetProperty(MODEL_ID);
	}
	//endregion

	//region 星之碎片图标
	public static var STARSHARD_ICON:PropertyMeta<SpriteReference> = Get("starshardIcon");
	public static function GetStarshardIcon(game:LevelEngine):Null<SpriteReference>
	{
		return game.GetProperty(STARSHARD_ICON);
	}
	//endregion

	//region 光照
	public static var BACKGROUND_LIGHT:PropertyMeta<Color> = Get("backgroundLight", Color.white);
	public static var GLOBAL_LIGHT:PropertyMeta<Color> = Get("globalLight", Color.white);
	public static function GetBackgroundLight(level:LevelEngine):Color
	{
		return level.GetProperty(BACKGROUND_LIGHT);
	}
	public static function GetGlobalLight(level:LevelEngine):Color
	{
		return level.GetProperty(GLOBAL_LIGHT);
	}
	public static var BACKGROUND_TINT:PropertyMeta<Color> = Get("background_tint", Color.white);
	public static function GetBackgroundTint(level:LevelEngine):Color
	{
		return level.GetProperty(BACKGROUND_TINT);
	}
	//endregion

	//region 门位置
	public static var DOOR_Z:PropertyMeta<Float> = Get("doorZ", 0.0);
	public static function GetDoorZ(game:LevelEngine):Float
	{
		return game.GetProperty(DOOR_Z);
	}
	//endregion

	private function new() {}
}
