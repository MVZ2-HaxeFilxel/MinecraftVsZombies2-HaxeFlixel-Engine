// Ported from: Assets/Scripts/Logic/Artifacts/ArtifactSourceReference.cs
package mvz2logic.artifacts;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.entities.Entity;
import pvzengine.level.ILevelSourceReference;
import pvzengine.level.ILevelSourceTarget;
import pvzengine.level.ISerializableSourceReference;
import pvzengine.level.LevelEngine;
using mvz2logic.level.LogicLevelExt;

@:rtti
class ArtifactSourceReference implements ILevelSourceReference
{
	// PORT-NOTE: C# 有三个构造函数 (long,NamespaceID) / (Artifact) / (LevelEngine, SerializableArtifactSourceReference)，
	// Haxe 不支持重载，拆为静态工厂 + 主构造函数。
	public function new(id:Int64, defID:NamespaceID)
	{
		this.id = id;
		definitionID = defID;
	}
	public static function FromArtifact(artifact:Artifact):ArtifactSourceReference
	{
		return new ArtifactSourceReference(artifact.Level.GetArtifactIndex(artifact), artifact.Definition.GetID());
	}
	public static function FromSerializable(level:LevelEngine, seri:SerializableArtifactSourceReference):ArtifactSourceReference
	{
		return new ArtifactSourceReference(seri.id, seri.definitionID);
	}
	public function Clone():ArtifactSourceReference
	{
		return new ArtifactSourceReference(id, definitionID);
	}
	public function GetEntity(game:LevelEngine):Null<Entity>
	{
		return null;
	}
	public function Equals(obj:Dynamic):Bool
	{
		if (Std.isOfType(obj, ArtifactSourceReference))
		{
			var entityRef:ArtifactSourceReference = cast obj;
			return ID == entityRef.ID;
		}
		return false; // PORT-NOTE: C# base.Equals(obj) 为引用相等
	}
	public function GetHashCode():Int
	{
		// PORT-NOTE: C# long.GetHashCode() 无 Haxe 对应，用 Int64 低 32 位代替。
		return id.low;
	}
	// PORT-NOTE: C# 定义了 operator == / !=，Haxe 不支持运算符重载，调用处请改用 Equals。

	public function GetTarget(level:LevelEngine):Null<ILevelSourceTarget>
	{
		return GetEntity(level);
	}
	public function ToSerializable():ISerializableSourceReference
	{
		return new SerializableArtifactSourceReference(this);
	}
	public var Faction(get, never):Int;
	private function get_Faction():Int
	{
		return 0;
	}
	public var DefinitionID(get, never):NamespaceID;
	private function get_DefinitionID():NamespaceID
	{
		return definitionID;
	}
	public var ID(get, never):Int64;
	private function get_ID():Int64
	{
		return id;
	}
	public var Parent(get, never):Null<ILevelSourceReference>;
	private function get_Parent():Null<ILevelSourceReference>
	{
		return null;
	}
	private var definitionID:NamespaceID;
	private var id:Int64;
}

// [Serializable]
@:rtti
class SerializableArtifactSourceReference implements ISerializableSourceReference
{
	public var definitionID:NamespaceID;
	public var id:Int64;

	public function new(reference:ArtifactSourceReference)
	{
		definitionID = reference.DefinitionID;
		id = reference.ID;
	}
	public function ToDeserialized(level:LevelEngine):ILevelSourceReference
	{
		// PORT-NOTE: Haxe 无构造函数重载，(LevelEngine, SerializableXxx) 重载合并为单参拷贝构造。
		return new ArtifactSourceReference(this.id, this.definitionID);
	}
}
