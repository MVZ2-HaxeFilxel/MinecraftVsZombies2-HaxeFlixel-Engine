// Ported from: Assets/Scripts/Engine/Level/Level/SerializableLevelOption.cs
package pvzengine.level;

@:rtti
class SerializableLevelOption
{
	public var leftFaction:Int;
	public var rightFaction:Int;
	public var tps:Int;
	public var cardSlotCount:Int;
	public var starshardSlotCount:Int;
	public var maxEnergy:Float;

	public function new() {}
}
