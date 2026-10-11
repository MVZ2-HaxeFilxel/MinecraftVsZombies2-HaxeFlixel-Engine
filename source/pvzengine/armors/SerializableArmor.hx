// Ported from: Assets/Scripts/Engine/Level/Armors/SerializableArmor.cs
// PORT-NOTE: C# [Serializable] → Haxe 序列化由 mvz2logic.serialization.SerializeHelper 按类名注册处理
//   （SerializeHelper.hx 注册了 PVZEngine.Armors.SerializableArmor）。字段名与 C# 保持一致。
// PORT-NOTE: C# [Obsolete] public long currentBuffID → 保留字段并标注（Haxe 用 @:deprecated 之外的注释形式）。
// PORT-NOTE: C# SerializableAuraEffect[]? auras → Array<SerializableAuraEffect>（元素允许 null）。
package pvzengine.armors;

import haxe.Int64;
import pvzengine.NamespaceID;
import pvzengine.auras.SerializableAuraEffect;
import pvzengine.buffs.SerializableBuffList;
// PORT-NOTE: C# 中 SerializablePropertyBlock 与 PropertyBlock 同处 PropertyBlock.cs，
//   移植层为 pvzengine.level.PropertyBlock 模块的子类型，import 需写模块路径。
import pvzengine.level.PropertyBlock.SerializablePropertyBlock;

@:rtti
class SerializableArmor
{
	// PORT-NOTE: Haxe 4.3 不再为无构造函数的类自动生成默认构造函数，C# 的隐式默认构造需显式写出。
	public function new() {}
	public var definitionID:NamespaceID;
	public var health:Float;
	public var slot:NamespaceID;
	// [Obsolete]
	public var currentBuffID:Int64;
	public var buffs:SerializableBuffList;
	public var properties:SerializablePropertyBlock;
	public var auras:Array<SerializableAuraEffect>;
}
