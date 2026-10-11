// Ported from: Assets/Scripts/Logic/Entities/LogicEntityProps.cs
package mvz2logic.entities;

import mvz2logic.conditions.IConditionList;
import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import pvzengine.PropertyRegions;
import pvzengine.entities.Entity;
import pvzengine.entities.EntityCollisionHelper;
import pvzengine.entities.EntityDefinition;
import pvzengine.grids.LawnGrid;
import pvzengine.level.LevelEngine;
import unity.Color;
import unity.Mathf.FloatRef;
import unity.Vector3;
import unity.Vector2Int;

@:propertyRegistryRegion(PropertyRegions.entity)
class LogicEntityProps
{
	static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}
	//region 形状ID
	public static var SHAPE:PropertyMeta<NamespaceID> = Get("shape");
	// TODO-PORT: C# 重载 GetShapeID(this EntityDefinition)，Haxe 不支持重载，重命名为 GetShapeIDOfDefinition
	public static function GetShapeIDOfDefinition(definition:EntityDefinition):Null<NamespaceID>
	{
		return definition.GetProperty(SHAPE);
	}
	public static function GetShapeID(entity:Entity, ignoreBuffs:Bool = false):Null<NamespaceID>
	{
		return entity.GetProperty(SHAPE, ignoreBuffs);
	}
	public static function SetShapeID(entity:Entity, value:NamespaceID):Void
	{
		entity.SetProperty(SHAPE, value);
	}
	//endregion

	//region 实体名称
	public static var NAME:PropertyMeta<String> = Get("name");
	public static function GetEntityName(definition:EntityDefinition):Null<String>
	{
		return definition.GetProperty(NAME);
	}
	public static function SetEntityName(entity:EntityDefinition, value:String):Void
	{
		entity.SetProperty(NAME, value);
	}
	//endregion

	//region 实体工具提示
	public static var TOOLTIP:PropertyMeta<String> = Get("tooltip");
	public static function GetEntityTooltip(definition:EntityDefinition):Null<String>
	{
		return definition.GetProperty(TOOLTIP);
	}
	public static function SetEntityTooltip(entity:EntityDefinition, value:String):Void
	{
		entity.SetProperty(TOOLTIP, value);
	}
	//endregion

	//region 死亡信息
	public static var DEATH_MESSAGE:PropertyMeta<String> = Get("death_message");
	public static function GetDeathMessage(definition:EntityDefinition):Null<String>
	{
		return definition.GetProperty(DEATH_MESSAGE);
	}
	public static function SetDeathMessage(entity:EntityDefinition, value:String):Void
	{
		entity.SetProperty(DEATH_MESSAGE, value);
	}
	//endregion

	//region 解锁
	public static var UNLOCK:PropertyMeta<IConditionList> = Get("unlock");
	public static function GetEntityUnlock(definition:EntityDefinition):Null<IConditionList>
	{
		return definition.GetProperty(UNLOCK);
	}
	//endregion

	//region 掉落物目标点
	public static var PICKUP_DESTINATION:PropertyMeta<Int> = Get("pickup_destination", 0);
	// TODO-PORT: C# 重载 GetPickupDestination(this EntityDefinition)，Haxe 不支持重载，重命名为 GetPickupDestinationOfDefinition
	public static function GetPickupDestinationOfDefinition(definition:EntityDefinition):Int
	{
		return definition.GetProperty(PICKUP_DESTINATION);
	}
	public static function GetPickupDestination(entity:Entity):Int
	{
		return entity.GetProperty(PICKUP_DESTINATION);
	}
	//endregion

	//region 变种
	public static var VARIANT:PropertyMeta<Int> = Get("variant", 0);
	public static function GetVariant(entity:Entity):Int
	{
		return entity.GetProperty(VARIANT);
	}
	public static function SetVariant(entity:Entity, value:Int):Void
	{
		entity.SetProperty(VARIANT, value);
	}
	//endregion

	//region 能量消耗
	public static var COST:PropertyMeta<Int> = Get("cost", 0);
	public static function GetCost(entity:Entity):Int
	{
		return entity.GetProperty(COST);
	}
	// TODO-PORT: C# 重载 GetCost(this EntityDefinition)，Haxe 不支持重载，重命名为 GetCostOfDefinition
	public static function GetCostOfDefinition(entity:EntityDefinition):Int
	{
		return entity.GetProperty(COST);
	}
	//endregion

	//region 充能时间
	public static var RECHARGE_ID:PropertyMeta<NamespaceID> = Get("rechargeId");
	public static function GetRechargeID(entity:Entity):Null<NamespaceID>
	{
		return entity.GetProperty(RECHARGE_ID);
	}
	// TODO-PORT: C# 重载 GetRechargeID(this EntityDefinition)，Haxe 不支持重载，重命名为 GetRechargeIDOfDefinition
	public static function GetRechargeIDOfDefinition(entity:EntityDefinition):Null<NamespaceID>
	{
		return entity.GetProperty(RECHARGE_ID);
	}
	//endregion

	//region 更新
	public static var UPDATE_BEFORE_GAME:PropertyMeta<Bool> = Get("updateBeforeGame", false);
	public static var UPDATE_IN_PAUSE:PropertyMeta<Bool> = Get("updateInPause", false);
	public static var UPDATE_AFTER_GAME_OVER:PropertyMeta<Bool> = Get("updateAfterGameOver", false);
	public static function SetCanUpdateBeforeGameStart(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(UPDATE_BEFORE_GAME, value);
	}
	public static function CanUpdateBeforeGameStart(entity:Entity):Bool
	{
		return entity.GetProperty(UPDATE_BEFORE_GAME);
	}
	public static function CanUpdateInPause(entity:Entity):Bool
	{
		return entity.GetProperty(UPDATE_IN_PAUSE);
	}
	public static function CanUpdateAfterGameOver(entity:Entity):Bool
	{
		return entity.GetProperty(UPDATE_AFTER_GAME_OVER);
	}
	//endregion

	//region 击中音效
	public static var HIT_SOUND:PropertyMeta<NamespaceID> = Get("hitSound");
	public static function GetHitSound(entity:Entity):Null<NamespaceID>
	{
		return entity.GetProperty(HIT_SOUND);
	}
	//endregion

	//region 放置音效
	public static var PLACE_SOUND:PropertyMeta<NamespaceID> = Get("placeSound");
	// TODO-PORT: C# 重载 GetPlaceSound(this EntityDefinition)，Haxe 不支持重载，重命名为 GetPlaceSoundOfDefinition
	public static function GetPlaceSoundOfDefinition(definition:EntityDefinition):Null<NamespaceID>
	{
		return definition.GetProperty(PLACE_SOUND);
	}
	public static function GetPlaceSound(entity:Entity):Null<NamespaceID>
	{
		return entity.GetProperty(PLACE_SOUND);
	}
	//endregion

	//region 死亡音效
	public static var DEATH_SOUND:PropertyMeta<NamespaceID> = Get("deathSound");
	public static function GetDeathSound(entity:Entity):Null<NamespaceID>
	{
		return entity.GetProperty(DEATH_SOUND);
	}
	//endregion

	//region HSV
	public static var HSV_OFFSET:PropertyMeta<Vector3> = Get("hsv_offset", new Vector3(0, 0, 0));
	public static function SetHSVOffset(entity:Entity, h:Float, s:Float, v:Float):Void
	{
		SetHSVOffsetByVector(entity, new Vector3(h, s, v));
	}
	// TODO-PORT: C# 重载 SetHSVOffset(this Entity, Vector3)，Haxe 不支持重载，重命名为 SetHSVOffsetByVector
	public static function SetHSVOffsetByVector(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(HSV_OFFSET, value);
	}
	public static function GetHSVOffset(entity:Entity):Vector3
	{
		return entity.GetProperty(HSV_OFFSET);
	}
	public static function SetHSVToColor(entity:Entity, srcColor:Color):Void
	{
		SetHSVToColorFrom(entity, srcColor, Color.red);
	}
	// TODO-PORT: C# 重载 SetHSVToColor(this Entity, Color, Color)，Haxe 不支持重载，重命名为 SetHSVToColorFrom
	public static function SetHSVToColorFrom(entity:Entity, srcColor:Color, dstColor:Color):Void
	{
		var srcH:FloatRef = {value: 0};
		var srcS:FloatRef = {value: 0};
		var srcV:FloatRef = {value: 0};
		Color.RGBToHSV(srcColor, srcH, srcS, srcV);
		var dstH:FloatRef = {value: 0};
		var dstS:FloatRef = {value: 0};
		var dstV:FloatRef = {value: 0};
		Color.RGBToHSV(dstColor, dstH, dstS, dstV);
		var h = (srcH.value - dstH.value) * 360;
		var s = (srcS.value - dstS.value) * 100;
		var v = (srcV.value - dstV.value) * 100;
		SetHSVOffset(entity, h, s, v);
	}
	//endregion

	//region 灰度
	public static var GRAYSCALE:PropertyMeta<Bool> = Get("grayscale", false);
	public static function SetGrayscale(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(GRAYSCALE, value);
	}
	public static function IsGrayscale(entity:Entity):Bool
	{
		return entity.GetProperty(GRAYSCALE);
	}
	//endregion

	//region 深度检测
	public static var DEPTH_TEST:PropertyMeta<Bool> = Get("depth_test", false);
	public static function SetDepthTtest(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(DEPTH_TEST, value);
	}
	public static function IsDepthTest(entity:Entity):Bool
	{
		return entity.GetProperty(DEPTH_TEST);
	}
	//endregion

	//region 起始位置偏移
	public static var STARTING_POSITION_OFFSET:PropertyMeta<Vector3> = Get("starting_position_offset", new Vector3(0, 0, 0));
	public static function GetStartingPositionOffset(entityDef:EntityDefinition):Vector3
	{
		return entityDef.GetProperty(STARTING_POSITION_OFFSET);
	}
	//endregion

	//region 光照
	public static var IS_LIGHT_SOURCE:PropertyMeta<Bool> = Get("isLightSource", false);
	public static var LIT_MASK:PropertyMeta<Int> = Get("lit_mask", 0);
	public static var LIGHT_COLOR:PropertyMeta<Color> = Get("lightColor", new Color(0, 0, 0, 0));
	public static var LIGHT_RANGE:PropertyMeta<Vector3> = Get("lightRange", new Vector3(0, 0, 0));
	public static function SetLightSource(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(IS_LIGHT_SOURCE, value);
	}
	// TODO-PORT: C# 重载 IsLightSource(this EntityDefinition)，Haxe 不支持重载，重命名为 IsLightSourceOfDefinition
	public static function IsLightSourceOfDefinition(definition:EntityDefinition):Bool
	{
		return definition.GetProperty(IS_LIGHT_SOURCE);
	}
	public static function IsLightSource(entity:Entity):Bool
	{
		return entity.GetProperty(IS_LIGHT_SOURCE);
	}
	public static function GetLitMask(entity:Entity):Int
	{
		return entity.GetProperty(LIT_MASK);
	}
	public static function ReceivesLightBy(entity:Entity, lightSource:Entity):Bool
	{
		return ReceivesLightByType(entity, lightSource.Type);
	}
	// TODO-PORT: C# 重载 ReceivesLightBy(this Entity, int)，Haxe 不支持重载，重命名为 ReceivesLightByType
	public static function ReceivesLightByType(entity:Entity, lightSourceType:Int):Bool
	{
		var mask = GetLitMask(entity);
		return (mask & EntityCollisionHelper.GetTypeMask(lightSourceType)) != 0;
	}
	public static function SetLightRange(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(LIGHT_RANGE, value);
	}
	public static function GetLightRange(entity:Entity):Vector3
	{
		return entity.GetProperty(LIGHT_RANGE);
	}
	public static function SetLightColor(entity:Entity, value:Color):Void
	{
		entity.SetProperty(LIGHT_COLOR, value);
	}
	public static function GetLightColor(entity:Entity):Color
	{
		return entity.GetProperty(LIGHT_COLOR);
	}
	//endregion

	//region 影子
	public static var SHADOW_HIDDEN:PropertyMeta<Bool> = Get("shadowHidden", false);
	public static var SHADOW_ALPHA:PropertyMeta<Float> = Get("shadowAlpha", 0.0);
	public static var SHADOW_SCALE:PropertyMeta<Vector3> = Get("shadowScale", new Vector3(0, 0, 0));
	public static var SHADOW_OFFSET:PropertyMeta<Vector3> = Get("shadowOffset", new Vector3(0, 0, 0));
	public static function IsShadowHidden(entity:Entity):Bool
	{
		return entity.GetProperty(SHADOW_HIDDEN);
	}
	public static function SetShadowHidden(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(SHADOW_HIDDEN, value);
	}
	public static function GetShadowAlpha(entity:Entity):Float
	{
		return entity.GetProperty(SHADOW_ALPHA);
	}
	public static function SetShadowAlpha(entity:Entity, value:Float):Void
	{
		entity.SetProperty(SHADOW_ALPHA, value);
	}
	public static function GetShadowScale(entity:Entity):Vector3
	{
		return entity.GetProperty(SHADOW_SCALE);
	}
	public static function SetShadowScale(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(SHADOW_SCALE, value);
	}
	public static function GetShadowOffset(entity:Entity):Vector3
	{
		return entity.GetProperty(SHADOW_OFFSET);
	}
	public static function SetShadowOffset(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(SHADOW_OFFSET, value);
	}
	//endregion

	//region 排序
	public static var SORTING_LAYER:PropertyMeta<String> = Get("sortingLayer");
	public static var SORTING_ORDER:PropertyMeta<Int> = Get("sortingOrder", 0);
	public static function GetSortingLayer(entity:Entity):Null<String>
	{
		return entity.GetProperty(SORTING_LAYER);
	}
	public static function SetSortingLayer(entity:Entity, layer:String):Void
	{
		entity.SetProperty(SORTING_LAYER, layer);
	}
	public static function GetSortingOrder(entity:Entity):Int
	{
		return entity.GetProperty(SORTING_ORDER);
	}
	public static function SetSortingOrder(entity:Entity, layer:Int):Void
	{
		entity.SetProperty(SORTING_ORDER, layer);
	}
	//endregion

	//region 血条
	public static var HP_BAR_VISIBILITY:PropertyMeta<Int> = Get("hp_bar_visibility", 0);
	public static function GetHPBarVisibility(entity:Entity):Int
	{
		return entity.GetProperty(HP_BAR_VISIBILITY);
	}
	public static function SetHPBarVisibility(entity:Entity, value:Int):Void
	{
		entity.SetProperty(HP_BAR_VISIBILITY, value);
	}
	//endregion

	//region 血条
	public static var SHOW_HEIGHT_INDICATOR:PropertyMeta<Bool> = Get("show_height_indicator", false);
	public static function ShowHeightIndicator(entity:Entity):Bool
	{
		return entity.GetProperty(SHOW_HEIGHT_INDICATOR);
	}
	public static function SetShowHeightIndicator(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(SHOW_HEIGHT_INDICATOR, value);
	}
	//endregion

	//region 死亡后移除
	public static var REMOVE_ON_DEATH:PropertyMeta<Bool> = Get("remove_on_death", false);
	public static function IsRemoveOnDeath(entity:Entity):Bool
	{
		return entity.GetProperty(REMOVE_ON_DEATH);
	}
	public static function SetRemoveOnDeath(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(REMOVE_ON_DEATH, value);
	}
	//endregion

	//region 死亡效果
	public static var NO_DEATH_EFFECTS:PropertyMeta<Bool> = Get("no_death_effects", false);
	public static function HasNoDeathEffects(entity:Entity):Bool
	{
		return entity.GetProperty(NO_DEATH_EFFECTS);
	}
	public static function SetNoDeathEffects(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(NO_DEATH_EFFECTS, value);
	}
	//endregion

	//region 死亡效果
	public static var NO_NEUTRALIZE_ON_DEATH:PropertyMeta<Bool> = Get("no_neutralize_on_death", false);
	public static function NoNeutralizedOnDeath(entity:Entity):Bool
	{
		return entity.GetProperty(NO_NEUTRALIZE_ON_DEATH);
	}
	public static function SetNoNeutralizedOnDeath(entity:Entity, value:Bool):Void
	{
		entity.SetProperty(NO_NEUTRALIZE_ON_DEATH, value);
	}
	//endregion

	//region 动画速度
	public static var ANIMATION_SPEED:PropertyMeta<Float> = Get("animation_speed", 1.0);
	public static function GetAnimationSpeed(entity:Entity):Float
	{
		return entity.GetProperty(ANIMATION_SPEED);
	}
	public static function SetAnimationSpeed(entity:Entity, value:Float):Void
	{
		entity.SetProperty(ANIMATION_SPEED, value);
	}
	//endregion

	//region 铁镐目标
	public static var KILL_BY_PICKAXE:PropertyMeta<Bool> = Get("kill_by_pickaxe", false);
	public static function CanBeKilledByPickaxe(contraption:Entity):Bool
	{
		return contraption.GetProperty(KILL_BY_PICKAXE);
	}
	//endregion

	//region 单元格
	public static var EXTRA_GRIDS:PropertyMeta<Array<Vector2Int>> = Get("extra_grids");
	// TODO-PORT: C# 重载 GetExtraGrids(this EntityDefinition)，Haxe 不支持重载，重命名为 GetExtraGridsOfDefinition
	public static function GetExtraGridsOfDefinition(entity:EntityDefinition):Null<Array<Vector2Int>>
	{
		return entity.GetProperty(EXTRA_GRIDS);
	}
	public static function GetExtraGrids(entity:Entity):Null<Array<Vector2Int>>
	{
		return entity.GetProperty(EXTRA_GRIDS);
	}
	public static function GetGridsToTake(entity:Entity):Array<Null<LawnGrid>>
	{
		return GetGridsToTakeAt(entity.Definition, entity.Level, entity.GetColumn(), entity.GetLane());
	}
	// TODO-PORT: C# 重载 GetGridsToTake(this EntityDefinition, LawnGrid)，Haxe 不支持重载，重命名为 GetGridsToTakeOfGrid
	public static function GetGridsToTakeOfGrid(entity:EntityDefinition, grid:LawnGrid):Array<Null<LawnGrid>>
	{
		return GetGridsToTakeAt(entity, grid.Level, grid.Column, grid.Lane);
	}
	// PORT-NOTE: C# 为迭代器方法（yield return），Haxe 无 yield 语法，改为返回数组。
	// TODO-PORT: C# 重载 GetGridsToTake(this EntityDefinition, LevelEngine, int, int)，Haxe 不支持重载，重命名为 GetGridsToTakeAt
	public static function GetGridsToTakeAt(entity:EntityDefinition, level:LevelEngine, column:Int, lane:Int):Array<Null<LawnGrid>>
	{
		var results:Array<Null<LawnGrid>> = [];
		var gridBelow = level.GetGrid(column, lane);
		results.push(gridBelow);
		var extraGrids = GetExtraGridsOfDefinition(entity);
		if (extraGrids != null)
		{
			for (offset in extraGrids)
			{
				var extraGrid = level.GetGrid(column + offset.x, lane + offset.y);
				results.push(extraGrid);
			}
		}
		return results;
	}

	public static var GRID_LAYERS:PropertyMeta<Array<NamespaceID>> = Get("gridLayers");
	// TODO-PORT: C# 重载 GetGridLayersToTake(this EntityDefinition)，Haxe 不支持重载，重命名为 GetGridLayersToTakeOfDefinition
	public static function GetGridLayersToTakeOfDefinition(entity:EntityDefinition):Null<Array<NamespaceID>>
	{
		return entity.GetProperty(GRID_LAYERS);
	}
	public static function GetGridLayersToTake(entity:Entity):Null<Array<NamespaceID>>
	{
		return entity.GetProperty(GRID_LAYERS);
	}
	public static function SetGridLayersToTake(entity:Entity, value:Null<Array<NamespaceID>>):Void
	{
		entity.SetProperty(GRID_LAYERS, value);
	}
	//endregion

	//region 统计
	public static var HIDE_IN_STATS:PropertyMeta<Bool> = Get("hide_in_stats", false);
	public static function HideInStats(entityDef:EntityDefinition):Bool
	{
		return entityDef.GetProperty(HIDE_IN_STATS);
	}
	//endregion

	private function new() {}
}
