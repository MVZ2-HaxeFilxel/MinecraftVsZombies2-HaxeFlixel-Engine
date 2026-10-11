// Ported from: Assets/Scripts/Engine/Level/Level/SerializableConveyorSeedSpendRecords.cs
package pvzengine.level;

import pvzengine.NamespaceID;

@:rtti
class SerializableConveyorSeedSpendRecords
{
	public var entries:Array<Null<SerializableConveyorSeedSendRecordEntry>>;

	public function new() {}
}

// C#: [BsonIgnoreExtraElements]
// PORT-NOTE: MongoDB Bson 特性在 Haxe 中无对应语义，保留为元数据（与本工程其它已移植的 Serializable* 一致）。
@:bsonIgnoreExtraElements
@:rtti
class SerializableConveyorSeedSendRecordEntry
{
	public var id:Null<NamespaceID>;
	public var spend:Int;
	public var discardCount:Int;

	public function new() {}
}
