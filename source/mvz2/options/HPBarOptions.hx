// Ported from: Assets/Scripts/MVZ2/Options/HPBarOptions.cs
package mvz2.options;

class HPBarOptions {
    public function new() {}

    public function ToSerializable():SerializableHPBarOptions {
        var seri = new SerializableHPBarOptions();
        seri.enabled = enabled;
        seri.autoHide = autoHide;
        seri.hoverDisplayRange = hoverDisplayRange;
        seri.amountMode = amountMode;
        return seri;
    }
    public function LoadFromSerializable(options:SerializableHPBarOptions):Void {
        if (options == null)
            return;
        enabled = options.enabled;
        autoHide = options.autoHide;
        hoverDisplayRange = options.hoverDisplayRange;
        amountMode = options.amountMode;
    }
    public var enabled:Bool;
    public var autoHide:Bool;
    public var hoverDisplayRange:Float;
    public var amountMode:Int;
}

// [Serializable]
// [BsonIgnoreExtraElements]
@:rtti
class SerializableHPBarOptions {
    public function new() {}
    public var enabled:Bool;
    public var autoHide:Bool;
    public var hoverDisplayRange:Float;
    public var amountMode:Int;
}
