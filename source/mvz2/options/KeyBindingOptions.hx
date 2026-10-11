// Ported from: Assets/Scripts/MVZ2/Options/KeyBindingOptions.cs
package mvz2.options;

import pvzengine.NamespaceID;
import unity.KeyCode;

class KeyBindingOptions {
    public function new() {}

    public function TryGetKeyBinding(hotkey:NamespaceID, code:KeyCode):KeyCode {
        // PORT-NOTE: C# 的 out 参数在 Haxe 中改为返回值（找不到时返回 KeyCode.None）。
        return bindings.exists(hotkey) ? bindings.get(hotkey) : KeyCode.None;
    }
    public function SetKeyBinding(hotkey:NamespaceID, code:KeyCode):Void {
        bindings.set(hotkey, code);
    }
    public function Reset():Void {
        bindings.clear();
    }
    public function ToSerializable():SerializableKeyBindingOptions {
        var seri = new SerializableKeyBindingOptions();
        seri.bindings = new Map();
        for (key in bindings.keys()) {
            seri.bindings.set(key, cast(bindings.get(key), Int));
        }
        return seri;
    }
    public function LoadFromSerializable(seri:SerializableKeyBindingOptions):Void {
        bindings = new Map();
        if (seri.bindings == null) return;
        for (key in seri.bindings.keys()) {
            bindings.set(key, cast(seri.bindings.get(key), KeyCode));
        }
    }

    private var bindings:Map<NamespaceID, KeyCode> = new Map();
}

// [Serializable]
@:rtti
class SerializableKeyBindingOptions {
    public function new() {}
    public var bindings:Map<NamespaceID, Int>;
}
