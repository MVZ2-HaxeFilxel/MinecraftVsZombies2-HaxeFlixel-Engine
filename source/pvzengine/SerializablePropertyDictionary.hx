// Ported from: Assets/Scripts/Engine/Base/Properties/PropertyDictionary.cs (class SerializablePropertyDictionary)
package pvzengine;

// PORT-NOTE: C# 的 `Dictionary<string, object?>` 在 Haxe 中用 Map<String, Dynamic> 表示。
// 该类型名必须保持 "PVZEngine.SerializablePropertyDictionary"，序列化按类名登记（见 SerializeHelper）。
@:rtti
class SerializablePropertyDictionary
{
    public function new(properties:Map<String, Dynamic>)
    {
        this.properties = properties;
    }
    public var properties:Map<String, Dynamic>;
}
