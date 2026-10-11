// Ported from: Assets/Scripts/Engine/Level/SeedPacks/SerializableSeedPack.cs
// PORT-NOTE: C# 的 [Serializable] 特性无运行期语义，此处省略（移植层的序列化由 tools 的 Bson 序列化器实现）。
package pvzengine.seedpacks;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.auras.SerializableAuraEffect;
import pvzengine.buffs.SerializableBuffList;
import pvzengine.level.PropertyBlock.SerializablePropertyBlock;

@:rtti
class SerializableSeedPack
{
	// PORT-NOTE: Haxe 4.3 不再为无构造函数的类自动生成默认构造函数，C# 的隐式默认构造需显式写出。
	public function new() {}
	public var id:Int64;
	public var seedID:Null<NamespaceID>;
	public var currentBuffID:Int64;
	public var buffs:SerializableBuffList;
	public var properties:SerializablePropertyBlock;
	public var auras:Array<SerializableAuraEffect>;
}
@:rtti
class SerializableClassicSeedPack extends SerializableSeedPack
{
	public function new() { super(); }
}
@:rtti
class SerializableConveyorSeedPack extends SerializableSeedPack
{
	public function new() { super(); }
}
