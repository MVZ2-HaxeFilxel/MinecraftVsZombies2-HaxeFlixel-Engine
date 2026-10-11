// Ported from: Assets/Scripts/Engine/Level/Buffs/SerializableBuffList.cs
// PORT-NOTE: C# [Serializable] → Haxe 序列化由 mvz2logic.serialization.SerializeHelper 按类名注册处理。
// PORT-NOTE: C# List<SerializableBuff>? → Array<SerializableBuff>（元素允许 null）。
package pvzengine.buffs;

import haxe.Int64;

@:rtti
class SerializableBuffList
{
	// PORT-NOTE: Haxe 4.3 不再为无构造函数的类自动生成默认构造函数，C# 的隐式默认构造需显式写出。
	public function new() {}
	public var buffs:Array<SerializableBuff>;
	public var currentBuffID:Int64;
}
