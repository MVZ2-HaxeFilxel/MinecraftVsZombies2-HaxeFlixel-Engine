// Ported from: Assets/Scripts/Engine/Level/Entities/EngineEntityExt.cs
package pvzengine.entities;

import pvzengine.NamespaceID;
import pvzengine.PropertyKey;
import pvzengine.PropertyMeta;
import pvzengine.level.ILevelSourceReference;
import pvzengine.level.LevelEngine;
import pvzengine.shells.ShellDefinition;
import tools.FrameTimer;
import unity.Vector3;
import unity.UnityObject;
using pvzengine.ContentProviderHelper;

// PORT-NOTE: C# 扩展方法 -> Haxe 静态工具类。既有调用点同时存在两种写法：
//   * 静态形式：EngineEntityExt.IsHostile(a, b)
//   * 实例形式：entity.GetMaxHealth()、entity.Spawn(...)、entity.ExistsAndAlive()
// 实例形式通过在 Entity / EntityDefinition 上加 `@:using(pvzengine.entities.EngineEntityExt)`
// 与 `using pvzengine.entities.EngineEntityExt;` 保留（PORTING.md §扩展方法）。
// PORT-NOTE: C# 的 `Spawn` 有 4 个重载（NamespaceID/SpawnParams、NamespaceID、NamespaceID+seed、
// EntityDefinition），Haxe 不支持重载，合并为一个按运行期实参分派的方法。
// PORT-NOTE: C# 的 `GetBehaviourField` / `SetBehaviourField` 各有「带 NamespaceID」与「不带」两组重载，
// Haxe 中带 NamespaceID 的版本改名为 GetBehaviourFieldNS / SetBehaviourFieldNS。
class EngineEntityExt
{
	public static function SetBehaviourField<T>(entity:Entity, name:PropertyKey<T>, value:Null<T>):Void
	{
		entity.SetProperty(name, value);
	}
	public static function GetBehaviourField<T>(entity:Entity, name:PropertyKey<T>):Null<T>
	{
		return entity.GetProperty(name);
	}
	// PORT-NOTE: C# 重载 SetBehaviourField<T>(this Entity entity, NamespaceID id, PropertyKey<T> name, T? value)
	public static function SetBehaviourFieldNS<T>(entity:Entity, id:NamespaceID, name:PropertyKey<T>, value:Null<T>):Void
	{
		entity.SetProperty(name, value);
	}
	// PORT-NOTE: C# 重载 GetBehaviourField<T>(this Entity entity, NamespaceID id, PropertyKey<T> name)
	public static function GetBehaviourFieldNS<T>(entity:Entity, id:NamespaceID, name:PropertyKey<T>):Null<T>
	{
		return entity.GetProperty(name);
	}
	public static function GetShellDefinition(entity:Entity):Null<ShellDefinition>
	{
		var shellID = entity.GetShellID();
		if (shellID == null)
			return null;
		return entity.Level.Content.GetShellDefinition(shellID);
	}
	public static function GetDefinitionID(entity:Entity):NamespaceID
	{
		return entity.Definition.GetID();
	}
	// PORT-NOTE: 合并 C# 的 4 个 Spawn 重载；target 为 NamespaceID 或 EntityDefinition，
	// arg1 可为 SpawnParams / seed(Int) / null，arg2 为 SpawnParams。
	public static function Spawn(entity:Entity, target:Dynamic, position:Vector3, ?arg1:Dynamic, ?arg2:Dynamic):Null<Entity>
	{
		if (arg1 == null && arg2 == null)
		{
			return entity.Level.Spawn(target, position, entity);
		}
		if (Std.isOfType(arg1, Int))
		{
			return entity.Level.Spawn(target, position, entity, arg1, arg2);
		}
		return entity.Level.Spawn(target, position, entity, arg1);
	}
	public static function IsHostile(faction1:Int, faction2:Int):Bool
	{
		return faction1 != faction2;
	}
	public static function IsFriendly(faction1:Int, faction2:Int):Bool
	{
		return faction1 == faction2;
	}
	public static function IsFactionTargetEntity(entity:Entity, other:Entity, target:FactionTarget):Bool
	{
		var faction2 = other.Cache.Faction;
		return IsFactionTargetFaction(entity, faction2, target);
	}
	public static function IsFactionTargetFaction(entity:Entity, faction2:Int, target:FactionTarget):Bool
	{
		var faction1 = entity.Cache.Faction;
		return IsFactionTarget(faction1, faction2, target);
	}
	public static function IsFactionTarget(faction1:Int, faction2:Int, target:FactionTarget):Bool
	{
		switch (target)
		{
			case FactionTarget.Any:
				return true;
			case FactionTarget.Friendly:
				return IsFriendly(faction1, faction2);
			case FactionTarget.Hostile:
				return IsHostile(faction1, faction2);
			case _:
				return false;
		}
		return false;
	}
	public static function ExistsAndAlive(entity:Null<Entity>):Bool
	{
		return entity != null && unity.UnityObject.exists(entity) && !entity.IsDead;
	}
	public static function IsEntitySpawnedByEntity(reference:ILevelSourceReference, level:LevelEngine,
		predicate:ILevelSourceReference->EntityDefinition->Bool, trackableOnly:Bool = true):Bool
	{
		if (reference == null)
			return false;
		// PORT-NOTE: C# 的 ArgumentNullException 在 Haxe 中无对应异常类型，改为抛出字符串。
		if (level == null)
			throw "ArgumentNullException: level";
		if (predicate == null)
			throw "ArgumentNullException: predicate";

		var source = reference;
		while (source != null)
		{
			if (!Std.isOfType(source, EntitySourceReference))
				break;
			var entitySource:EntitySourceReference = cast source;
			var definition = level.Content.GetEntityDefinition(entitySource.DefinitionID);
			if (definition == null)
				break;
			if (predicate(source, definition))
			{
				return true;
			}
			if (trackableOnly && !CanEntityTrackSpawnSource(definition))
			{
				break;
			}
			source = source.Parent;
		}
		return false;
	}
	public static function CanEntityTrackSpawnSource(definition:EntityDefinition):Bool
	{
		return definition.Type == EntityTypes.PROJECTILE || definition.Type == EntityTypes.EFFECT || definition.Type == EntityTypes.PICKUP;
	}
	public static function GetOrCreateTimerProperty(entity:Entity, property:PropertyMeta<FrameTimer>, time:Int):FrameTimer
	{
		var timer = entity.GetProperty(property);
		if (timer == null)
		{
			timer = new FrameTimer(time);
			entity.SetProperty(property, timer);
		}
		return timer;
	}
}
