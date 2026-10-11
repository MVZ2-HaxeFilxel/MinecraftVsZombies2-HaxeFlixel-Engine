// Ported from: Assets/Scripts/Logic/Grids/LogicGridProps.cs
package mvz2logic.grids;

import mvz2logic.models.SortingLayers;
import mvz2logic.resources.SpriteReference;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.grids.GridDefinition;
import pvzengine.grids.LawnGrid;

@:propertyRegistryRegion(PropertyRegions.grid)
class LogicGridProps
{
	static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	public static var IS_SLAB:PropertyMeta<Bool> = Get("is_slab", false);
	public static function IsSlab(grid:LawnGrid):Bool
	{
		return grid.GetProperty(IS_SLAB);
	}
	public static var IS_WATER:PropertyMeta<Bool> = Get("is_water", false);
	// TODO-PORT: C# 重载 IsWater(this GridDefinition)，Haxe 不支持重载，重命名为 IsWaterOfDefinition
	public static function IsWaterOfDefinition(definition:GridDefinition):Bool
	{
		return definition.GetProperty(IS_WATER);
	}
	public static function IsWater(grid:LawnGrid):Bool
	{
		return grid.GetProperty(IS_WATER);
	}
	public static var IS_AIR:PropertyMeta<Bool> = Get("is_air", false);
	// TODO-PORT: C# 重载 IsCloud(this GridDefinition)，Haxe 不支持重载，重命名为 IsCloudOfDefinition
	public static function IsCloudOfDefinition(definition:GridDefinition):Bool
	{
		return definition.GetProperty(IS_AIR);
	}
	public static function IsCloud(grid:LawnGrid):Bool
	{
		return grid.GetProperty(IS_AIR);
	}
	public static function IsLand(grid:LawnGrid):Bool
	{
		return !IsWater(grid) && !IsCloud(grid);
	}
	public static var IS_WET:PropertyMeta<Bool> = Get("is_wet", false);
	public static function IsWet(grid:LawnGrid):Bool
	{
		return grid.GetProperty(IS_WET);
	}

	//region 斜率
	public static var SLOPE:PropertyMeta<Float> = Get("slope", 0.0);
	public static function GetSlope(grid:LawnGrid):Float
	{
		return grid.GetProperty(SLOPE);
	}
	public static function SetSlope(grid:GridDefinition, value:Float):Void
	{
		grid.SetProperty(SLOPE, value);
	}
	//endregion

	//region 遮盖贴图
	public static var OVERLAY_SPRITE:PropertyMeta<SpriteReference> = Get("overlay_sprite");
	public static function GetOverlaySprite(grid:LawnGrid):Null<SpriteReference>
	{
		return grid.GetProperty(OVERLAY_SPRITE);
	}
	public static function SetOverlaySprite(grid:GridDefinition, value:SpriteReference):Void
	{
		grid.SetProperty(OVERLAY_SPRITE, value);
	}
	//endregion

	//region 禁用
	public static var DISABLED:PropertyMeta<Bool> = Get("disabled", false);
	public static function IsDisabled(grid:LawnGrid):Bool
	{
		return grid.GetProperty(DISABLED);
	}
	//endregion

	//region 排序层
	public static var SORTING_LAYER:PropertyMeta<String> = Get("sorting_layer", SortingLayers.ground);
	public static function GetSortingLayer(grid:LawnGrid):Null<String>
	{
		return grid.GetProperty(SORTING_LAYER);
	}
	//endregion

	//region 排序顺序
	public static var SORTING_ORDER:PropertyMeta<Int> = Get("sorting_order", 0);
	public static function GetSortingOrder(grid:LawnGrid):Int
	{
		return grid.GetProperty(SORTING_ORDER);
	}
	//endregion

	private function new() {}
}
