// Ported from: Assets/Scripts/Engine/Level/Entities/GridSourceReference.cs
package pvzengine.grids;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import pvzengine.level.ILevelSourceReference;
import pvzengine.level.ILevelSourceTarget;
import pvzengine.level.ISerializableSourceReference;
import pvzengine.level.LevelEngine;

// PORT-NOTE: C# 有私有构造器 (int index, NamespaceID defID) 与两个公开构造器
//   ((LawnGrid) / (LevelEngine, SerializableGridSourceReference))，Haxe 无重载，
//   合并为一个按首参类型分派的方法（首参为 LevelEngine 时走反序列化分支；
//   其余非 LawnGrid 的实参视为 Clone() 使用的字段记录，见 Clone 的 PORT-NOTE）。
@:rtti
class GridSourceReference implements ILevelSourceReference
{
	public function new(source:Dynamic, ?seri:Dynamic)
	{
		if (Std.isOfType(source, LevelEngine))
		{
			LoadFromSerializable(cast source, cast seri);
			return;
		}
		if (Std.isOfType(source, LawnGrid))
		{
			var grid:LawnGrid = cast source;
			index = grid.GetIndex();
			definitionID = grid.Definition.GetID();
			return;
		}
		var raw:{index:Int, definitionID:NamespaceID} = cast source;
		index = raw.index;
		definitionID = raw.definitionID;
	}
	// C#: public GridSourceReference(LevelEngine level, SerializableGridSourceReference seri)
	public function LoadFromSerializable(level:LevelEngine, seri:SerializableGridSourceReference):Void
	{
		index = seri.index;
		definitionID = seri.definitionID;
	}
	public function Clone():GridSourceReference
	{
		// PORT-NOTE: 对应 C# 私有构造器 new GridSourceReference(index, definitionID)。
		return new GridSourceReference({index: index, definitionID: definitionID});
	}
	public function GetEntity(game:LevelEngine):Null<Entity>
	{
		return null;
	}
	public function Equals(other:Dynamic):Bool
	{
		if (Std.isOfType(other, GridSourceReference))
		{
			var entityRef:GridSourceReference = cast other;
			return ID == entityRef.ID;
		}
		return false;
	}
	public function GetHashCode():Int
	{
		// PORT-NOTE: C# long.GetHashCode() 无 Haxe 对应，用 Int64 低 32 位代替（同 EntityID / ArtifactSourceReference 的既有做法）。
		return ID.low;
	}
	// PORT-NOTE: 同 EntitySourceReference —— Haxe 类上的 @:op 会被静默忽略，改为显式静态方法 eq/neq
	//   （本类型实现 ILevelSourceReference 且需 new 构造，无法改为 abstract）。
	public static function eq(lhs:GridSourceReference, rhs:GridSourceReference):Bool
	{
		if (lhs == null)
			return rhs == null;
		return lhs.Equals(rhs);
	}
	public static function neq(lhs:GridSourceReference, rhs:GridSourceReference):Bool
	{
		return !eq(lhs, rhs);
	}
	public function GetTarget(level:LevelEngine):Null<ILevelSourceTarget>
	{
		// PORT-NOTE: C# `level.GetGrid(index)`；Haxe 侧 LevelEngine 同时存在 GetGrid(column, lane) 重载，
		//   故按 C# 定义（index = lane * maxColumnCount + column）换算后调用二参版本。
		return level.GetGrid(level.GetGridColumnByIndex(index), level.GetGridLaneByIndex(index));
	}
	public function ToSerializable():ISerializableSourceReference
	{
		return new SerializableGridSourceReference(this);
	}
	public var Faction(get, never):Int;
	function get_Faction():Int
	{
		return 0;
	}
	public var DefinitionID(get, never):NamespaceID;
	function get_DefinitionID():NamespaceID
	{
		return definitionID;
	}
	public var ID(get, never):Int64;
	function get_ID():Int64
	{
		return haxe.Int64.ofInt(index);
	}
	public var Parent(get, never):Null<ILevelSourceReference>;
	function get_Parent():Null<ILevelSourceReference>
	{
		return null;
	}
	private var definitionID:NamespaceID;
	private var index:Int;
}

// Ported from: Assets/Scripts/Engine/Level/Entities/GridSourceReference.cs (class SerializableGridSourceReference)
@:rtti
class SerializableGridSourceReference implements ISerializableSourceReference
{
	public function new(reference:GridSourceReference)
	{
		definitionID = reference.DefinitionID;
		// PORT-NOTE: C# `(int)reference.ID`（long → int 显式转换）→ Haxe `haxe.Int64.toInt`。
		index = haxe.Int64.toInt(reference.ID);
	}
	public function ToDeserialized(level:LevelEngine):ILevelSourceReference
	{
		return new GridSourceReference(level, this);
	}
	public var definitionID:NamespaceID;
	public var index:Int;
}
