// Ported from: Assets/Scripts/Engine/Level/Entities/SerializableEntity.cs
package pvzengine.entities;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.armors.SerializableArmor;
import pvzengine.auras.SerializableAuraEffect;
import pvzengine.buffs.SerializableBuffList;
import pvzengine.damages.SerializableDeathInfo;
import pvzengine.level.ILevelSourceReference;
import pvzengine.level.PropertyBlock.SerializablePropertyBlock;
import tools.SerializableRNG;
import unity.Vector3;

// PORT-NOTE: C# 的 `Dictionary<string, T>?` → Haxe `Map<String, T>`；`T[]?` → `Array<T>`。
@:rtti
class SerializableEntity
{
	public function new() {}

	public var id:Int64;
	public var time:Int64;
	// [Obsolete]
	public var type:Int;
	public var state:Int;
	public var target:Int64;
	public var parent:Int64;
	public var initSeed:Int;
	public var rng:Null<SerializableRNG>;
	public var dropRng:Null<SerializableRNG>;
	public var definitionID:Null<NamespaceID>;
	public var modelID:Null<NamespaceID>;
	// [Obsolete]
	public var spawnerReference:Null<EntitySourceReference>;
	public var spawnerSource:Null<ILevelSourceReference>;
	public var previousPosition:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var position:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var velocity:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var scale:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var collisionMaskHostile:Int;
	public var collisionMaskFriendly:Int;
	public var renderRotation:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var renderScale:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var takenConveyorSeeds:Null<Map<String, Int>>;
	public var timeout:Int;

	// #region 影子
	public var shadowVisible:Bool;
	public var shadowAlpha:Float;
	public var shadowScale:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	public var shadowOffset:Vector3 = new Vector3(0, 0, 0); // PORT-NOTE: C# Vector3 为 struct，默认 (0,0,0)；显式初始化避免 abstract-over-class 的 null 解引用
	// #endregion

	public var armors:Null<Map<String, SerializableArmor>>;

	public var isDead:Bool;
	public var lethalDeathInfo:Null<SerializableDeathInfo>;
	public var health:Float;
	public var isOnGround:Bool;
	// [Obsolete]
	public var currentBuffID:Int64;
	public var properties:Null<SerializablePropertyBlock>;
	public var buffs:Null<SerializableBuffList>;
	public var children:Null<Array<Int64>>;
	// [Obsolete]
	public var takenGrids:Null<Array<TakenGridInfo>>;
	public var takenGridIndexes:Null<Array<Int>>;

	public var auras:Array<SerializableAuraEffect>;
}

// Ported from: Assets/Scripts/Engine/Level/Entities/SerializableEntity.cs (class TakenGridInfo)
// [Serializable] [Obsolete]
class TakenGridInfo
{
	public function new() {}

	public var grid:Int;
	public var layers:Array<NamespaceID>;
}
