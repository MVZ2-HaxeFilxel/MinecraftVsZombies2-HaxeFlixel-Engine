// Ported from: Assets/Scripts/Engine/Tools/RNG/SerializableRNG.cs
package tools;

@:rtti
class SerializableRNG
{
	public function new(x:Int, y:Int, z:Int, w:Int)
	{
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}
	// C#: internal SerializableRNG(XORShift128 generator)
	// PORT-NOTE: Haxe 无 internal 修饰符（同包可见性由可见性规则近似表达），保持 public。
	public static function fromGenerator(generator:XORShift128):SerializableRNG
	{
		return new SerializableRNG(Std.int(generator.x), Std.int(generator.y), Std.int(generator.z), Std.int(generator.w));
	}
	public var x:Int;
	public var y:Int;
	public var z:Int;
	public var w:Int;
}
