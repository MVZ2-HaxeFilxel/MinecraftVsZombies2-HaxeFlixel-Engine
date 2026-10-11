// Ported from: Assets/Scripts/Engine/Level/Buffs/SerializableBuff.cs
// PORT-NOTE: C# [Serializable] → Haxe 序列化由 mvz2logic.serialization.SerializeHelper 按类名注册处理
//   （SerializeHelper.hx 注册了 PVZEngine.Buffs.SerializableBuff）。字段名与 C# 保持一致。
// PORT-NOTE: C# 中 auras 为 SerializableAuraEffect?[]?（元素可空），Haxe 数组元素允许 null，故声明为
//   Array<SerializableAuraEffect>。
package pvzengine.buffs;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.SerializablePropertyDictionary;
import pvzengine.auras.SerializableAuraEffect;

@:rtti
class SerializableBuff
{
	// PORT-NOTE: Haxe 4.3 不再为无构造函数的类自动生成默认构造函数，C# 的隐式默认构造需显式写出。
	public function new() {}
	public var id:Int64;
	public var definitionID:NamespaceID;
	public var propertyDict:SerializablePropertyDictionary;
	public var auras:Array<SerializableAuraEffect>;
}
