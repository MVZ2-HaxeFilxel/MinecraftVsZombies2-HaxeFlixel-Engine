// Ported from: Assets/Scripts/MVZ2/Localization/SpriteRendererTranslator.cs
package mvz2.localization;

import mvz2.managers.MainManager;
import unity.Component;  // UNKNOWNIMPORT
import unity.UnityObject;
import tools.ObjectExtensions;
import unity.Sprite;
import unity.SpriteRenderer;

// [RequireComponent(typeof(SpriteRenderer))]
class SpriteRendererTranslator extends TranslateComponentSprite<SpriteRenderer> {
    public function new() {
        super(SpriteRenderer);
    }

    override private function GetKeyInner():Sprite {
        return Component != null ? Component.sprite : null;
    }
    override private function Translate(language:String):Void {
        super.Translate(language);
        if (UnityObject.exists(Component) && UnityObject.exists(Key))
            // PORT-NOTE: C# 为 MainManager.GetFinalSprite(Sprite, string)（重载）；
            // managers 包的移植版将其重命名为 GetFinalSpriteLocalizedFromSprite。
            Component.sprite = MainManager.Instance.GetFinalSpriteLocalizedFromSprite(Key, language);
    }
}
