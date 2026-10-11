// Ported from: Assets/Scripts/MVZ2/Level/LevelController/SerializableLevelControllerHeader.cs
package mvz2.level;
// PORT-NOTE: 以下类型是同包其他模块的次类型，Haxe 需显式从所属模块导入。
import mvz2.level.LevelManager.LevelDataIdentifierList;

// PORT-NOTE: C# 的 [BsonIgnoreExtraElements] 特性在 Haxe 中无对应语义，保留为元数据。
@:bsonIgnoreExtraElements
@:rtti
class SerializableLevelControllerHeader
{
	public var identifiers:LevelDataIdentifierList;
	public function new() {}
}
