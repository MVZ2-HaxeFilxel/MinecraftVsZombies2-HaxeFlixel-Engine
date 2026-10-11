// Ported from: Assets/Scripts/MVZ2/Level/Components/Light/LightSourceInfo.cs
package mvz2.level.components;

import haxe.Int64;

// 对应 C# 的 [Serializable] class SerializableLightSourceInfo
@:rtti
class SerializableLightSourceInfo
{
	public var id:Int64;
	public var illuminatingEntities:Array<Int64>;
	public function new() {}
}
