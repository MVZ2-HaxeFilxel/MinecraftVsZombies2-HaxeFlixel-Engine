// Ported from: Assets/Scripts/Engine/Level/Entities/EntitySourceReference.cs
package pvzengine.entities;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.level.ILevelSourceReference;
import pvzengine.level.ILevelSourceTarget;
import pvzengine.level.ISerializableSourceReference;
import pvzengine.level.LevelEngine;

// PORT-NOTE: C# 有私有构造器 (long, NamespaceID, ILevelSourceReference?, int) 与两个公开构造器
//   ((Entity) / (LevelEngine, SerializableEntitySourceReference))，Haxe 无重载，
//   合并为一个按首参类型分派的方法：首参为 LevelEngine 走反序列化分支，
//   为 Entity 走实体分支，否则视为 Clone() 使用的字段记录（见 Clone 的 PORT-NOTE）。
@:rtti
class EntitySourceReference implements ILevelSourceReference
{
	public function new(source:Dynamic, ?seri:Dynamic)
	{
		if (Std.isOfType(source, LevelEngine))
		{
			LoadFromSerializable(cast source, cast seri);
			return;
		}
		if (Std.isOfType(source, Entity))
		{
			var entity:Entity = cast source;
			id = entity.ID;
			definitionID = entity.Definition.GetID();
			parent = entity.SpawnerReference != null ? entity.SpawnerReference.Clone() : null;
			faction = entity.Cache.Faction;
			return;
		}
		var raw:{id:Int64, definitionID:NamespaceID, parent:Null<ILevelSourceReference>, faction:Int} = cast source;
		id = raw.id;
		definitionID = raw.definitionID;
		parent = raw.parent;
		faction = raw.faction;
	}
	// C#: public EntitySourceReference(LevelEngine level, SerializableEntitySourceReference seri)
	public function LoadFromSerializable(level:LevelEngine, seri:SerializableEntitySourceReference):Void
	{
		id = seri.id;
		definitionID = seri.definitionID;
		parent = seri.parent != null ? seri.parent.ToDeserialized(level) : null;
		faction = seri.faction;
	}
	public function Clone():EntitySourceReference
	{
		// PORT-NOTE: 对应 C# 私有构造器 new EntitySourceReference(ID, DefinitionID, parent?.Clone(), faction)。
		return new EntitySourceReference({
			id: ID,
			definitionID: DefinitionID,
			parent: parent != null ? parent.Clone() : null,
			faction: faction
		});
	}
	public function GetEntity(game:LevelEngine):Null<Entity>
	{
		return game.FindEntityByID(ID);
	}
	public function Equals(other:Dynamic):Bool
	{
		if (Std.isOfType(other, EntitySourceReference))
		{
			var entityRef:EntitySourceReference = cast other;
			return ID == entityRef.ID;
		}
		return false;
	}
	public function GetHashCode():Int
	{
		// PORT-NOTE: C# long.GetHashCode() 无 Haxe 对应，用 Int64 低 32 位代替（同 ArtifactSourceReference 的既有做法）。
		return ID.low;
	}
	// PORT-NOTE: Haxe 不支持类上的运算符重载（@:op 仅对 abstract 有效，写在 class 上会被静默忽略，
	//   导致 C# 的 `operator ==` 值语义丢失）。本类型因实现 ILevelSourceReference 且需 new 构造，
	//   不能改为 abstract，故按工程既有做法（同 mvz2logic.inputs.PointerData）改为显式静态方法 eq/neq。
	//   C# 中 `refA == refB` 的比较（非 null 判断）需改写为 EntitySourceReference.eq(refA, refB)。
	// TODO-PORT: 上层若存在两个非空引用的值比较调用点，必须改用 eq(...) 或 Equals(...)。
	public static function eq(lhs:EntitySourceReference, rhs:EntitySourceReference):Bool
	{
		if (lhs == null)
			return rhs == null;
		return lhs.Equals(rhs);
	}
	public static function neq(lhs:EntitySourceReference, rhs:EntitySourceReference):Bool
	{
		return !eq(lhs, rhs);
	}
	public function GetTarget(level:LevelEngine):Null<ILevelSourceTarget>
	{
		return GetEntity(level);
	}
	public function ToSerializable():ISerializableSourceReference
	{
		return new SerializableEntitySourceReference(this);
	}
	public var SpawnerReference(get, never):Null<ILevelSourceReference>;
	function get_SpawnerReference():Null<ILevelSourceReference>
	{
		return parent;
	}
	public var Faction(get, never):Int;
	function get_Faction():Int
	{
		return faction;
	}
	public var DefinitionID(get, never):NamespaceID;
	function get_DefinitionID():NamespaceID
	{
		return definitionID;
	}
	public var ID(get, never):Int64;
	function get_ID():Int64
	{
		return id;
	}
	public var Parent(get, never):Null<ILevelSourceReference>;
	function get_Parent():Null<ILevelSourceReference>
	{
		return parent;
	}
	private var definitionID:NamespaceID;
	private var parent:Null<ILevelSourceReference>;
	private var faction:Int = -1;
	private var id:Int64;
}

// Ported from: Assets/Scripts/Engine/Level/Entities/EntitySourceReference.cs (class SerializableEntitySourceReference)
@:rtti
class SerializableEntitySourceReference implements ISerializableSourceReference
{
	public function new(reference:EntitySourceReference)
	{
		definitionID = reference.DefinitionID;
		parent = reference.SpawnerReference != null ? reference.SpawnerReference.ToSerializable() : null;
		faction = reference.Faction;
		id = reference.ID;
	}
	public function ToDeserialized(level:LevelEngine):ILevelSourceReference
	{
		return new EntitySourceReference(level, this);
	}
	public var definitionID:NamespaceID;
	public var parent:Null<ISerializableSourceReference>;
	public var faction:Int = -1;
	public var id:Int64;
}
