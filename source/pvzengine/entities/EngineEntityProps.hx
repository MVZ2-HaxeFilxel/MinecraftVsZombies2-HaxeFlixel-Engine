// Ported from: Assets/Scripts/Engine/Level/Entities/EngineEntityProps.cs
package pvzengine.entities;

import pvzengine.NamespaceID;
import pvzengine.PropertyMeta;
import unity.Color;
import unity.Vector3;

// PORT-NOTE: C# 扩展方法 -> Haxe 静态工具类；实例写法（entity.GetMaxHealth()、entity.IsFlipX()、
// entityDef.GetShellID()）通过 Entity / EntityDefinition 上的
// `@:using(pvzengine.entities.EngineEntityProps)` 保留。
// PORT-NOTE: C# 中有若干同名重载同时挂到 Entity 与 EntityDefinition（GetGravity/GetSize/GetBoundsPivot/
// GetBoundsOffset/GetShellID/GetGridPivotOffset）。Haxe 同一类内不能重名，故合并为一个以 Dynamic
// 接收者并按运行期类型分派的方法，保持两种调用点都能用原名调用。
// PORT-NOTE: C# `Get<T>(name, T? defaultValue = default)` 的 `default` 对值类型为 0/false/零向量。
// Haxe 的 Unity shim 里 Vector3 / Color 是引用类型，缺省实参会是 null，因此对这两种类型显式传入
// Vector3.zero / Color.clear（与 C# default(Vector3)/default(Color) 等价）。
// PORT-NOTE: C# 原文的类上有 `[PropertyRegistryRegion(PropertyRegions.entity)]`
// （Assets/Scripts/Engine/Level/Entities/EngineEntityProps.cs:7），移植时漏掉了该标注；
// PropertyMapper 依赖它给这些属性确定区域，缺失会让全部 entity 属性退化成未注册（键全为 0）。
@:propertyRegistryRegion(PropertyRegions.entity)
class EngineEntityProps
{
	private static function Get<T>(name:String, ?defaultValue:T):PropertyMeta<T>
	{
		return new PropertyMeta<T>(name, defaultValue);
	}

	// #region 默认朝左
	public static var FACE_LEFT_AT_DEFAULT:PropertyMeta<Bool> = Get("faceLeftAtDefault", false);
	public static function FaceLeftAtDefault(entity:Entity):Bool
	{
		return entity.GetProperty(FACE_LEFT_AT_DEFAULT);
	}
	// #endregion

	// #region 无敌
	public static var INVINCIBLE:PropertyMeta<Bool> = Get("invincible", false);
	public static function IsInvincible(entity:Entity):Bool
	{
		return entity.GetProperty(INVINCIBLE);
	}
	// #endregion

	// #region 重力
	public static var GRAVITY:PropertyMeta<Float> = Get("gravity", 0.0);
	// PORT-NOTE: C# 重载 GetGravity(this EntityDefinition) / GetGravity(this Entity) 合并。
	public static function GetGravity(target:Dynamic):Float
	{
		if (Std.isOfType(target, Entity))
			return (cast target:Entity).GetProperty(GRAVITY);
		return (cast target:EntityDefinition).GetProperty(GRAVITY);
	}
	public static function SetGravity(entity:Entity, value:Float):Void
	{
		entity.SetProperty(GRAVITY, value);
	}
	// #endregion

	// #region 水平翻转
	public static var FLIP_X:PropertyMeta<Bool> = Get("flipX", false);
	public static function IsFlipX(entity:Entity):Bool
	{
		return entity.GetProperty(FLIP_X);
	}
	public static function SetFlipX(entity:Entity, flipX:Bool):Void
	{
		entity.SetProperty(FLIP_X, flipX);
	}
	// #endregion

	// #region 体积
	public static var SIZE:PropertyMeta<Vector3> = Get("size", Vector3.zero);
	// PORT-NOTE: C# 重载 GetSize(this EntityDefinition) / GetSize(this Entity, bool) 合并。
	public static function GetSize(target:Dynamic, ignoreBuffs:Bool = false):Vector3
	{
		if (Std.isOfType(target, Entity))
			return cast(cast(target, Entity).GetProperty(SIZE, ignoreBuffs));
		return cast(cast(target, EntityDefinition).GetProperty(SIZE));
	}
	public static function SetSize(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(SIZE, value);
	}
	// #endregion

	// #region 缩放
	public static var SCALE:PropertyMeta<Vector3> = Get("scale", Vector3.zero);
	public static function GetScale(entity:Entity):Vector3
	{
		return cast(entity.GetProperty(SCALE));
	}
	public static function SetScale(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(SCALE, value);
	}
	public static function GetFinalScale(entity:Entity):Vector3
	{
		// PORT-NOTE: C# Vector3 为值类型（赋值即拷贝）；Haxe 的 unity.Vector3 为引用语义，
		//   直接修改会污染实体缓存，故显式构造新值。
		var scale = entity.GetScale();
		var flipX = entity.IsFlipX() ? -1 : 1;
		return new Vector3(scale.x * flipX, scale.y, scale.z);
	}
	// #endregion

	// #region 显示缩放
	public static var DISPLAY_SCALE:PropertyMeta<Vector3> = Get("displayScale", Vector3.zero);
	public static function GetFinalDisplayScale(entity:Entity):Vector3
	{
		// PORT-NOTE: 同 GetFinalScale，避免就地修改污染的引用语义问题。
		var scale = entity.GetDisplayScale();
		var flipX = entity.IsFlipX() ? -1 : 1;
		return new Vector3(scale.x * flipX, scale.y, scale.z);
	}
	public static function GetDisplayScale(entity:Entity):Vector3
	{
		return cast(entity.GetProperty(DISPLAY_SCALE));
	}
	public static function SetDisplayScale(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(DISPLAY_SCALE, value);
	}
	// #endregion

	// #region 移速阻尼
	public static var VELOCITY_DAMPEN:PropertyMeta<Vector3> = Get("velocityDampen", Vector3.zero);
	public static function GetVelocityDampen(entity:Entity):Vector3
	{
		return cast(entity.GetProperty(VELOCITY_DAMPEN));
	}
	public static function SetVelocityDampen(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(VELOCITY_DAMPEN, value);
	}
	// #endregion

	// #region 摩擦力
	public static var FRICTION:PropertyMeta<Float> = Get("friction", 0.0);
	public static function GetFriction(entity:Entity):Float
	{
		return entity.GetProperty(FRICTION);
	}
	public static function SetFriction(entity:Entity, value:Float):Void
	{
		entity.SetProperty(FRICTION, value);
	}
	// #endregion

	// #region 染色
	public static var TINT:PropertyMeta<Color> = Get("tint", Color.clear);
	public static function GetTint(entity:Entity, ignoreBuffs:Bool = false):Color
	{
		return cast(entity.GetProperty(TINT, ignoreBuffs));
	}
	public static function SetTint(entity:Entity, value:Color):Void
	{
		entity.SetProperty(TINT, value);
	}
	// #endregion

	// #region 颜色偏移
	public static var COLOR_OFFSET:PropertyMeta<Color> = Get("colorOffset", Color.clear);
	public static function GetColorOffset(entity:Entity, ignoreBuffs:Bool = false):Color
	{
		return cast(entity.GetProperty(COLOR_OFFSET, ignoreBuffs));
	}
	public static function SetColorOffset(entity:Entity, value:Color):Void
	{
		entity.SetProperty(COLOR_OFFSET, value);
	}
	// #endregion

	// #region 头盔染色
	public static var HELMET_TINT:PropertyMeta<Color> = Get("helmet_tint", Color.white);
	public static function GetHelmetTint(entity:Entity, ignoreBuffs:Bool = false):Color
	{
		return cast(entity.GetProperty(HELMET_TINT, ignoreBuffs));
	}
	public static function SetHelmetTint(entity:Entity, value:Color):Void
	{
		entity.SetProperty(HELMET_TINT, value);
	}
	// #endregion

	// #region 头盔颜色偏移
	public static var HELMET_COLOR_OFFSET:PropertyMeta<Color> = Get("helmet_color_offset", Color.clear);
	public static function GetHelmetColorOffset(entity:Entity, ignoreBuffs:Bool = false):Color
	{
		return cast(entity.GetProperty(HELMET_COLOR_OFFSET, ignoreBuffs));
	}
	public static function SetHelmetColorOffset(entity:Entity, value:Color):Void
	{
		entity.SetProperty(HELMET_COLOR_OFFSET, value);
	}
	// #endregion

	// #region 阵营
	public static var FACTION:PropertyMeta<Int> = Get("faction", 0);
	public static function SetFaction(entity:Entity, value:Int):Void
	{
		entity.SetProperty(FACTION, value);
	}
	// #endregion

	// #region 地面高度偏移
	public static var GROUND_LIMIT_OFFSET:PropertyMeta<Float> = Get("groundLimitOffset", 0.0);
	public static function GetGroundLimitOffset(entity:Entity):Float
	{
		return entity.GetProperty(GROUND_LIMIT_OFFSET);
	}
	// #endregion

	// #region 网格中心偏移
	public static var GRID_PIVOT_OFFSET:PropertyMeta<Vector3> = Get("grid_pivot_offset", Vector3.zero);
	// PORT-NOTE: C# 重载 GetGridPivotOffset(this Entity) / GetGridPivotOffset(this EntityDefinition) 合并。
	public static function GetGridPivotOffset(target:Dynamic):Vector3
	{
		if (Std.isOfType(target, Entity))
			return cast(cast(target, Entity).GetProperty(GRID_PIVOT_OFFSET));
		return cast(cast(target, EntityDefinition).GetProperty(GRID_PIVOT_OFFSET));
	}
	// #endregion

	// #region 碰撞盒中心点
	public static var BOUNDS_PIVOT:PropertyMeta<Vector3> = Get("boundsPivot", Vector3.zero);
	// PORT-NOTE: C# 重载 GetBoundsPivot(this EntityDefinition) / GetBoundsPivot(this Entity, bool) 合并。
	public static function GetBoundsPivot(target:Dynamic, ignoreBuffs:Bool = false):Vector3
	{
		if (Std.isOfType(target, Entity))
			return cast(cast(target, Entity).GetProperty(BOUNDS_PIVOT, ignoreBuffs));
		return cast(cast(target, EntityDefinition).GetProperty(BOUNDS_PIVOT));
	}
	public static function SetBoundsPivot(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(BOUNDS_PIVOT, value);
	}
	// #endregion

	// #region 碰撞盒偏移
	public static var BOUNDS_OFFSET:PropertyMeta<Vector3> = Get("bounds_offset", Vector3.zero);
	// PORT-NOTE: C# 重载 GetBoundsOffset(this EntityDefinition) / GetBoundsOffset(this Entity, bool) 合并。
	public static function GetBoundsOffset(target:Dynamic, ignoreBuffs:Bool = false):Vector3
	{
		if (Std.isOfType(target, Entity))
			return cast(cast(target, Entity).GetProperty(BOUNDS_OFFSET, ignoreBuffs));
		return cast(cast(target, EntityDefinition).GetProperty(BOUNDS_OFFSET));
	}
	public static function SetBoundsOffset(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(BOUNDS_OFFSET, value);
	}
	// #endregion

	// #region 最大血量
	public static var MAX_HEALTH:PropertyMeta<Float> = Get("maxHealth", 0.0);
	public static function GetMaxHealth(entity:Entity, ignoreBuffs:Bool = false):Float
	{
		return entity.GetProperty(MAX_HEALTH, ignoreBuffs);
	}
	// #endregion

	// #region 外壳ID
	public static var SHELL:PropertyMeta<NamespaceID> = Get("shell");
	// PORT-NOTE: C# 重载 GetShellID(this EntityDefinition) / GetShellID(this Entity, bool) 合并。
	public static function GetShellID(target:Dynamic, ignoreBuffs:Bool = false):NamespaceID
	{
		if (Std.isOfType(target, Entity))
			return cast(cast(target, Entity).GetProperty(SHELL, ignoreBuffs));
		return cast(cast(target, EntityDefinition).GetProperty(SHELL));
	}
	public static function SetShellID(entity:Entity, value:NamespaceID):Void
	{
		entity.SetProperty(SHELL, value);
	}
	// #endregion

	// #region 放置ID
	public static var PLACEMENT:PropertyMeta<NamespaceID> = Get("placement");
	public static function GetPlacementID(entity:EntityDefinition):NamespaceID
	{
		return cast(entity.GetProperty(PLACEMENT));
	}
	// #endregion

	// #region 模型ID
	public static var MODEL_ID:PropertyMeta<NamespaceID> = Get("modelId");
	// #endregion

	// #region 碰撞检测
	public static var COLLISION_DETECTION:PropertyMeta<Int> = Get("collisionDetection", 0);
	public static function GetCollisionDetection(entity:Entity):Int
	{
		return entity.GetProperty(COLLISION_DETECTION);
	}
	public static function IsCollisionCheckDisabled(entity:Entity):Bool
	{
		return (entity.GetCollisionDetection() & EntityCollisionHelper.DETECTION_NO_COLLISION) != 0;
	}
	public static function IsCollisionOverlapDisabled(entity:Entity):Bool
	{
		return (entity.GetCollisionDetection() & EntityCollisionHelper.DETECTION_NO_OVERLAP) != 0;
	}
	// #endregion

	// #region 碰撞检测样本长度
	public static var COLLISION_INTERVAL:PropertyMeta<Int> = Get("collision_interval", 0);
	public static function GetCollisionInterval(entity:Entity):Int
	{
		return entity.GetProperty(COLLISION_INTERVAL);
	}
	// #endregion

	// #region 模型位置偏移
	public static var MODEL_POSITION_OFFSET:PropertyMeta<Vector3> = Get("model_position_offset", Vector3.zero);
	public static function GetModelPositionOffset(entity:Entity):Vector3
	{
		return cast(entity.GetProperty(MODEL_POSITION_OFFSET));
	}
	public static function SetModelPositionOffset(entity:Entity, value:Vector3):Void
	{
		entity.SetProperty(MODEL_POSITION_OFFSET, value);
	}
	// #endregion
}
