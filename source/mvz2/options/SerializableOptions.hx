// Ported from: Assets/Scripts/MVZ2/Options/SerializableOptions.cs
package mvz2.options;
import mvz2.options.HPBarOptions.SerializableHPBarOptions;  // IMPORTAUTO
import mvz2.options.KeyBindingOptions.SerializableKeyBindingOptions;  // IMPORTAUTO

// [Serializable]
// [BsonIgnoreExtraElements]
@:rtti
class SerializableOptions {
    public function new() {}
    public var keyBindings:SerializableKeyBindingOptions;
    public var skipAllTalks:Bool;
    public var showSponsorNames:Bool;
    public var blueprintWarningsDisabled:Bool;
    public var commandBlockMode:Int;
    public var fpsMode:Int;
    public var showHotkeyIndicators:Bool;
    public var hdrLightingDisabled:Bool;
    public var heightIndicatorEnabled:Bool;
    public var hpBar:SerializableHPBarOptions;
}
