// Ported from: Assets/Scripts/MVZ2/Options/SerializableOptionsV1.cs
package mvz2.options;
import mvz2.options.KeyBindingOptions.SerializableKeyBindingOptions;  // IMPORTAUTO

// [Serializable]
// [BsonIgnoreExtraElements]
@:rtti
class SerializableOptionsV1 {
    public function new() {}
    public var keyBindings:SerializableKeyBindingOptions;
    public var boolOptions:Map<String, Bool>;
    public var intOptions:Map<String, Int>;
    public var floatOptions:Map<String, Float>;
    public var stringOptions:Map<String, String>;
    public var idOptions:Map<String, String>;
}
