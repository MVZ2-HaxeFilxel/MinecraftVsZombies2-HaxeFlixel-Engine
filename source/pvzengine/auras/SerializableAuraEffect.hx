// Ported from: Assets/Scripts/Engine/Level/Aura/SerializableAuraEffect.cs
// PORT-NOTE: C# [Serializable] → Haxe 序列化由 mvz2logic.serialization.SerializeHelper 按类名注册处理。
// PORT-NOTE: C# BuffReference[]? buffs → Array<BuffReference>（元素允许 null）。
package pvzengine.auras;

import pvzengine.buffs.BuffReference;
import tools.FrameTimer;

@:rtti
class SerializableAuraEffect
{
	// PORT-NOTE: Haxe 4.3 不再为无构造函数的类自动生成默认构造函数，C# 的隐式默认构造需显式写出。
	public function new() {}
	public var id:Int;
	public var updateTimer:FrameTimer;
	public var buffs:Array<BuffReference>;
}
