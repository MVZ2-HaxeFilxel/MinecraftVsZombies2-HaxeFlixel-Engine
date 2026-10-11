// Ported from: Assets/Scripts/MVZ2/Localization/TextMeshProTranslator.cs
package mvz2.localization;

import tools.ObjectExtensions;
import unity.Component;  // UNKNOWNIMPORT
import unity.UnityObject;
import tmpro.TextMeshPro;

// [RequireComponent(typeof(TextMeshPro))]
class TextMeshProTranslator extends TranslateComponentText<TextMeshPro> {
    public function new() {
        super(TextMeshPro);
    }

    override private function GetKeyInner():String {
        return Component != null ? Component.text : null;
    }
    override private function Translate(language:String):Void {
        super.Translate(language);
        if (!UnityObject.exists(Component))
            return;
        // PORT-NOTE: Haxe 无 StringTools.isBlank，等价于 C# string.IsNullOrWhiteSpace。
        if (Context != null && StringTools.trim(Context).length > 0)
            Component.text = lang._p(Context, Key);
        else
            Component.text = lang._(Key);
    }
}
