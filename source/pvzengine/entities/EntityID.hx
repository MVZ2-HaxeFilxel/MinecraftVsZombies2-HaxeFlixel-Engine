// Ported from: Assets/Scripts/Engine/Level/Entities/EntityID.cs
package pvzengine.entities;

import unity.UnityObject;
import pvzengine.level.LevelEngine;

// PORT-NOTE: C# 的 `long` -> `haxe.Int64`；C# 的三个构造重载（无参 / long / Entity）在 Haxe 中
// 合并为一个 `?value:Dynamic` 构造器。
// PORT-NOTE: C# 的 `operator ==` / `Equals` 在 Haxe 中改为显式静态方法 `eq`/`neq` + `Equals`
// （Haxe 不支持 class 上的 @:op，只对 abstract 有效；见 eq 处的说明）。
// 注意 Haxe 的 Array.indexOf/remove 在静态目标上使用引用相等，不经过 eq，因此
// 以 EntityID 为元素的数组查找与 C# 的 List<T>.IndexOf(Equals) 语义存在差异（见 TODO-PORT）。
class EntityID
{
	public function new(?value:Dynamic)
	{
		if (value == null)
		{
			id = haxe.Int64.ofInt(0);
			return;
		}
		if (Std.isOfType(value, Entity))
		{
			var entity:Entity = cast value;
			entityFound = true;
			entityCache = entity;
			id = entity != null ? entity.ID : haxe.Int64.ofInt(0);
		}
		else
		{
			id = ToInt64(value);
		}
	}
	// PORT-NOTE: C# 的 long 形参在 Haxe 中为 haxe.Int64，这里兼容传入普通 Int 的调用点。
	private static function ToInt64(value:Dynamic):haxe.Int64
	{
		if (Std.isOfType(value, Int))
			return haxe.Int64.ofInt(cast(value, Int));
		return cast value;
	}
	public function GetEntity(game:LevelEngine):Null<Entity>
	{
		if (!entityFound)
		{
			entityFound = true;
			entityCache = game.FindEntityByID(ID);
		}
		return entityCache;
	}
	public function IsEntity(entity:Entity):Bool
	{
		return ID == entity.ID;
	}
	public function Exists(game:LevelEngine):Bool
	{
		var entity = GetEntity(game);
		return entity != null && unity.UnityObject.exists(entity);
	}
	public function Equals(other:Dynamic):Bool
	{
		if (Std.isOfType(other, EntityID))
		{
			var entityRef:EntityID = cast other;
			return ID == entityRef.ID;
		}
		return false;
	}
	public function GetHashCode():Int
	{
		// PORT-NOTE: C# long.GetHashCode() 无 Haxe 对应，用 Int64 低 32 位代替（同 ArtifactSourceReference 的既有做法）。
		return ID.low;
	}
	// PORT-NOTE: C# 的 `operator ==` / `operator !=` 在 Haxe 中无法作用于 class（@:op 仅对 abstract 有效，
	//   写在 class 上会被静默忽略，`a == b` 退化为引用相等）。本类型保留为 class（Bson 序列化按字段
	//   反射处理，改 abstract 会破坏序列化），按工程既有做法（同 mvz2logic.inputs.PointerData）
	//   改为显式静态方法 eq/neq；`a == null` / `a != null` 不受影响。
	// TODO-PORT: 上层若存在两个非空 EntityID 的值比较调用点，必须改用 EntityID.eq(...) 或 Equals(...)。
	public static function eq(lhs:EntityID, rhs:EntityID):Bool
	{
		if (lhs == null)
			return rhs == null;
		if (rhs == null)
			return false;
		return lhs.Equals(rhs);
	}
	public static function neq(lhs:EntityID, rhs:EntityID):Bool
	{
		return !eq(lhs, rhs);
	}
	public function toString():String
	{
		return Std.string(ID);
	}

	public var ID(default, null):haxe.Int64;
	// TODO-PORT: C# List<EntityID>.IndexOf/Remove 走 Equals；Haxe Array 的同名方法用引用相等。
	// 需要值语义查找的调用点（如 TheGiant 的僵尸块列表）应改为按 ID 比较。
	private var id:haxe.Int64;

	private var entityFound:Bool;
	private var entityCache:Null<Entity>;
}
